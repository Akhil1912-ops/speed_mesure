import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('speed_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL';

    // Table to store trip information
    await db.execute('''
      CREATE TABLE trips (
        id $idType,
        start_time $textType,
        end_time $textType,
        total_distance $realType,
        max_speed $realType,
        violations_count $integerType
      )
    ''');

    // Table to store GPS points for each trip
    await db.execute('''
      CREATE TABLE gps_points (
        id $idType,
        trip_id $integerType,
        latitude $realType,
        longitude $realType,
        speed $realType,
        accuracy $realType,
        timestamp $textType,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');
  }

  // Create a new trip
  Future<int> createTrip(String startTime) async {
    final db = await database;
    return await db.insert('trips', {
      'start_time': startTime,
      'end_time': startTime, // Will update later
      'total_distance': 0.0,
      'max_speed': 0.0,
      'violations_count': 0,
    });
  }

  // Save GPS point
  Future<void> saveGPSPoint({
    required int tripId,
    required double latitude,
    required double longitude,
    required double speed,
    required double accuracy,
    required String timestamp,
  }) async {
    final db = await database;
    await db.insert('gps_points', {
      'trip_id': tripId,
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'accuracy': accuracy,
      'timestamp': timestamp,
    });
  }

  // Get all GPS points for a trip
  Future<List<Map<String, dynamic>>> getGPSPointsForTrip(int tripId) async {
    final db = await database;
    return await db.query(
      'gps_points',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'timestamp ASC',
    );
  }

  // Update trip summary
  Future<void> updateTripSummary({
    required int tripId,
    required String endTime,
    required double totalDistance,
    required double maxSpeed,
    required int violationsCount,
  }) async {
    final db = await database;
    await db.update(
      'trips',
      {
        'end_time': endTime,
        'total_distance': totalDistance,
        'max_speed': maxSpeed,
        'violations_count': violationsCount,
      },
      where: 'id = ?',
      whereArgs: [tripId],
    );
  }

  // Get trip by ID
  Future<Map<String, dynamic>?> getTrip(int tripId) async {
    final db = await database;
    final results = await db.query(
      'trips',
      where: 'id = ?',
      whereArgs: [tripId],
    );
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}

