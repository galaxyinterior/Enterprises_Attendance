import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../../models/attendance_model.dart';
import '../../models/employee_model.dart';

class OfflineDbService {
  static final OfflineDbService _instance = OfflineDbService._internal();
  factory OfflineDbService() => _instance;
  OfflineDbService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'attendance_offline.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Attendance offline queue table
        await db.execute('''
          CREATE TABLE offline_attendance (
            attendanceId TEXT PRIMARY KEY,
            businessId TEXT,
            employeeId TEXT,
            employeeName TEXT,
            date TEXT,
            shiftId TEXT,
            checkInTime TEXT,
            checkOutTime TEXT,
            status TEXT,
            confidence REAL,
            syncStatus TEXT,
            createdAt TEXT,
            updatedAt TEXT
          )
        ''');

        // Cached local employee embeddings table
        await db.execute('''
          CREATE TABLE local_employees (
            employeeId TEXT PRIMARY KEY,
            businessId TEXT,
            fullName TEXT,
            assignedShiftId TEXT,
            faceEmbedding TEXT
          )
        ''');
      },
    );
  }

  // Insert or queue offline attendance
  Future<void> insertAttendance(AttendanceModel attendance) async {
    final db = await database;
    await db.insert(
      'offline_attendance',
      attendance.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all pending unsynced attendance records
  Future<List<AttendanceModel>> getPendingAttendance() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'offline_attendance',
      where: 'syncStatus = ?',
      whereArgs: ['PENDING'],
    );
    return maps.map((map) => AttendanceModel.fromMap(map)).toList();
  }

  // Mark attendance as synced
  Future<void> markAttendanceSynced(String attendanceId) async {
    final db = await database;
    await db.update(
      'offline_attendance',
      {'syncStatus': 'COMPLETED'},
      where: 'attendanceId = ?',
      whereArgs: [attendanceId],
    );
  }

  // Cache local employees with embeddings
  Future<void> cacheLocalEmployee(EmployeeModel employee) async {
    final db = await database;
    await db.insert(
      'local_employees',
      {
        'employeeId': employee.employeeId,
        'businessId': employee.businessId,
        'fullName': employee.fullName,
        'assignedShiftId': employee.assignedShiftId,
        'faceEmbedding': employee.faceEmbedding != null
            ? jsonEncode(employee.faceEmbedding)
            : null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all cached local employees for offline face recognition
  Future<List<Map<String, dynamic>>> getLocalEmployees(String businessId) async {
    final db = await database;
    return await db.query(
      'local_employees',
      where: 'businessId = ?',
      whereArgs: [businessId],
    );
  }
}
