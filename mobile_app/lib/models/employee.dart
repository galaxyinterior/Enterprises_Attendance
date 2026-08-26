class Employee {
  final int? id;
  final String empId;
  final String name;
  final String department;
  final String? createdAt;
  final List<double>? faceEmbedding;
  
  // New V2 Fields
  final String phone;
  final String dob;
  final String joiningDate;
  final String dutyTime;
  final String dutyEndTime;
  final String designation;
  final String email;
  final double monthlySalary;

  Employee({
    this.id,
    required this.empId,
    required this.name,
    required this.department,
    this.createdAt,
    this.faceEmbedding,
    this.phone = 'N/A',
    this.dob = 'N/A',
    this.joiningDate = 'N/A',
    this.dutyTime = 'N/A',
    this.dutyEndTime = 'N/A',
    this.designation = 'N/A',
    this.email = 'N/A',
    this.monthlySalary = 0.0,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'],
      empId: json['emp_id'] ?? '',
      name: json['name'] ?? '',
      department: json['department'] ?? '',
      createdAt: json['created_at'],
      faceEmbedding: json['face_embedding'] != null 
          ? List<double>.from(json['face_embedding']) 
          : null,
      phone: json['phone'] ?? 'N/A',
      dob: json['dob'] ?? 'N/A',
      joiningDate: json['joining_date'] ?? 'N/A',
      dutyTime: json['duty_time'] ?? 'N/A',
      dutyEndTime: json['duty_end_time'] ?? 'N/A',
      designation: json['designation'] ?? 'N/A',
      email: json['email'] ?? 'N/A',
      monthlySalary: (json['monthly_salary'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'emp_id': empId,
      'name': name,
      'department': department,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'face_embedding': faceEmbedding,
      'phone': phone,
      'dob': dob,
      'joining_date': joiningDate,
      'duty_time': dutyTime,
      'duty_end_time': dutyEndTime,
      'designation': designation,
      'email': email,
      'monthly_salary': monthlySalary,
    };
  }
}
