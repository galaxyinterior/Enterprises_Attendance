class SalaryAdvanceModel {
  final String advanceId;
  final String businessId;
  final String employeeId;
  final String employeeName;
  final double amountGiven;
  final double monthlyDeduction;
  final double remainingBalance;
  final String notes;
  final DateTime dateGiven;
  final DateTime createdAt;

  SalaryAdvanceModel({
    required this.advanceId,
    required this.businessId,
    required this.employeeId,
    required this.employeeName,
    required this.amountGiven,
    required this.monthlyDeduction,
    required this.remainingBalance,
    required this.notes,
    required this.dateGiven,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'advanceId': advanceId,
      'businessId': businessId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'amountGiven': amountGiven,
      'monthlyDeduction': monthlyDeduction,
      'remainingBalance': remainingBalance,
      'notes': notes,
      'dateGiven': dateGiven.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SalaryAdvanceModel.fromMap(Map<String, dynamic> map) {
    return SalaryAdvanceModel(
      advanceId: map['advanceId'] ?? '',
      businessId: map['businessId'] ?? '',
      employeeId: map['employeeId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      amountGiven: (map['amountGiven'] ?? 0.0).toDouble(),
      monthlyDeduction: (map['monthlyDeduction'] ?? 0.0).toDouble(),
      remainingBalance: (map['remainingBalance'] ?? 0.0).toDouble(),
      notes: map['notes'] ?? '',
      dateGiven: map['dateGiven'] != null ? DateTime.parse(map['dateGiven']) : DateTime.now(),
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
    );
  }
}
