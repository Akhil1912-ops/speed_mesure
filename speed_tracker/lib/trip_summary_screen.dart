import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'upload_screen.dart';

class TripSummaryScreen extends StatefulWidget {
  final List<Map<String, dynamic>> gpsPoints;
  final double totalDistance;
  final double maxSpeed;
  final int violationsCount;
  final Duration tripDuration;
  final DateTime tripStartTime;

  const TripSummaryScreen({
    super.key,
    required this.gpsPoints,
    required this.totalDistance,
    required this.maxSpeed,
    required this.violationsCount,
    required this.tripDuration,
    required this.tripStartTime,
  });

  @override
  State<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends State<TripSummaryScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();

  List<LatLng> get routePoints {
    return widget.gpsPoints.map((point) {
      return LatLng(point['latitude'], point['longitude']);
    }).toList();
  }

  LatLng get centerPoint {
    if (routePoints.isEmpty) return LatLng(0, 0);
    double sumLat = 0;
    double sumLng = 0;
    for (var point in routePoints) {
      sumLat += point.latitude;
      sumLng += point.longitude;
    }
    return LatLng(sumLat / routePoints.length, sumLng / routePoints.length);
  }

  List<Polyline> getColorCodedRoute() {
    List<Polyline> polylines = [];
    const double speedLimit = 30.0;

    for (int i = 0; i < routePoints.length - 1; i++) {
      double speed = widget.gpsPoints[i]['speed'];
      Color lineColor;

      if (speed < 25) {
        lineColor = Colors.green;
      } else if (speed < speedLimit) {
        lineColor = Colors.orange;
      } else {
        lineColor = Colors.red;
      }

      polylines.add(Polyline(
        points: [routePoints[i], routePoints[i + 1]],
        strokeWidth: 5.0,
        color: lineColor,
      ));
    }

    return polylines;
  }

  // Upload handler
  Future<void> _uploadTrip() async {
    try {
      // Capture screenshot of map
      Uint8List? image = await _screenshotController.capture();
      if (image == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to capture map')),
        );
        return;
      }

      // Prepare violation data
      List<Map<String, dynamic>> violations = [];
      for (int i = 0; i < widget.gpsPoints.length; i++) {
        double speed = widget.gpsPoints[i]['speed'];
        if (speed > 30) {
          violations.add({
            'location': {
              'lat': widget.gpsPoints[i]['latitude'],
              'lon': widget.gpsPoints[i]['longitude'],
            },
            'speed': speed,
            'speed_limit': 30.0,
            'timestamp': widget.gpsPoints[i]['timestamp'],
          });
        }
      }

      // Calculate average speed
      double totalSpeed = 0;
      for (var point in widget.gpsPoints) {
        totalSpeed += point['speed'];
      }
      double avgSpeed = widget.gpsPoints.isNotEmpty ? totalSpeed / widget.gpsPoints.length : 0;

      // Navigate to upload screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UploadScreen(
              mapImageBytes: image,
              distance: widget.totalDistance,
              maxSpeed: widget.maxSpeed,
              avgSpeed: avgSpeed,
              duration: widget.tripDuration.inSeconds,
              violationsCount: widget.violationsCount,
              gpsPoints: widget.gpsPoints,
              violations: violations,
              timestamp: widget.tripStartTime,
              startLocation: {
                'lat': widget.gpsPoints.first['latitude'],
                'lon': widget.gpsPoints.first['longitude'],
              },
              endLocation: {
                'lat': widget.gpsPoints.last['latitude'],
                'lon': widget.gpsPoints.last['longitude'],
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  List<Marker> getMarkers() {
    if (routePoints.isEmpty) return [];

    return [
      // Start marker
      Marker(
        point: routePoints.first,
        width: 40,
        height: 40,
        child: const Icon(
          Icons.location_on,
          color: Colors.green,
          size: 40,
        ),
      ),
      // End marker
      Marker(
        point: routePoints.last,
        width: 40,
        height: 40,
        child: const Icon(
          Icons.flag,
          color: Colors.red,
          size: 40,
        ),
      ),
    ];
  }

  String formatDuration(Duration duration) {
    int minutes = duration.inMinutes;
    int seconds = duration.inSeconds % 60;
    return '$minutes min $seconds sec';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Summary'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Map display (wrapped with Screenshot)
          Expanded(
            flex: 2,
            child: routePoints.isEmpty
                ? const Center(child: Text('No route data'))
                : Screenshot(
                    controller: _screenshotController,
                    child: Stack(
                      children: [
                        FlutterMap(
                        options: MapOptions(
                          initialCenter: centerPoint,
                          initialZoom: 15.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.campus.speed_tracker',
                          ),
                          PolylineLayer(
                            polylines: getColorCodedRoute(),
                          ),
                          MarkerLayer(
                            markers: getMarkers(),
                          ),
                        ],
                      ),
                      ],
                    ),
                  ),
          ),

          // Stats panel
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Trip Statistics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard(
                      'Distance',
                      '${widget.totalDistance.toStringAsFixed(2)} km',
                      Icons.straighten,
                      Colors.blue,
                    ),
                    _buildStatCard(
                      'Duration',
                      formatDuration(widget.tripDuration),
                      Icons.access_time,
                      Colors.purple,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard(
                      'Max Speed',
                      '${widget.maxSpeed.toStringAsFixed(1)} km/h',
                      Icons.speed,
                      widget.maxSpeed > 30 ? Colors.red : Colors.green,
                    ),
                    _buildStatCard(
                      'Violations',
                      widget.violationsCount.toString(),
                      Icons.warning,
                      widget.violationsCount > 0 ? Colors.red : Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Upload button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _uploadTrip,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text(
                      'Upload to Server & Get QR',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

