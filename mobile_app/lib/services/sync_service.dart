import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'database_helper.dart';
import 'api_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/employee.dart';
import '../models/store_config.dart';

class SyncService {
  static Future<void> syncAllData(String storeId) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      debugPrint("[SyncService] Device is offline. Skipping cloud sync.");
      return;
    }

    final isServerAlive = true; // No longer checking python API, relying on Firebase availability.

    // Step 0: Sync Store Config (Download from Cloud to Local)
    try {
      final configDoc = await FirebaseFirestore.instance.collection('stores').doc(storeId).collection('config').doc('main').get();
      if (configDoc.exists && configDoc.data() != null) {
         final remoteConfig = StoreConfig.fromMap(configDoc.data()!);
         await DatabaseHelper.instance.saveStoreConfig(remoteConfig);
         debugPrint("[SyncService] Store config downloaded from Firestore.");
      }
    } catch(e) {
      debugPrint("[SyncService] Failed to sync config: $e");
    }

    // Step 1: Auto-Restore logic. If local DB has 0 employees, fetch everything from Cloud.
    try {
      final localEmployees = await DatabaseHelper.instance.getAllEmployees();
      if (localEmployees.isEmpty) {
        debugPrint("[SyncService] Local DB empty. Auto-restoring from Firestore for store: $storeId");
        final snapshot = await FirebaseFirestore.instance.collection('stores').doc(storeId).collection('employees').get();
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final emp = Employee(
            empId: data['emp_id'] ?? data['empId'] ?? doc.id,
            name: data['name'] ?? 'Unknown',
            department: data['department'] ?? 'General',
            faceEmbedding: data['face_embedding'] != null ? List<double>.from(data['face_embedding']) : null,
          );
          await DatabaseHelper.instance.insertEmployee(emp);
          
          // Note: The photo file won't be auto-restored perfectly unless we also upload images to Firebase Storage. 
          // For now, we restore the embedding so face recognition continues to work immediately.
        }
        await DatabaseHelper.instance.markEmployeesAsSynced(snapshot.docs.map((e) => e.id).toList());
      }
    } catch (e) {
      debugPrint("[SyncService] Failed auto-restore: $e");
    }

    // Step 2: Upload Unsynced Employees to Cloud Firestore
    try {
      final unsyncedEmployees = await DatabaseHelper.instance.getUnsyncedEmployees();
      if (unsyncedEmployees.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        List<String> syncedEmpIds = [];
        for (var emp in unsyncedEmployees) {
          final docRef = FirebaseFirestore.instance.collection('stores').doc(storeId).collection('employees').doc(emp.empId);
          batch.set(docRef, {
            'emp_id': emp.empId,
            'name': emp.name,
            'department': emp.department,
            'face_embedding': emp.faceEmbedding,
            'last_synced': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          syncedEmpIds.add(emp.empId);
        }
        await batch.commit();
        await DatabaseHelper.instance.markEmployeesAsSynced(syncedEmpIds);
        debugPrint("[SyncService] Synced ${syncedEmpIds.length} employees to Firestore.");
      }
    } catch (e) {
      debugPrint("[SyncService] Failed to upload employees to Firestore: $e");
    }

    // Step 2: Upload Unsynced Attendance Logs to Cloud Firestore
    final unsyncedLogs = await DatabaseHelper.instance.getUnsyncedLogs();
    if (unsyncedLogs.isNotEmpty) {
      List<int> syncedLocalIds = [];
      try {
        final batch = FirebaseFirestore.instance.batch();
        
        for (var log in unsyncedLogs) {
          final docRef = FirebaseFirestore.instance.collection('stores').doc(storeId).collection('attendance_logs').doc();
          batch.set(docRef, log.toSyncPayload());
          if (log.id != null) {
            syncedLocalIds.add(log.id!);
          }
        }
        
        await batch.commit();
        
        if (syncedLocalIds.isNotEmpty) {
          await DatabaseHelper.instance.markLogsAsSynced(syncedLocalIds);
          debugPrint("[SyncService] Synced ${syncedLocalIds.length} logs to Firestore.");
        }
      } catch (e) {
        debugPrint("[SyncService] Failed to upload logs to Firestore: $e");
      }
    }
  }

  static Future<void> pushStoreConfig(String storeId, StoreConfig config) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) return;
    
    try {
      await FirebaseFirestore.instance.collection('stores').doc(storeId).collection('config').doc('main').set(config.toMap(), SetOptions(merge: true));
      debugPrint("[SyncService] Store config uploaded to Firestore.");
    } catch (e) {
      debugPrint("[SyncService] Failed to upload config: $e");
    }
  }
}
