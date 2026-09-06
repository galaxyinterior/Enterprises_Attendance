import '../models/attendance_log.dart';
import '../services/database_helper.dart';

class AttendanceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> logAttendance(AttendanceLog log) async {
    // Bridges legacy AttendanceLog to new V2 attendance_events
    await _dbHelper.logAttendanceEvent(
      log.empId, 
      log.punchType, 
      1.0, // distance placeholder since log only has confidence
      log.confidence
    );
  }

  Future<List<AttendanceLog>> getAllLogs() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT ae.id, ae.employee_id as emp_id, e.name as emp_name, e.department, 
             ae.device_timestamp as punch_time, ae.event_type as punch_type, 
             ae.confidence, ae.status, ae.is_synced
      FROM attendance_events ae
      LEFT JOIN employees e ON ae.employee_id = e.emp_id
      ORDER BY ae.device_timestamp DESC
    ''');
    
    return result.map((row) => AttendanceLog.fromMap(row)).toList();
  }

  Future<List<AttendanceLog>> getLogsForEmployee(String empId) async {
    final allLogs = await getAllLogs();
    return allLogs.where((log) => log.empId == empId).toList();
  }

  Future<String?> getLastPunch(String empId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT event_type FROM attendance_events 
      WHERE employee_id = ? 
      ORDER BY device_timestamp DESC LIMIT 1
    ''', [empId]);
    if (result.isNotEmpty) {
      return result.first['event_type'] as String?;
    }
    return null;
  }

  Future<int> getPresentDaysThisMonth(String empId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final monthPrefix = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT substr(device_timestamp, 1, 10)) as count 
      FROM attendance_events 
      WHERE employee_id = ? AND device_timestamp LIKE ?
    ''', [empId, '$monthPrefix%']);
    
    return (result.first['count'] as int?) ?? 0;
  }

  Future<String?> getTodaysCheckInTime(String empId) async {
    final db = await _dbHelper.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = await db.rawQuery('''
      SELECT device_timestamp FROM attendance_events 
      WHERE employee_id = ? AND device_timestamp LIKE ? AND event_type = 'IN'
      ORDER BY device_timestamp ASC LIMIT 1
    ''', [empId, '$today%']);
    
    if (result.isNotEmpty) {
      return (result.first['device_timestamp'] as String).substring(11, 16);
    }
    return null;
  }
}
