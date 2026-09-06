import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../models/employee.dart';
import '../models/store_config.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  final Uuid _uuid = const Uuid();

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('local_attendance_v2.db');
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
    await db.execute('''
      CREATE TABLE stores (
        id TEXT PRIMARY KEY,
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
        id TEXT PRIMARY KEY,
        store_id TEXT NOT NULL,
        emp_id TEXT NOT NULL,
        name TEXT NOT NULL,
        department TEXT NOT NULL,
        phone TEXT DEFAULT 'N/A',
        dob TEXT DEFAULT 'N/A',
        joining_date TEXT DEFAULT 'N/A',
        duty_time TEXT DEFAULT 'N/A',
        duty_end_time TEXT DEFAULT 'N/A',
        designation TEXT DEFAULT 'N/A',
        email TEXT DEFAULT 'N/A',
        monthly_salary REAL DEFAULT 0.0,
        FOREIGN KEY (store_id) REFERENCES stores (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE biometric_profiles (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        store_id TEXT NOT NULL,
        face_embedding TEXT NOT NULL,
        model_version TEXT DEFAULT 'mobilefacenet_v1',
        FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE,
        FOREIGN KEY (store_id) REFERENCES stores (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance_events (
        id TEXT PRIMARY KEY,
        client_event_id TEXT UNIQUE NOT NULL,
        store_id TEXT NOT NULL,
        employee_id TEXT NOT NULL,
        device_id TEXT,
        event_type TEXT NOT NULL,
        device_timestamp TEXT NOT NULL,
        server_timestamp TEXT,
        face_distance REAL NOT NULL,
        confidence REAL NOT NULL,
        status TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE,
        FOREIGN KEY (store_id) REFERENCES stores (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance_daily (
        id TEXT PRIMARY KEY,
        store_id TEXT NOT NULL,
        employee_id TEXT NOT NULL,
        date TEXT NOT NULL,
        first_in TEXT,
        last_out TEXT,
        status TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE,
        FOREIGN KEY (store_id) REFERENCES stores (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE payroll_records (
        id TEXT PRIMARY KEY,
        store_id TEXT NOT NULL,
        employee_id TEXT NOT NULL,
        month_year TEXT NOT NULL,
        bonus REAL DEFAULT 0.0,
        deduction REAL DEFAULT 0.0,
        paid_absent_days INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE,
        FOREIGN KEY (store_id) REFERENCES stores (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        status TEXT DEFAULT 'pending',
        retry_count INTEGER DEFAULT 0,
        last_error TEXT
      )
    ''');
  }

  // --- Outbox Helper ---
  Future<void> insertOutbox(Transaction txn, String tableName, String operation, Map<String, dynamic> payload) async {
    await txn.insert('outbox', {
      'table_name': tableName,
      'operation': operation,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // --- Store Config ---
  Future<StoreConfig?> getStoreConfig() async {
    final db = await instance.database;
    final result = await db.query('stores', limit: 1);
    if (result.isNotEmpty) {
      return StoreConfig.fromMap(result.first);
    }
    return null;
  }

  Future<void> saveStoreConfig(StoreConfig config) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final map = config.toMap();
      map['id'] = 'default_store_id'; // Replace with real ID
      await txn.insert('stores', map, conflictAlgorithm: ConflictAlgorithm.replace);
      await insertOutbox(txn, 'stores', 'UPDATE', map);
    });
  }

  // --- Phase 6: Biometrics ---
  Future<List<double>?> getBiometricEmbedding(String employeeId) async {
    final db = await instance.database;
    final result = await db.query('biometric_profiles', where: 'employee_id = ?', whereArgs: [employeeId]);
    if (result.isNotEmpty) {
      final data = result.first['face_embedding'] as String;
      final List<dynamic> decoded = jsonDecode(data);
      return decoded.cast<double>();
    }
    return null;
  }

  // --- Employees ---
  Future<void> insertEmployee(Employee emp) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final empIdUuid = _uuid.v4();
      final storeId = 'default_store_id'; // Get from session
      
      final empData = {
        'id': empIdUuid,
        'store_id': storeId,
        'emp_id': emp.empId,
        'name': emp.name,
        'department': emp.department,
        'monthly_salary': emp.monthlySalary,
        'phone': emp.phone,
        'dob': emp.dob,
        'joining_date': emp.joiningDate,
        'duty_time': emp.dutyTime,
        'duty_end_time': emp.dutyEndTime,
        'designation': emp.designation,
        'email': emp.email,
      };

      await txn.insert('employees', empData, conflictAlgorithm: ConflictAlgorithm.replace);
      await insertOutbox(txn, 'employees', 'INSERT', empData);

      if (emp.faceEmbedding != null) {
        final bioData = {
          'id': _uuid.v4(),
          'employee_id': empIdUuid,
          'store_id': storeId,
          'face_embedding': jsonEncode(emp.faceEmbedding),
        };
        await txn.insert('biometric_profiles', bioData, conflictAlgorithm: ConflictAlgorithm.replace);
        await insertOutbox(txn, 'biometric_profiles', 'INSERT', bioData);
      }
    });
  }

  Future<List<Employee>> getAllEmployees() async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT e.*, b.face_embedding 
      FROM employees e
      LEFT JOIN biometric_profiles b ON e.id = b.employee_id
    ''');
    
    List<Employee> employees = [];
    for (var row in result) {
      List<double>? faceEmbedding;
      if (row['face_embedding'] != null) {
        final List<dynamic> decoded = jsonDecode(row['face_embedding'] as String);
        faceEmbedding = decoded.cast<double>();
      }

      employees.add(Employee(
        empId: row['emp_id'] as String,
        name: row['name'] as String,
        department: row['department'] as String,
        monthlySalary: row['monthly_salary'] as double? ?? 0.0,
        phone: row['phone'] as String? ?? 'N/A',
        dob: row['dob'] as String? ?? 'N/A',
        joiningDate: row['joining_date'] as String? ?? 'N/A',
        dutyTime: row['duty_time'] as String? ?? 'N/A',
        dutyEndTime: row['duty_end_time'] as String? ?? 'N/A',
        designation: row['designation'] as String? ?? 'N/A',
        email: row['email'] as String? ?? 'N/A',
        faceEmbedding: faceEmbedding,
      ));
    }
    return employees;
  }

  // --- Phase 7 & 8: Attendance and Payroll ---
  Future<void> logAttendanceEvent(String employeeId, String type, double distance, double confidence) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final eventData = {
        'id': _uuid.v4(),
        'client_event_id': _uuid.v4(),
        'store_id': 'default_store_id',
        'employee_id': employeeId,
        'event_type': type,
        'device_timestamp': DateTime.now().toIso8601String(),
        'face_distance': distance,
        'confidence': confidence,
        'status': 'SUCCESS'
      };
      
      await txn.insert('attendance_events', eventData);
      await insertOutbox(txn, 'attendance_events', 'INSERT', eventData);
    });
  }

  Future<void> savePayrollRecord(String employeeId, String monthYear, {double? bonus, double? deduction, int? paidAbsentDays}) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // Find existing
      final existing = await txn.query('payroll_records', where: 'employee_id = ? AND month_year = ?', whereArgs: [employeeId, monthYear]);
      
      final Map<String, dynamic> data = {
        'store_id': 'default_store_id',
        'employee_id': employeeId,
        'month_year': monthYear,
      };
      
      if (bonus != null) data['bonus'] = bonus;
      if (deduction != null) data['deduction'] = deduction;
      if (paidAbsentDays != null) data['paid_absent_days'] = paidAbsentDays;

      if (existing.isNotEmpty) {
        data['id'] = existing.first['id'];
        await txn.update('payroll_records', data, where: 'id = ?', whereArgs: [data['id']]);
        await insertOutbox(txn, 'payroll_records', 'UPDATE', data);
      } else {
        data['id'] = _uuid.v4();
        await txn.insert('payroll_records', data);
        await insertOutbox(txn, 'payroll_records', 'INSERT', data);
      }
    });
  }
}
