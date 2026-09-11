class BusinessModel {
  final String businessId;
  final String shopId;
  final String shopName;
  final String ownerName;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String status; // ACTIVE, PAUSED, SUSPENDED, DEACTIVATED
  final String timezone;
  final String currency;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final DateTime? pausedAt;
  final String? pausedBy;
  final String? pauseReason;

  BusinessModel({
    required this.businessId,
    required this.shopId,
    required this.shopName,
    required this.ownerName,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.status,
    this.timezone = 'Asia/Kolkata',
    this.currency = 'INR',
    required this.createdAt,
    this.approvedAt,
    this.approvedBy,
    this.pausedAt,
    this.pausedBy,
    this.pauseReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'shopId': shopId,
      'shopName': shopName,
      'ownerName': ownerName,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'status': status,
      'timezone': timezone,
      'currency': currency,
      'createdAt': createdAt.toIso8601String(),
      'approvedAt': approvedAt?.toIso8601String(),
      'approvedBy': approvedBy,
      'pausedAt': pausedAt?.toIso8601String(),
      'pausedBy': pausedBy,
      'pauseReason': pauseReason,
    };
  }

  factory BusinessModel.fromMap(Map<String, dynamic> map) {
    return BusinessModel(
      businessId: map['businessId'] ?? '',
      shopId: map['shopId'] ?? '',
      shopName: map['shopName'] ?? '',
      ownerName: map['ownerName'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      pincode: map['pincode'] ?? '',
      status: map['status'] ?? 'ACTIVE',
      timezone: map['timezone'] ?? 'Asia/Kolkata',
      currency: map['currency'] ?? 'INR',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      approvedAt: map['approvedAt'] != null
          ? DateTime.parse(map['approvedAt'])
          : null,
      approvedBy: map['approvedBy'],
      pausedAt: map['pausedAt'] != null
          ? DateTime.parse(map['pausedAt'])
          : null,
      pausedBy: map['pausedBy'],
      pauseReason: map['pauseReason'],
    );
  }
}
