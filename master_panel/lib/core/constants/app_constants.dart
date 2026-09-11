class AppConstants {
  static const String appName = 'Master Control Panel - Smart Attendance SaaS';

  // User Roles
  static const String roleMaster = 'MASTER';
  static const String roleShopAdmin = 'SHOP_ADMIN';
  static const String roleKiosk = 'KIOSK';

  // Business Statuses
  static const String statusPending = 'PENDING';
  static const String statusUnderReview = 'UNDER_REVIEW';
  static const String statusApproved = 'APPROVED';
  static const String statusRejected = 'REJECTED';
  static const String statusActive = 'ACTIVE';
  static const String statusPaused = 'PAUSED';
  static const String statusSuspended = 'SUSPENDED';
  static const String statusDeactivated = 'DEACTIVATED';

  // Firestore Collections
  static const String colRegistrationRequests = 'registrationRequests';
  static const String colBusinesses = 'businesses';
  static const String colUsers = 'users';
  static const String colMasterAuditLogs = 'masterAuditLogs';
}
