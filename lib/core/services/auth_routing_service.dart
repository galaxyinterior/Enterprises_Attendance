import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../../models/business_model.dart';

class AuthRoutingService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  // Login user and fetch role & business info
  Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;

      // Check Master User collection
      final userDoc = await _firestore.collection(AppConstants.colUsers).doc(uid).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        final role = data['role'] ?? AppConstants.roleShopAdmin;
        final businessId = data['businessId'] ?? '';

        if (role == AppConstants.roleMaster) {
          return {
            'role': AppConstants.roleMaster,
            'uid': uid,
            'email': email,
          };
        }

        // Fetch business profile to verify active status
        if (businessId.isNotEmpty) {
          final bizDoc = await _firestore
              .collection(AppConstants.colBusinesses)
              .doc(businessId)
              .get();

          if (bizDoc.exists) {
            final bizModel = BusinessModel.fromMap(bizDoc.data()!);
            return {
              'role': role,
              'uid': uid,
              'email': email,
              'businessId': businessId,
              'business': bizModel,
            };
          }
        }

        return {
          'role': role,
          'uid': uid,
          'email': email,
          'businessId': businessId,
        };
      } else {
        // Check if email format identifies Kiosk or Admin fallback
        if (email.endsWith('@kiosk.in')) {
          String shopId = email.split('@').first.toUpperCase();
          return {
            'role': AppConstants.roleKiosk,
            'uid': uid,
            'email': email,
            'shopId': shopId,
          };
        } else if (email.endsWith('@admin.in')) {
          String shopId = email.split('@').first.toUpperCase();
          return {
            'role': AppConstants.roleShopAdmin,
            'uid': uid,
            'email': email,
            'shopId': shopId,
          };
        } else if (email == 'master@admin.com') {
          return {
            'role': AppConstants.roleMaster,
            'uid': uid,
            'email': email,
          };
        }
      }

      return {
        'role': AppConstants.roleShopAdmin,
        'uid': uid,
        'email': email,
      };
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
