import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'database_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SyncService {
  static bool _isSyncing = false;
  static bool _isUploadingOutbox = false;

  /// Fast-path sync to upload pending records (e.g. immediately after attendance punch)
  /// without incurring expensive remote data downloads.
  static Future<void> uploadPendingOutbox(String storeId) async {
    if (_isUploadingOutbox) return;

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return;
    }

    _isUploadingOutbox = true;
    try {
      await _processOutbox(storeId);
    } catch (e) {
      debugPrint("[SyncService] Upload outbox failed: $e");
    } finally {
      _isUploadingOutbox = false;
    }
  }

  static Future<void> syncAllData(String storeId) async {
    if (_isSyncing) return;
    
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      debugPrint("[SyncService] Device is offline. Skipping cloud sync.");
      return;
    }

    _isSyncing = true;
    try {
      // 1. Download missing data (Stores, Employees, Configs)
      await _downloadRemoteData(storeId);

      // 2. Process Local Outbox (Upload)
      await _processOutbox(storeId);
      
    } catch (e) {
      debugPrint("[SyncService] Sync failed: $e");
    } finally {
      _isSyncing = false;
    }
  }

  static Future<void> _downloadRemoteData(String storeId) async {
    try {
      // Note: Implementation relies on fetching delta updates using `updated_at`
      // For now, doing a bulk sync or overriding local tables.
      debugPrint("[SyncService] Downloading remote data...");
      
      // Employees
      final remoteEmployees = await Supabase.instance.client
          .from('employees')
          .select()
          .eq('store_id', storeId);
      debugPrint("[SyncService] Fetched ${remoteEmployees.length} remote employees.");

      // Biometrics
      final remoteBiometrics = await Supabase.instance.client
          .from('biometric_profiles')
          .select()
          .eq('store_id', storeId);
      debugPrint("[SyncService] Fetched ${remoteBiometrics.length} remote biometrics.");
          
      // TODO: Merge biometrics into local DB
      
    } catch (e) {
      debugPrint("Error downloading remote data: $e");
    }
  }

  static Future<void> _processOutbox(String storeId) async {
    debugPrint("[SyncService] Processing outbox...");
    // Fetch pending outbox records
    final db = await DatabaseHelper.instance.database;
    final pendingRecords = await db.query(
      'outbox',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );

    for (var record in pendingRecords) {
      try {
        final id = record['id'] as int;
        final tableName = record['table_name'] as String;
        final operation = record['operation'] as String;
        final payload = jsonDecode(record['payload'] as String);
        
        // Ensure store_id is attached if missing
        if (!payload.containsKey('store_id')) {
           payload['store_id'] = storeId;
        }

        if (operation == 'INSERT' || operation == 'UPDATE') {
          // Supabase upsert
          await Supabase.instance.client
              .from(tableName)
              .upsert(payload);
        } else if (operation == 'DELETE') {
          // Supabase delete
          await Supabase.instance.client
              .from(tableName)
              .delete()
              .eq('id', payload['id']);
        }

        // Mark as synced by deleting from outbox
        await db.delete('outbox', where: 'id = ?', whereArgs: [id]);
        debugPrint("[SyncService] Synced outbox record $id for table $tableName");

      } catch (e) {
        debugPrint("[SyncService] Failed to sync outbox record ${record['id']}: $e");
        // Mark as failed or increment retry count
        await db.update(
          'outbox', 
          {'status': 'failed', 'last_error': e.toString()},
          where: 'id = ?',
          whereArgs: [record['id']]
        );
      }
    }
  }
}
