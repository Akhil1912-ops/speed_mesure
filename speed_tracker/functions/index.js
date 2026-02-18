/**
 * Firebase Cloud Functions for Campus Speed Tracker
 * 
 * Automated trip verification:
 * - Route comparison (buffer-based corridor)
 * - Distance validation
 * - Penalty calculation
 * - Auto-scoring
 */

const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

/**
 * Calculate distance between two GPS points (Haversine formula)
 * Returns distance in meters
 */
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371000; // Earth's radius in meters
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);
  
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);
  
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRadians(degrees) {
  return degrees * (Math.PI / 180);
}

/**
 * Calculate distance from a point to a line segment
 * Returns distance in meters
 */
function pointToLineDistance(px, py, x1, y1, x2, y2) {
  const A = px - x1;
  const B = py - y1;
  const C = x2 - x1;
  const D = y2 - y1;
  
  const dot = A * C + B * D;
  const lenSq = C * C + D * D;
  let param = -1;
  
  if (lenSq !== 0) {
    param = dot / lenSq;
  }
  
  let xx, yy;
  
  if (param < 0) {
    xx = x1;
    yy = y1;
  } else if (param > 1) {
    xx = x2;
    yy = y2;
  } else {
    xx = x1 + param * C;
    yy = y1 + param * D;
  }
  
  const dx = px - xx;
  const dy = py - yy;
  return Math.sqrt(dx * dx + dy * dy) * 111000; // Convert to meters (rough approximation)
}

/**
 * Check if a GPS point is within the buffer corridor of an approved route
 */
function isPointInCorridor(point, routePolyline, bufferMeters) {
  let minDistance = Infinity;
  
  // Check distance to each segment of the route
  // Handle both array format [[lat,lon],...] and object format [{lat,lon},...]
  for (let i = 0; i < routePolyline.length - 1; i++) {
    const p1 = routePolyline[i];
    const p2 = routePolyline[i + 1];
    
    // Convert to lat/lon format
    const x1 = Array.isArray(p1) ? p1[0] : p1.lat;
    const y1 = Array.isArray(p1) ? p1[1] : p1.lon;
    const x2 = Array.isArray(p2) ? p2[0] : p2.lat;
    const y2 = Array.isArray(p2) ? p2[1] : p2.lon;
    
    const distance = pointToLineDistance(
      point.latitude, point.longitude,
      x1, y1, x2, y2
    );
    
    minDistance = Math.min(minDistance, distance);
  }
  
  return minDistance <= bufferMeters;
}

/**
 * Verify if traveled route matches approved route
 */
function verifyRoute(gpsPoints, approvedRoute, verificationConfig) {
  const { corridorBuffer_m, minInsideRatio } = verificationConfig;
  const routePolyline = approvedRoute.polyline;
  
  let pointsInside = 0;
  let totalPoints = gpsPoints.length;
  
  // Check each GPS point
  for (const point of gpsPoints) {
    if (isPointInCorridor(
      { latitude: point.latitude, longitude: point.longitude },
      routePolyline,
      corridorBuffer_m
    )) {
      pointsInside++;
    }
  }
  
  const insideRatio = pointsInside / totalPoints;
  const passed = insideRatio >= minInsideRatio;
  
  return {
    passed,
    insideRatio,
    pointsInside,
    totalPoints,
    bufferUsed: corridorBuffer_m
  };
}

/**
 * Verify distance is within expected range
 */
function verifyDistance(traveledDistance, expectedDistance, config) {
  const { distanceRatioMin, distanceRatioMax } = config;
  
  const ratio = traveledDistance / expectedDistance;
  const passed = ratio >= distanceRatioMin && ratio <= distanceRatioMax;
  
  return {
    passed,
    ratio,
    traveledDistance,
    expectedDistance,
    minAllowed: expectedDistance * distanceRatioMin,
    maxAllowed: expectedDistance * distanceRatioMax
  };
}

/**
 * Calculate penalty based on violations
 */
