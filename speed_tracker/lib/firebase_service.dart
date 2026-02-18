import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload trip data and map image to Firebase
  /// Returns the trip ID
  Future<String> uploadTrip({
    required Uint8List mapImageBytes,
    required double distance,
    required double maxSpeed,
    required double avgSpeed,
    required int duration,
    required int violationsCount,
    required List<Map<String, dynamic>> gpsPoints,
    required List<Map<String, dynamic>> violations,
    required DateTime timestamp,
    required Map<String, dynamic> startLocation,
    required Map<String, dynamic> endLocation,
  }) async {
    try {
      // 1. Generate unique trip ID
      String tripId = _generateTripId();

      // 2. Upload map image to Firebase Storage
      String imageUrl = await _uploadMapImage(tripId, mapImageBytes);

      // 3. Prepare trip data
      Map<String, dynamic> tripData = {
        'trip_id': tripId,
        'timestamp': timestamp.toIso8601String(),
        'max_speed': maxSpeed,
        'avg_speed': avgSpeed,
        'speed_limit': 30.0,
        'violations_count': violationsCount,
        'total_distance': distance,
        'duration': duration,
        'start_location': startLocation,
        'end_location': endLocation,
        'map_image_url': imageUrl,
        'gps_points': gpsPoints,
        'violations': violations,
        'status': 'completed',
        'reviewed_by': null,
        'action_taken': null,
      };

      // 4. Save to Firestore
      await _firestore.collection('trips').doc(tripId).set(tripData);

      return tripId;
    } catch (e) {
      rethrow;
    }
  }

  /// Upload map image to Firebase Storage
  Future<String> _uploadMapImage(String tripId, Uint8List imageBytes) async {
    try {
      // Create reference to storage location
      Reference ref = _storage.ref().child('trip_maps/$tripId.png');

      // Upload image
      UploadTask uploadTask = ref.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/png'),
      );

      // Wait for upload to complete
      TaskSnapshot snapshot = await uploadTask;

      // Get download URL
      String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      rethrow;
    }
  }

  /// Generate unique trip ID
  String _generateTripId() {
    DateTime now = DateTime.now();
    String dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    String timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'TRIP$dateStr$timeStr';
  }

  /// Get trip data by ID (for testing/admin)
  Future<Map<String, dynamic>?> getTrip(String tripId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('trips').doc(tripId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Update trip with security action
  Future<void> updateTripAction(String tripId, String action, String reviewedBy) async {
    try {
      await _firestore.collection('trips').doc(tripId).update({
        'action_taken': action,
        'reviewed_by': reviewedBy,
        'reviewed_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      rethrow;
    }
  }
}

