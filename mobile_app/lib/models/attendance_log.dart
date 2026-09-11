class AttendanceLog {
  final int? id;
  final String empId;
  final String empName;
  final String department;
  final String punchTime;
  final String punchType; // 'IN' or 'OUT'
  final double confidence;
  final String status; // 'PRESENT', 'LATE'
  final int isSynced; // 0 = Pending, 1 = Synced to Server

  AttendanceLog({
    this.id,
    required this.empId,
    required this.empName,
    required this.department,
    required this.punchTime,
    required this.punchType,
    required this.confidence,
    required this.status,
    this.isSynced = 0,
  });

  factory AttendanceLog.fromMap(Map<String, dynamic> map) {
    return AttendanceLog(
      id: map['id'],
      empId: map['emp_id'] ?? '',
      empName: map['emp_name'] ?? '',
      department: map['department'] ?? '',
      punchTime: map['punch_time'] ?? '',
      punchType: map['punch_type'] ?? 'IN',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
      status: map['status'] ?? 'PRESENT',
      isSynced: map['is_synced'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'emp_id': empId,
      'emp_name': empName,
      'department': department,
      'punch_time': punchTime,
      'punch_type': punchType,
      'confidence': confidence,
      'status': status,
      'is_synced': isSynced,
    };
  }

  Map<String, dynamic> toSyncPayload() {
    return {
      'local_id': id,
      'emp_id': empId,
      'emp_name': empName,
      'department': department,
      'punch_time': punchTime,
      'punch_type': punchType,
      'confidence': confidence,
      'status': status,
    };
  }
}