function calculatePenalty(violationsCount, maxSpeed, speedLimit, routeViolations) {
  let penalty = 0;
  let violations = [];
  
  // Speed violations
  if (violationsCount > 0) {
    const speedPenalty = violationsCount * 50; // ₹50 per violation
    penalty += speedPenalty;
    violations.push({
      type: 'speed',
      count: violationsCount,
      penalty: speedPenalty
    });
  }
  
  // Serious speeding (over 35 km/h)
  if (maxSpeed > 35) {
    const seriousPenalty = 200; // ₹200 for serious violation
    penalty += seriousPenalty;
    violations.push({
      type: 'serious_speeding',
      maxSpeed: maxSpeed,
      penalty: seriousPenalty
    });
  }
  
  // Route deviation
  if (routeViolations && !routeViolations.passed) {
    const routePenalty = 100; // ₹100 for route violation
    penalty += routePenalty;
    violations.push({
      type: 'route_deviation',
      insideRatio: routeViolations.insideRatio,
      penalty: routePenalty
    });
  }
  
  return {
    totalPenalty: penalty,
    violations: violations
  };
}

/**
 * Determine overall verdict
 */
function determineVerdict(routeCheck, distanceCheck, penalty) {
  let verdict = 'approved';
  let score = 100;
  
  // Route violation: -30 points
  if (!routeCheck.passed) {
    score -= 30;
    verdict = 'warning';
  }
  
  // Distance violation: -20 points
  if (!distanceCheck.passed) {
    score -= 20;
    verdict = 'warning';
  }
  
  // Penalty-based deduction
  if (penalty.totalPenalty > 200) {
    score -= 30;
    verdict = 'denied';
  } else if (penalty.totalPenalty > 100) {
    score -= 20;
    verdict = 'warning';
  }
  
  // Final verdict
  if (score < 50) {
    verdict = 'denied';
  } else if (score < 70) {
    verdict = 'warning';
  }
  
  return {
    verdict,
    score,
    message: getVerdictMessage(verdict, score)
  };
}

function getVerdictMessage(verdict, score) {
  if (verdict === 'approved') {
    return `✅ Clean trip (Score: ${score}/100)`;
  } else if (verdict === 'warning') {
    return `⚠️ Minor violations detected (Score: ${score}/100)`;
  } else {
    return `❌ Serious violations - Entry denied (Score: ${score}/100)`;
  }
}

/**
 * Find best matching route by comparing against ALL routes
 * Returns the route with highest match score, or null if no good match
 */
async function findBestMatchingRoute(startLocation, endLocation, traveledGPSPoints) {
  const routesRef = db.collection('approved_routes');
  const routesSnapshot = await routesRef.get();
  
  if (routesSnapshot.empty) {
    console.log('WARNING: No routes found in approved_routes collection!');
    return { route: null, score: 0, matchDetails: null };
  }
  
  let bestMatch = null;
  let bestScore = 0;
  let bestMatchDetails = null;
  const allMatches = [];
  
  // Check each route and score the match
  for (const doc of routesSnapshot.docs) {
    const route = doc.data();
    let score = 0;
    const matchDetails = {
      routeId: route.id,
      routeName: route.fullName,
      startMatch: false,
      endMatch: false,
      shapeMatchRatio: 0,
      components: {}
    };
    
    // Route shape check (100 points) - Only factor!
    const routePolyline = route.approvedRoutes[0].polyline;
    let pointsInside = 0;
    const sampleSize = Math.min(traveledGPSPoints.length, 30);
    const step = Math.max(1, Math.floor(traveledGPSPoints.length / sampleSize));
    
    for (let i = 0; i < traveledGPSPoints.length; i += step) {
      const point = traveledGPSPoints[i];
      const lat = point.latitude || point.lat;
      const lon = point.longitude || point.lon;
      if (!lat || !lon) continue;
      if (isPointInCorridor(
        { latitude: lat, longitude: lon },
        routePolyline,
        route.verification.corridorBuffer_m * 2.5 // Use 2.5x buffer for matching (62.5m)
      )) {
        pointsInside++;
      }
    }
    
    const shapeMatchRatio = sampleSize > 0 ? pointsInside / sampleSize : 0;
    matchDetails.shapeMatchRatio = shapeMatchRatio;
    matchDetails.components.shapePoints = Math.round(shapeMatchRatio * 100);
    score = shapeMatchRatio * 100;
    
    matchDetails.totalScore = Math.round(score);
    allMatches.push(matchDetails);
    
    // Keep track of best match
    if (score > bestScore) {
      bestScore = score;
      bestMatch = route;
      bestMatchDetails = matchDetails;
    }
  }
  
  // Return best match if score is good enough (at least 60/100)
  // Based purely on route shape matching
  if (bestScore >= 60) {
    console.log(`Best match: ${bestMatch.fullName} (Score: ${bestScore.toFixed(1)}/100)`);
    return {
      route: bestMatch,
      score: bestScore,
      matchDetails: bestMatchDetails,
      allMatches: allMatches.sort((a, b) => b.totalScore - a.totalScore) // Sorted by score
    };
  }
  
  console.log(`No route matched (best score: ${bestScore.toFixed(1)}/100)`);
  return {
    route: null,
    score: bestScore,
    matchDetails: null,
    allMatches: allMatches.sort((a, b) => b.totalScore - a.totalScore)
  };
}

