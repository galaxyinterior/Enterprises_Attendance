import 'package:flutter/material.dart';
import '../models/attendance_log.dart';
import '../repositories/attendance_repository.dart';
import '../services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/sync_service.dart';

class AttendanceLogsScreen extends StatefulWidget {
  final String storeId;
  const AttendanceLogsScreen({super.key, required this.storeId});

  @override
  State<AttendanceLogsScreen> createState() => _AttendanceLogsScreenState();
}

class _AttendanceLogsScreenState extends State<AttendanceLogsScreen> {
  final AttendanceRepository _attendanceRepo = AttendanceRepository();
  bool _isLoading = true;
  List<AttendanceLog> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    _logs = await _attendanceRepo.getAllLogs();
    setState(() => _isLoading = false);
  }

  Future<void> _manualSync() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Syncing to cloud...")));
    await SyncService.syncAllData(widget.storeId);
    await _loadLogs();
  }

  Future<void> _exportData() async {
    try {
      final logs = await _attendanceRepo.getAllLogs();
      if (logs.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No data to export.")));
        return;
      }

      String csvData = "ID,Employee ID,Name,Department,Punch Time,Punch Type,Confidence,Status\n";
      for (var log in logs) {
        csvData += "${log.id},${log.empId},${log.empName},${log.department},${log.punchTime},${log.punchType},${log.confidence},${log.status}\n";
      }

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/attendance_export.csv');
      await file.writeAsString(csvData);

      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: 'Attendance Logs Export');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to export: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance Logs"),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: "Export as CSV",
            onPressed: _exportData,
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            tooltip: "Manual Sync Now",
            onPressed: _manualSync,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: "Logout",
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<AttendanceLog>>(
        future: _attendanceRepo.getAllLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.redAccent)));
          }
          
          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
            return const Center(child: Text("No attendance logs found."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final punchType = log.punchType;
              final empName = log.empName;
              final empId = log.empId;
              final punchTime = log.punchTime.toString(); // or format it better
              final isSynced = log.isSynced == 1;

              return Card(
                color: Colors.grey[900],
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: punchType == 'IN' ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: punchType == 'IN' ? Colors.green : Colors.orange),
                    ),
                    child: Text(
                      punchType,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: punchType == 'IN' ? Colors.greenAccent : Colors.orangeAccent,
                      ),
                    ),
                  ),
                  title: Text(empName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: Text("$empId • $punchTime", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSynced ? Colors.blue.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSynced ? Icons.cloud_done : Icons.cloud_off,
                          size: 14,
                          color: isSynced ? Colors.blueAccent : Colors.redAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isSynced ? "SYNCED" : "OFFLINE",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSynced ? Colors.blueAccent : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
