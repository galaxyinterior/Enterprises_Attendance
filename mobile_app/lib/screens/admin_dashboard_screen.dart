import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String storeId;
  const AdminDashboardScreen({super.key, required this.storeId});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int totalEmployees = 0;
  int todaysPunches = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final emps = await DatabaseHelper.instance.getAllEmployees();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final logs = await DatabaseHelper.instance.getAllAttendanceLogs();
    
    final todayLogs = logs.where((log) => log.punchTime.startsWith(today)).toList();
    final uniquePunchedEmps = todayLogs.map((e) => e.empId).toSet().length;
    
    if (mounted) {
      setState(() {
        totalEmployees = emps.length;
        todaysPunches = uniquePunchedEmps;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    int absentCount = totalEmployees - todaysPunches;
    if (absentCount < 0) absentCount = 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Welcome to ${widget.storeId}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Card(
                      color: const Color(0xFF00BFFF),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const Icon(Icons.people, size: 48, color: Colors.white),
                            const SizedBox(height: 8),
                            Text("$totalEmployees", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                            const Text("Total Employees", style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const Icon(Icons.fingerprint, size: 48, color: Color(0xFF00BFFF)),
                            const SizedBox(height: 8),
                            Text("$todaysPunches", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87)),
                            const Text("Present Today", style: TextStyle(color: Colors.black54)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text("Today's Attendance Overview", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (totalEmployees > 0)
                SizedBox(
                  height: 250,
                  child: PieChart(
                    PieChartData(
                      sections: [
                        PieChartSectionData(
                          color: Colors.green,
                          value: todaysPunches.toDouble(),
                          title: '$todaysPunches\nPresent',
                          radius: 80,
                          titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        PieChartSectionData(
                          color: Colors.redAccent,
                          value: absentCount.toDouble(),
                          title: '$absentCount\nAbsent',
                          radius: 80,
                          titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                      centerSpaceRadius: 40,
                      sectionsSpace: 4,
                    ),
                  )
                )
              else
                const Center(child: Text("No employees added yet.")),
            ],
          ),
        ),
      ),
    );
  }
}
