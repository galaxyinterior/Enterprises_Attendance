import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'admin_dashboard_screen.dart';
import 'employee_list_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'payroll_screen.dart';

class AdminPanel extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String storeId;
  
  const AdminPanel({super.key, required this.cameras, required this.storeId});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      AdminDashboardScreen(storeId: widget.storeId),
      EmployeeListScreen(cameras: widget.cameras, storeId: widget.storeId),
      ReportsScreen(storeId: widget.storeId),
      PayrollScreen(storeId: widget.storeId),
      SettingsScreen(storeId: widget.storeId),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          setState(() {
            _currentIndex = idx;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Employees'),
          NavigationDestination(icon: Icon(Icons.analytics), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.attach_money), label: 'Payroll'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
