import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:typed_data';
import 'firebase_service.dart';
import 'qr_display_screen.dart';

class UploadScreen extends StatefulWidget {
  final Uint8List mapImageBytes;
  final double distance;
  final double maxSpeed;
  final double avgSpeed;
  final int duration;
  final int violationsCount;
  final List<Map<String, dynamic>> gpsPoints;
  final List<Map<String, dynamic>> violations;
  final DateTime timestamp;
  final Map<String, dynamic> startLocation;
  final Map<String, dynamic> endLocation;

  const UploadScreen({
    super.key,
    required this.mapImageBytes,
    required this.distance,
    required this.maxSpeed,
    required this.avgSpeed,
    required this.duration,
    required this.violationsCount,
    required this.gpsPoints,
    required this.violations,
    required this.timestamp,
    required this.startLocation,
    required this.endLocation,
  });

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _isUploading = false;
  String _uploadMessage = 'Preparing trip data...';
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _startUpload();
  }

  Future<void> _startUpload() async {
    setState(() {
      _isUploading = true;
      _uploadMessage = 'Uploading map image...';
      _uploadProgress = 0.3;
    });

    try {
      // Create Firebase service
      FirebaseService firebaseService = FirebaseService();

      setState(() {
        _uploadMessage = 'Saving trip data...';
        _uploadProgress = 0.6;
      });

      // Upload trip
      String tripId = await firebaseService.uploadTrip(
        mapImageBytes: widget.mapImageBytes,
        distance: widget.distance,
        maxSpeed: widget.maxSpeed,
        avgSpeed: widget.avgSpeed,
        duration: widget.duration,
        violationsCount: widget.violationsCount,
        gpsPoints: widget.gpsPoints,
        violations: widget.violations,
        timestamp: widget.timestamp,
        startLocation: widget.startLocation,
        endLocation: widget.endLocation,
      );

      setState(() {
        _uploadMessage = 'Trip uploaded successfully!';
        _uploadProgress = 1.0;
      });

      // Wait a moment to show success
      await Future.delayed(const Duration(milliseconds: 500));

      // Navigate to QR display
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => QRDisplayScreen(
              tripId: tripId,
              // Production Firebase Hosting URL
              dashboardUrl: 'https://security-dashboard.web.app',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadMessage = 'Upload failed: $e';
      });

      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Upload Failed'),
            content: Text('Error: $e\n\nPlease check your internet connection and try again.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startUpload();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uploading Trip'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Upload icon
              if (_isUploading)
                const SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    strokeWidth: 6,
                  ),
                ),

              const SizedBox(height: 40),

              // Upload message
              Text(
                _uploadMessage,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 30),

              // Progress bar
              LinearProgressIndicator(
                value: _uploadProgress,
                minHeight: 10,
                backgroundColor: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(5),
              ),

              const SizedBox(height: 10),

              // Progress percentage
              Text(
                '${(_uploadProgress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 40),

              // Info
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Please wait while we upload your trip data to the server.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

