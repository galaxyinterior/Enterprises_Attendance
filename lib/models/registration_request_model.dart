class RegistrationRequestModel {
  final String applicationId;
  final String ownerName;
  final String shopName;
  final String businessType;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final int employeeCount;
  final int kioskCount;
  final String notes;
  final String status; // PENDING, UNDER_REVIEW, APPROVED, REJECTED
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;

  RegistrationRequestModel({
    required this.applicationId,
    required this.ownerName,
    required this.shopName,
    required this.businessType,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.employeeCount,
    required this.kioskCount,
    required this.notes,
    required this.status,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'applicationId': applicationId,
      'ownerName': ownerName,
      'shopName': shopName,
      'businessType': businessType,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'employeeCount': employeeCount,
      'kioskCount': kioskCount,
      'notes': notes,
      'status': status,
      'submittedAt': submittedAt.toIso8601String(),
      'reviewedAt': reviewedAt?.toIso8601String(),
      'reviewedBy': reviewedBy,
      'rejectionReason': rejectionReason,
    };
  }

  factory RegistrationRequestModel.fromMap(Map<String, dynamic> map) {
    return RegistrationRequestModel(
      applicationId: map['applicationId'] ?? '',
      ownerName: map['ownerName'] ?? '',
      shopName: map['shopName'] ?? '',
      businessType: map['businessType'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      pincode: map['pincode'] ?? '',
      employeeCount: map['employeeCount'] ?? 0,
      kioskCount: map['kioskCount'] ?? 1,
      notes: map['notes'] ?? '',
      status: map['status'] ?? 'PENDING',
      submittedAt: map['submittedAt'] != null
          ? DateTime.parse(map['submittedAt'])
          : DateTime.now(),
      reviewedAt: map['reviewedAt'] != null
          ? DateTime.parse(map['reviewedAt'])
          : null,
      reviewedBy: map['reviewedBy'],
      rejectionReason: map['rejectionReason'],
    );
  }
}