/**
 * Main function: Automatically verify trip when uploaded
 * Using 2nd Gen Functions for better permissions
 */
exports.verifyTrip = onDocumentCreated('trips/{tripId}', async (event) => {
    const snap = event.data;
    if (!snap) return;
    const tripId = event.params.tripId;
    const trip = snap.data();
    
    console.log(`Verifying trip: ${tripId}`);
    
    try {
      // Auto-detect route by matching against ALL routes
      // Handle both {lat, lon} and {latitude, longitude} formats
      const startLoc = {
        latitude: trip.start_location.latitude || trip.start_location.lat,
        longitude: trip.start_location.longitude || trip.start_location.lon
      };
      const endLoc = {
        latitude: trip.end_location.latitude || trip.end_location.lat,
        longitude: trip.end_location.longitude || trip.end_location.lon
      };
      
      const matchResult = await findBestMatchingRoute(
        startLoc,
        endLoc,
        trip.gps_points
      );
      
      const approvedRoute = matchResult.route;
      const matchScore = matchResult.score;
      const matchDetails = matchResult.matchDetails;
      
      if (!approvedRoute) {
        console.log(`No route detected for trip ${tripId} (best score: ${matchScore.toFixed(1)})`);
        // Update trip with "no route match" status
        await snap.ref.update({
          verification_status: 'no_route_match',
          verification_message: `No route detected. Best match score: ${matchScore.toFixed(1)}/100`,
          route_detection: {
            detected: false,
            bestScore: matchScore,
            allMatches: matchResult.allMatches.slice(0, 3) // Top 3 matches
          },
          verified_at: admin.firestore.FieldValue.serverTimestamp()
        });
        return;
      }
      
      console.log(`Route detected: ${approvedRoute.fullName} (Score: ${matchScore.toFixed(1)}/100)`);
      
      // Get the first approved route (you can enhance to check all routes)
      const route = approvedRoute.approvedRoutes[0];
      const verificationConfig = approvedRoute.verification;
      
      // 1. Verify route shape
      const routeCheck = verifyRoute(
        trip.gps_points,
        route,
        verificationConfig
      );
      
      // 2. Verify distance
      const traveledDistanceKm = trip.total_distance;
      const expectedDistanceKm = route.expectedDistance_m / 1000;
      const distanceCheck = verifyDistance(
        traveledDistanceKm,
        expectedDistanceKm,
        verificationConfig
      );
      
      // 3. Calculate penalty
      const penalty = calculatePenalty(
        trip.violations_count,
        trip.max_speed,
        trip.speed_limit,
        routeCheck
      );
      
      // 4. Determine verdict
      const verdict = determineVerdict(routeCheck, distanceCheck, penalty);
      
      // 5. Update trip with verification results
      await snap.ref.update({
        verification_status: 'verified',
        verification_result: {
          route_check: routeCheck,
          distance_check: distanceCheck,
          penalty: penalty,
          verdict: verdict,
          matched_route: {
            id: approvedRoute.id,
            name: approvedRoute.fullName,
            displayName: approvedRoute.name
          }
        },
        route_detection: {
          detected: true,
          routeId: approvedRoute.id,
          routeName: approvedRoute.fullName,
          displayName: approvedRoute.name,
          matchScore: Math.round(matchScore),
          matchDetails: matchDetails
        },
        auto_verdict: verdict.verdict,
        auto_score: verdict.score,
        verified_at: admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log(`Trip ${tripId} verified: ${verdict.verdict} (Score: ${verdict.score})`);
      
    } catch (error) {
      console.error(`Error verifying trip ${tripId}:`, error);
      await snap.ref.update({
        verification_status: 'error',
        verification_error: error.message,
        verified_at: admin.firestore.FieldValue.serverTimestamp()
      });
    }
  });

