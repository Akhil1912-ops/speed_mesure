import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'dart:math' as math;
import 'database_helper.dart';
import 'trip_summary_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SpeedTrackerApp());
}

class SpeedTrackerApp extends StatelessWidget {
  const SpeedTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Speed Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const SpeedTrackerHome(),
    );
  }
}

class SpeedTrackerHome extends StatefulWidget {
  const SpeedTrackerHome({super.key});

  @override
  State<SpeedTrackerHome> createState() => _SpeedTrackerHomeState();
}

class _SpeedTrackerHomeState extends State<SpeedTrackerHome> {
  double currentSpeed = 0.0;
  bool isTracking = false;
  StreamSubscription<Position>? positionStream;
  String statusMessage = "Press START to begin tracking";
  bool locationPermissionGranted = false;

  final double speedLimit = 30.0; // km/h
  
  // Trip recording data
  int? currentTripId;
  DateTime? tripStartTime;
  List<Map<String, dynamic>> tripGPSPoints = [];
  Position? lastPosition;
  double totalDistance = 0.0;
  double maxSpeed = 0.0;
  int violationsCount = 0;

  @override
  void initState() {
    super.initState();
    checkLocationPermission();
  }

  Future<void> checkLocationPermission() async {
    var status = await Permission.location.status;
    if (status.isGranted) {
      setState(() {
        locationPermissionGranted = true;
        statusMessage = "Ready to track";
      });
    } else {
      setState(() {
        locationPermissionGranted = false;
        statusMessage = "Location permission required";
      });
    }
  }

  Future<void> requestLocationPermission() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      setState(() {
        locationPermissionGranted = true;
        statusMessage = "Permission granted! Press START";
      });
    } else {
      setState(() {
        locationPermissionGranted = false;
        statusMessage = "Permission denied. Cannot track speed.";
      });
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Haversine formula for distance between two points
    const R = 6371; // Earth's radius in kilometers
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) {
    return degree * math.pi / 180;
  }

  void startTracking() async {
    if (!locationPermissionGranted) {
      await requestLocationPermission();
      if (!locationPermissionGranted) return;
    }

    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        statusMessage = "Please enable GPS/Location services";
      });
      return;
    }

    // Create new trip in database
    tripStartTime = DateTime.now();
    currentTripId = await DatabaseHelper.instance.createTrip(
      tripStartTime!.toIso8601String(),
    );

    // Reset trip data
    tripGPSPoints = [];
    lastPosition = null;
    totalDistance = 0.0;
    maxSpeed = 0.0;
    violationsCount = 0;

    setState(() {
      isTracking = true;
      statusMessage = "Tracking speed...";
    });

    // Configure location settings with foreground notification (keeps running in background)
    final LocationSettings locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0, // Get updates for any movement
      forceLocationManager: false,
      intervalDuration: const Duration(seconds: 2),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: "Speed Tracker is monitoring your speed",
        notificationTitle: "Tracking Active",
        enableWakeLock: true,
      ),
    );

    // Start listening to position updates
    positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) async {
      // GPS provides speed in meters per second
      double speedMps = position.speed;
      
      // Convert to km/h
      double speedKmh = speedMps * 3.6;
      
      // Filter bad data
      if (position.accuracy > 15 || speedKmh < 0) {
        return; // Ignore inaccurate readings
      }

      // Update max speed
      if (speedKmh > maxSpeed) {
        maxSpeed = speedKmh;
      }

      // Count violations
      if (speedKmh > speedLimit) {
        violationsCount++;
      }

      // Calculate distance if we have a previous position
      if (lastPosition != null && speedKmh > 1) { // Only if moving
        double distance = calculateDistance(
          lastPosition!.latitude,
          lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        totalDistance += distance;
      }

      // Save GPS point to database
      if (currentTripId != null) {
        await DatabaseHelper.instance.saveGPSPoint(
          tripId: currentTripId!,
          latitude: position.latitude,
          longitude: position.longitude,
          speed: speedKmh,
          accuracy: position.accuracy,
          timestamp: DateTime.now().toIso8601String(),
        );

        // Also keep in memory for summary screen
        tripGPSPoints.add({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'speed': speedKmh,
          'accuracy': position.accuracy,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      lastPosition = position;

      setState(() {
        currentSpeed = speedKmh;
      });
    });
  }

  void stopTracking() async {
    positionStream?.cancel();

    // Update trip summary in database
    if (currentTripId != null && tripStartTime != null) {
      await DatabaseHelper.instance.updateTripSummary(
        tripId: currentTripId!,
        endTime: DateTime.now().toIso8601String(),
        totalDistance: totalDistance,
        maxSpeed: maxSpeed,
        violationsCount: violationsCount,
      );

      // Navigate to summary screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TripSummaryScreen(
              gpsPoints: tripGPSPoints,
              totalDistance: totalDistance,
              maxSpeed: maxSpeed,
              violationsCount: violationsCount,
              tripDuration: DateTime.now().difference(tripStartTime!),
              tripStartTime: tripStartTime!,
            ),
          ),
        );
      }
    }

    setState(() {
      isTracking = false;
      currentSpeed = 0.0;
      statusMessage = "Tracking stopped";
    });
  }

  @override
  void dispose() {
    positionStream?.cancel();
    super.dispose();
  }

  Color getSpeedColor() {
    if (currentSpeed < 25) {
      return Colors.green;
    } else if (currentSpeed < speedLimit) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  String getSpeedStatus() {
    if (currentSpeed < 25) {
      return "Safe Speed";
    } else if (currentSpeed < speedLimit) {
      return "Approaching Limit";
    } else {
      return "⚠️ OVERSPEEDING!";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Speed Tracker'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Speed display
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: getSpeedColor().withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                    border: Border.all(
                      color: getSpeedColor(),
                      width: 8,
                    ),
                  ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        currentSpeed.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                          color: getSpeedColor(),
                        ),
            ),
            Text(
                        'km/h',
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Speed status
                if (isTracking)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: getSpeedColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: getSpeedColor(),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      getSpeedStatus(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: getSpeedColor(),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // Trip stats (if tracking)
                if (isTracking)
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMiniStat('Distance', '${totalDistance.toStringAsFixed(2)} km'),
                            _buildMiniStat('Max', '${maxSpeed.toStringAsFixed(0)} km/h'),
                            _buildMiniStat('Violations', '$violationsCount'),
                          ],
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // Speed limit info
                Text(
                  'Campus Speed Limit: ${speedLimit.toInt()} km/h',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),

                const SizedBox(height: 40),

                // Status message
                Text(
                  statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),

                const SizedBox(height: 30),

                // Start/Stop button
                SizedBox(
                  width: 200,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: isTracking ? stopTracking : startTracking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isTracking ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 5,
                    ),
                    child: Text(
                      isTracking ? 'STOP & VIEW ROUTE' : 'START',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
