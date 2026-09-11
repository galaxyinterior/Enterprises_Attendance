class ShiftModel {
  final String shiftId;
  final String businessId;
  final String shiftName;
  final String startTime; // "10:00 AM" or "10:00"
  final String endTime; // "07:00 PM" or "19:00"
  final String checkInWindowStart; // "09:30 AM"
  final String checkInWindowEnd; // "10:30 AM"
  final String checkOutWindowStart; // "06:30 PM"
  final String checkOutWindowEnd; // "07:30 PM"
  final int gracePeriodMinutes; // e.g. 15 minutes
  final bool allowLateAttendance;
  final bool isOvernight;

  ShiftModel({
    required this.shiftId,
    required this.businessId,
    required this.shiftName,
    required this.startTime,
    required this.endTime,
    required this.checkInWindowStart,
    required this.checkInWindowEnd,
    required this.checkOutWindowStart,
    required this.checkOutWindowEnd,
    this.gracePeriodMinutes = 15,
    this.allowLateAttendance = true,
    this.isOvernight = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'shiftId': shiftId,
      'businessId': businessId,
      'shiftName': shiftName,
      'startTime': startTime,
      'endTime': endTime,
      'checkInWindowStart': checkInWindowStart,
      'checkInWindowEnd': checkInWindowEnd,
      'checkOutWindowStart': checkOutWindowStart,
      'checkOutWindowEnd': checkOutWindowEnd,
      'gracePeriodMinutes': gracePeriodMinutes,
      'allowLateAttendance': allowLateAttendance,
      'isOvernight': isOvernight,
    };
  }

  factory ShiftModel.fromMap(Map<String, dynamic> map) {
    return ShiftModel(
      shiftId: map['shiftId'] ?? '',
      businessId: map['businessId'] ?? '',
      shiftName: map['shiftName'] ?? '',
      startTime: map['startTime'] ?? '10:00',
      endTime: map['endTime'] ?? '19:00',
      checkInWindowStart: map['checkInWindowStart'] ?? '09:30',
      checkInWindowEnd: map['checkInWindowEnd'] ?? '10:30',
      checkOutWindowStart: map['checkOutWindowStart'] ?? '18:30',
      checkOutWindowEnd: map['checkOutWindowEnd'] ?? '19:30',
      gracePeriodMinutes: map['gracePeriodMinutes'] ?? 15,
      allowLateAttendance: map['allowLateAttendance'] ?? true,
      isOvernight: map['isOvernight'] ?? false,
    );
  }
}
