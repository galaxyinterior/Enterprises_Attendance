import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../models/attendance_log.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ReportsScreen extends StatefulWidget {
  final String storeId;
  const ReportsScreen({super.key, required this.storeId});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isExporting = false;

  Future<void> _exportToExcel() async {
    setState(() => _isExporting = true);
    try {
      final logs = await DatabaseHelper.instance.getAllAttendanceLogs();
      
      final xlsio.Workbook workbook = xlsio.Workbook();
      final xlsio.Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Attendance Logs';
      
      sheet.getRangeByName('A1').setText('Emp ID');
      sheet.getRangeByName('B1').setText('Name');
      sheet.getRangeByName('C1').setText('Department');
      sheet.getRangeByName('D1').setText('Time');
      sheet.getRangeByName('E1').setText('Type');
      sheet.getRangeByName('F1').setText('Status');

      final xlsio.Style headerStyle = workbook.styles.add('HeaderStyle');
      headerStyle.bold = true;
      sheet.getRangeByName('A1:F1').cellStyle = headerStyle;

      for (int i = 0; i < logs.length; i++) {
        final log = logs[i];
        final row = i + 2;
        sheet.getRangeByIndex(row, 1).setText(log.empId);
        sheet.getRangeByIndex(row, 2).setText(log.empName);
        sheet.getRangeByIndex(row, 3).setText(log.department);
        sheet.getRangeByIndex(row, 4).setText(log.punchTime);
        sheet.getRangeByIndex(row, 5).setText(log.punchType);
        sheet.getRangeByIndex(row, 6).setText(log.status);
      }

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/Attendance_Report.xlsx';
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Exported Successfully!")));
        await Share.shareXFiles([XFile(path)], text: 'Attendance Report');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export Failed: $e")));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance Reports", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<List<AttendanceLog>>(
        future: DatabaseHelper.instance.getAllAttendanceLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00BFFF)));
          }
          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
            return const Center(child: Text("No attendance logs found."));
          }
          
          return ListView.builder(
            itemCount: logs.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final log = logs[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: log.punchType == 'IN' ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                    child: Icon(
                      log.punchType == 'IN' ? Icons.login : Icons.logout,
                      color: log.punchType == 'IN' ? Colors.green : Colors.orange,
                    ),
                  ),
                  title: Text(log.empName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${log.punchTime.split(' ')[0]} at ${log.punchTime.split(' ')[1]}\n${log.status}"),
                  trailing: Text(log.punchType, style: TextStyle(color: log.punchType == 'IN' ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isExporting ? null : _exportToExcel,
        label: _isExporting ? const Text("Exporting...") : const Text("Export Excel"),
        icon: _isExporting ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.download),
        backgroundColor: const Color(0xFF00BFFF),
        foregroundColor: Colors.white,
      ),
    );
  }
}
