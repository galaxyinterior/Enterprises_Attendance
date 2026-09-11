import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../../models/registration_request_model.dart';
import '../../models/business_model.dart';
import 'email_notification_service.dart';

class ProvisioningResult {
  final bool success;
  final String shopId;
  final String adminEmail;
  final String kioskEmail;
  final bool emailSent;
  final String? errorMessage;

  ProvisioningResult({
    required this.success,
    required this.shopId,
    required this.adminEmail,
    required this.kioskEmail,
    required this.emailSent,
    this.errorMessage,
  });
}

class ShopProvisioningService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if Shop ID already exists in businesses collection
  Future<bool> checkShopIdExists(String shopId) async {
    final cleanId = shopId.trim().toUpperCase();
    final doc = await _firestore.collection(AppConstants.colBusinesses).doc(cleanId).get();
    return doc.exists;
  }

  /// Provision Shop & create Admin + Kiosk Firebase Auth accounts & send email
  Future<ProvisioningResult> provisionShop({
    required RegistrationRequestModel request,
    required String customShopId,
    required String adminPassword,
    required String kioskPassword,
    required String userEmail,
  }) async {
    final String shopId = customShopId.trim().toUpperCase();
    final String adminEmail = '$shopId@admin.in';
    final String kioskEmail = '$shopId@kiosk.in';
    final String recipientEmail = userEmail.trim();

    try {
      // 1. Verify Shop ID uniqueness
      final exists = await checkShopIdExists(shopId);
      if (exists) {
        return ProvisioningResult(
          success: false,
          shopId: shopId,
          adminEmail: adminEmail,
          kioskEmail: kioskEmail,
          emailSent: false,
          errorMessage: 'Shop ID "$shopId" already exists! Please enter a unique Shop ID.',
        );
      }

      // 2. Initialize secondary FirebaseApp to register users in Firebase Auth without logging out current Master Admin session
      FirebaseApp secondaryApp;
      try {
        secondaryApp = Firebase.app('ProvisioningApp');
      } catch (_) {
        secondaryApp = await Firebase.initializeApp(
          name: 'ProvisioningApp',
          options: Firebase.app().options,
        );
      }
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      String? adminUid;
      String? kioskUid;

      // Register Admin User in Firebase Authentication
      try {
        final adminCred = await secondaryAuth.createUserWithEmailAndPassword(
          email: adminEmail,
          password: adminPassword,
        );
        adminUid = adminCred.user?.uid;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          try {
            final cred = await secondaryAuth.signInWithEmailAndPassword(email: adminEmail, password: adminPassword);
            adminUid = cred.user?.uid;
          } catch (_) {}
        } else {
          rethrow;
        }
      }

      // Register Kiosk User in Firebase Authentication
      try {
        final kioskCred = await secondaryAuth.createUserWithEmailAndPassword(
          email: kioskEmail,
          password: kioskPassword,
        );
        kioskUid = kioskCred.user?.uid;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          try {
            final cred = await secondaryAuth.signInWithEmailAndPassword(email: kioskEmail, password: kioskPassword);
            kioskUid = cred.user?.uid;
          } catch (_) {}
        } else {
          rethrow;
        }
      }

      // Sign out secondary auth instance
      await secondaryAuth.signOut();

      // 3. Store Business Document in Firestore
      final bizModel = BusinessModel(
        businessId: shopId,
        shopId: shopId,
        shopName: request.shopName,
        ownerName: request.ownerName,
        email: recipientEmail,
        phone: request.phone,
        address: request.address,
        city: request.city,
        state: request.state,
        pincode: request.pincode,
        status: AppConstants.statusActive,
        createdAt: DateTime.now(),
        approvedAt: DateTime.now(),
        approvedBy: 'MASTER',
      );

      await _firestore.collection(AppConstants.colBusinesses).doc(shopId).set(bizModel.toMap());

      // 4. Save User records in Firestore users collection
      if (adminUid != null) {
        await _firestore.collection(AppConstants.colUsers).doc(adminUid).set({
          'uid': adminUid,
          'email': adminEmail,
          'role': AppConstants.roleShopAdmin,
          'businessId': shopId,
          'shopId': shopId,
          'ownerName': request.ownerName,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }

      if (kioskUid != null) {
        await _firestore.collection(AppConstants.colUsers).doc(kioskUid).set({
          'uid': kioskUid,
          'email': kioskEmail,
          'role': AppConstants.roleKiosk,
          'businessId': shopId,
          'shopId': shopId,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }

      // 5. Delete Application Request from registrationRequests collection upon approval
      await _firestore.collection(AppConstants.colRegistrationRequests).doc(request.applicationId).delete();

      // 6. Log Master Audit Trail
      await _firestore.collection(AppConstants.colMasterAuditLogs).add({
        'action': 'PROVISION_SHOP',
        'shopId': shopId,
        'shopName': request.shopName,
        'userEmail': recipientEmail,
        'timestamp': DateTime.now().toIso8601String(),
        'performedBy': 'MASTER',
      });

      // 7. Send Credentials Email to User
      final bool emailSent = await EmailNotificationService().sendApprovalCredentialsEmail(
        recipientEmail: recipientEmail,
        shopName: request.shopName,
        ownerName: request.ownerName,
        shopId: shopId,
        adminEmail: adminEmail,
        adminPassword: adminPassword,
        kioskEmail: kioskEmail,
        kioskPassword: kioskPassword,
      );

      return ProvisioningResult(
        success: true,
        shopId: shopId,
        adminEmail: adminEmail,
        kioskEmail: kioskEmail,
        emailSent: emailSent,
      );
    } catch (e) {
      return ProvisioningResult(
        success: false,
        shopId: shopId,
        adminEmail: adminEmail,
        kioskEmail: kioskEmail,
        emailSent: false,
        errorMessage: e.toString(),
      );
    }
  }
}
