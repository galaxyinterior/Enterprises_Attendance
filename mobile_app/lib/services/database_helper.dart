import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/employee.dart';
import '../models/attendance_log.dart';
import '../models/store_config.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('local_attendance.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 7,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE employees ADD COLUMN face_embedding TEXT');
      } catch (e) {
        // Ignore if column already exists
      }
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE employees ADD COLUMN is_synced INTEGER DEFAULT 0');
      } catch (e) {
        // Ignore if column already exists
      }
    }
    if (oldVersion < 4) {
      try {
        await db.execute('''
          CREATE TABLE store_config (
            id INTEGER PRIMARY KEY,
            store_name TEXT,
            address TEXT,
            open_time TEXT,
            close_time TEXT,
            punch_in_start TEXT,
            punch_in_end TEXT,
            punch_out_start TEXT,
            punch_out_end TEXT
          )
        ''');
      } catch (e) {
        // Ignore if table exists
      }
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE store_config ADD COLUMN tts_language TEXT DEFAULT "en-US"');
      } catch (e) {
        // Ignore if column exists
      }
    }
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE employees ADD COLUMN phone TEXT DEFAULT "N/A"');
        await db.execute('ALTER TABLE employees ADD COLUMN dob TEXT DEFAULT "N/A"');
        await db.execute('ALTER TABLE employees ADD COLUMN joining_date TEXT DEFAULT "N/A"');
        await db.execute('ALTER TABLE employees ADD COLUMN duty_time TEXT DEFAULT "N/A"');
        await db.execute('ALTER TABLE employees ADD COLUMN duty_end_time TEXT DEFAULT "N/A"');
        await db.execute('ALTER TABLE employees ADD COLUMN designation TEXT DEFAULT "N/A"');
        await db.execute('ALTER TABLE employees ADD COLUMN email TEXT DEFAULT "N/A"');
      } catch (e) {
        // Ignore if columns exist
      }
    }
    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE employees ADD COLUMN monthly_salary REAL DEFAULT 0.0');
        await db.execute('''
          CREATE TABLE payroll_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            emp_id TEXT NOT NULL,
            month_year TEXT NOT NULL,
            bonus REAL DEFAULT 0.0,
            deduction REAL DEFAULT 0.0,
            paid_absent_days INTEGER DEFAULT 0
          )
        ''');
      } catch (e) {
        // Ignore if exists
      }
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE store_config (
        id INTEGER PRIMARY KEY,
        store_name TEXT,
        address TEXT,
        open_time TEXT,
        close_time TEXT,
        punch_in_start TEXT,
        punch_in_end TEXT,
        punch_out_start TEXT,
        punch_out_end TEXT,
        tts_language TEXT DEFAULT 'en-US'
      )
    ''');

    await db.execute('''
      CREATE TABLE employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        emp_id TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        department TEXT NOT NULL,
        created_at TEXT,
        face_embedding TEXT,
        is_synced INTEGER DEFAULT 0,
        phone TEXT DEFAULT 'N/A',
        dob TEXT DEFAULT 'N/A',
        joining_date TEXT DEFAULT 'N/A',
        duty_time TEXT DEFAULT 'N/A',
        duty_end_time TEXT DEFAULT 'N/A',
        designation TEXT DEFAULT 'N/A',
        email TEXT DEFAULT 'N/A'
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        emp_id TEXT NOT NULL,
        emp_name TEXT NOT NULL,
        department TEXT NOT NULL,
        punch_time TEXT NOT NULL,
        punch_type TEXT NOT NULL,
        confidence REAL NOT NULL,
        status TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE payroll_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        emp_id TEXT NOT NULL,
        month_year TEXT NOT NULL,
        bonus REAL DEFAULT 0.0,
        deduction REAL DEFAULT 0.0,
        paid_absent_days INTEGER DEFAULT 0
      )
    ''');
  }

  // Store Config Methods
  Future<StoreConfig?> getStoreConfig() async {
    final db = await instance.database;
    final result = await db.query('store_config', where: 'id = ?', whereArgs: [1]);
    if (result.isNotEmpty) {
      return StoreConfig.fromMap(result.first);
    }
    return null;
  }

  Future<void> saveStoreConfig(StoreConfig config) async {
    final db = await instance.database;
    final map = config.toMap();
    map['id'] = 1; // singleton
    await db.insert(
      'store_config',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Employee Methods
  Future<int> insertEmployee(Employee emp) async {
    final db = await instance.database;
    final map = emp.toMap();
    if (map['face_embedding'] != null) {
      map['face_embedding'] = jsonEncode(map['face_embedding']);
    }
    final id = await db.insert(
      'employees', 
      emp.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace
    );
    return id;
  }

  Future<int> updateEmployeeSalary(String empId, double salary) async {
    final db = await instance.database;
    return await db.update(
      'employees',
      {'monthly_salary': salary},
      where: 'emp_id = ?',
      whereArgs: [empId]
    );
  }

  Future<Map<String, dynamic>?> getPayrollRecord(String empId, String monthYear) async {
    final db = await instance.database;
    final result = await db.query(
      'payroll_records',
      where: 'emp_id = ? AND month_year = ?',
      whereArgs: [empId, monthYear],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> savePayrollRecord(String empId, String monthYear, {double? bonus, double? deduction, int? paidAbsentDays}) async {
    final db = await instance.database;
    final existing = await getPayrollRecord(empId, monthYear);
    
    final data = <String, dynamic>{
      'emp_id': empId,
      'month_year': monthYear,
    };
    if (bonus != null) data['bonus'] = bonus;
    if (deduction != null) data['deduction'] = deduction;
    if (paidAbsentDays != null) data['paid_absent_days'] = paidAbsentDays;

    if (existing != null) {
      return await db.update(
        'payroll_records',
        data,
        where: 'emp_id = ? AND month_year = ?',
        whereArgs: [empId, monthYear],
      );
    } else {
      return await db.insert('payroll_records', data);
    }
  }

  Future<Employee?> getEmployee(String empId) async {
    final db = await instance.database;
    final result = await db.query('employees', where: 'emp_id = ?', whereArgs: [empId]);
    if (result.isNotEmpty) {
      final map = Map<String, dynamic>.from(result.first);
      if (map['face_embedding'] != null && map['face_embedding'] is String) {
        map['face_embedding'] = jsonDecode(map['face_embedding'] as String);
      }
      return Employee.fromJson(map);
    }
    return null;
  }

  Future<List<Employee>> getAllEmployees() async {
    final db = await instance.database;
    final result = await db.query('employees', orderBy: 'id DESC');
    return result.map((row) {
      final map = Map<String, dynamic>.from(row);
      if (map['face_embedding'] != null && map['face_embedding'] is String) {
        map['face_embedding'] = jsonDecode(map['face_embedding'] as String);
      }
      return Employee.fromJson(map);
    }).toList();
  }

  Future<List<Employee>> getUnsyncedEmployees() async {
    final db = await instance.database;
    final result = await db.query('employees', where: 'is_synced = ?', whereArgs: [0]);
    return result.map((row) {
      final map = Map<String, dynamic>.from(row);
      if (map['face_embedding'] != null && map['face_embedding'] is String) {
        map['face_embedding'] = jsonDecode(map['face_embedding'] as String);
      }
      return Employee.fromJson(map);
    }).toList();
  }

  Future<void> markEmployeesAsSynced(List<String> empIds) async {
    final db = await instance.database;
    for (String id in empIds) {
      await db.update(
        'employees',
        {'is_synced': 1},
        where: 'emp_id = ?',
        whereArgs: [id],
      );
    }
  }

  // Attendance Log Methods
  Future<int> insertAttendanceLog(AttendanceLog log) async {
    final db = await instance.database;
    return await db.insert('attendance_logs', log.toMap());
  }

  Future<List<AttendanceLog>> getAllAttendanceLogs() async {
    final db = await instance.database;
    final result = await db.query('attendance_logs', orderBy: 'id DESC');
    return result.map((map) => AttendanceLog.fromMap(map)).toList();
  }

  Future<List<AttendanceLog>> getUnsyncedLogs() async {
    final db = await instance.database;
    final result = await db.query('attendance_logs', where: 'is_synced = ?', whereArgs: [0]);
    return result.map((map) => AttendanceLog.fromMap(map)).toList();
  }

  Future<void> markLogsAsSynced(List<int> localIds) async {
    final db = await instance.database;
    for (int id in localIds) {
      await db.update(
        'attendance_logs',
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<AttendanceLog?> getLastPunch(String empId) async {
    final db = await instance.database;
    final result = await db.query(
      'attendance_logs',
      where: 'emp_id = ?',
      whereArgs: [empId],
      orderBy: 'id DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      return AttendanceLog.fromMap(result.first);
    }
    return null;
  }

  Future<int> getPresentDaysThisMonth(String empId) async {
    final db = await instance.database;
    final now = DateTime.now();
    // Format: yyyy-MM
    final monthStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}";
    
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT substr(punch_time, 1, 10)) as count 
      FROM attendance_logs 
      WHERE emp_id = ? AND punch_time LIKE ?
    ''', [empId, '$monthStr%']);
    
    if (result.isNotEmpty) {
      return (result.first['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  Future<String?> getTodaysCheckInTime(String empId) async {
    final db = await instance.database;
    final now = DateTime.now();
    // Format: yyyy-MM-dd
    final dateStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    final result = await db.query(
      'attendance_logs',
      where: 'emp_id = ? AND punch_type = ? AND punch_time LIKE ?',
      whereArgs: [empId, 'IN', '$dateStr%'],
      orderBy: 'punch_time ASC',
      limit: 1,
    );
    
    if (result.isNotEmpty) {
      final log = AttendanceLog.fromMap(result.first);
      // Try to parse and format it nicely, e.g., '10:00 AM'
      try {
        final dt = DateTime.parse(log.punchTime);
        int hour = dt.hour;
        int minute = dt.minute;
        String ampm = hour >= 12 ? 'PM' : 'AM';
        hour = hour % 12;
        if (hour == 0) hour = 12;
        String hrStr = hour.toString().padLeft(2, '0');
        String minStr = minute.toString().padLeft(2, '0');
        return '$hrStr:$minStr $ampm';
      } catch (e) {
        return log.punchTime;
      }
    }
    return null;
  }
}
