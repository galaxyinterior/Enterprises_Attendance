import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../models/employee_model.dart';
import '../auth/login_screen.dart';
import 'add_employee_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String shopId;
  final String businessId;

  const AdminDashboardScreen({
    super.key,
    required this.shopId,
    required this.businessId,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.cardDark,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SHOP ADMIN CONSOLE', style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Shop ID: ${widget.shopId}', style: GoogleFonts.inter(color: AppColors.textSaffron, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.sindoorRed),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar Navigation
          NavigationRail(
            backgroundColor: AppColors.cardDark,
            selectedIndex: _selectedNavIndex,
            onDestinationSelected: (index) => setState(() => _selectedNavIndex = index),
            labelType: NavigationRailLabelType.all,
            selectedIconTheme: const IconThemeData(color: AppColors.kesariSaffron),
            selectedLabelTextStyle: GoogleFonts.inter(color: AppColors.kesariSaffron, fontWeight: FontWeight.bold),
            unselectedIconTheme: const IconThemeData(color: AppColors.textMuted),
            unselectedLabelTextStyle: GoogleFonts.inter(color: AppColors.textMuted),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), label: Text('Overview')),
              NavigationRailDestination(icon: Icon(Icons.people_alt_outlined), label: Text('Staff Directory')),
              NavigationRailDestination(icon: Icon(Icons.schedule_outlined), label: Text('Shifts')),
              NavigationRailDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: Text('Payroll & Udhaar')),
              NavigationRailDestination(icon: Icon(Icons.campaign_outlined), label: Text('Announcements')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1, color: AppColors.cardBorderDark),
          
          // Main Content View
          Expanded(
            child: IndexedStack(
              index: _selectedNavIndex,
              children: [
                _buildOverviewTab(),
                _buildStaffDirectoryTab(),
                _buildShiftsTab(),
                _buildPayrollUdhaarTab(),
                _buildAnnouncementsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Today\'s Attendance Summary', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildSummaryTile('Present Today', '18', AppColors.pannaEmerald, Icons.check_circle_outline)),
              const SizedBox(width: 12),
              Expanded(child: _buildSummaryTile('Late Arrivals', '3', AppColors.haldiGold, Icons.access_time_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _buildSummaryTile('Absent', '2', AppColors.sindoorRed, Icons.cancel_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _buildSummaryTile('Pending Checkout', '4', AppColors.royalPurple, Icons.exit_to_app_rounded)),
            ],
          ),
          const SizedBox(height: 32),
          Text('Recent Live Attendance Stream', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorderDark),
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(AppConstants.colBusinesses)
                  .doc(widget.businessId)
                  .collection(AppConstants.colAttendance)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Text('No attendance records logged yet today.', style: GoogleFonts.inter(color: AppColors.textMuted));
                }
                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return ListTile(
                      leading: const CircleAvatar(backgroundColor: AppColors.kesariSaffron, child: Icon(Icons.person, color: Colors.white)),
                      title: Text(data['employeeName'] ?? 'Employee', style: const TextStyle(color: AppColors.textPrimary)),
                      subtitle: Text('Status: ${data['status']} | Date: ${data['date']}', style: const TextStyle(color: AppColors.textMuted)),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTile(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          Text(title, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildStaffDirectoryTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Employee Directory', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.saffronGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
                  label: const Text('ADD NEW EMPLOYEE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AddEmployeeScreen(
                          businessId: widget.businessId,
                          shopId: widget.shopId,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(AppConstants.colBusinesses)
                  .doc(widget.businessId)
                  .collection(AppConstants.colEmployees)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.kesariSaffron));

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Text('No staff members added yet. Click "Add New Employee" to enroll staff.', style: GoogleFonts.inter(color: AppColors.textMuted)),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final emp = EmployeeModel.fromMap(docs[index].data() as Map<String, dynamic>);
                    return Card(
                      color: AppColors.cardDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.cardBorderDark),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.kesariSaffron,
                          child: Text(emp.fullName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(emp.fullName, style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                        subtitle: Text('Code: ${emp.employeeCode} | Dept: ${emp.department} | Salary: ₹${emp.monthlySalary}/mo', style: GoogleFonts.inter(color: AppColors.textMuted)),
                        trailing: Chip(
                          label: Text(emp.faceEnrollmentStatus ? 'Face Enrolled ✓' : 'Face Pending ⚠', style: const TextStyle(color: Colors.white, fontSize: 11)),
                          backgroundColor: emp.faceEnrollmentStatus ? AppColors.pannaEmerald : AppColors.haldiGold,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftsTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Shift Engine Configuration', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Card(
            color: AppColors.cardDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.cardBorderDark),
            ),
            child: ListTile(
              title: const Text('Morning Shift (Default)', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              subtitle: const Text('Check-in: 10:00 AM - 10:30 AM | Checkout: 06:30 PM - 07:30 PM | Grace: 15 mins', style: TextStyle(color: AppColors.textMuted)),
              trailing: const Icon(Icons.edit, color: AppColors.haldiGold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollUdhaarTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Staff Advance (Udhaar) & Payroll Ledger', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorderDark),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sample Udhaar Calculation:', style: GoogleFonts.outfit(color: AppColors.haldiGold, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Staff: Ravi Kumar | Base Salary: ₹18,000/month', style: TextStyle(color: AppColors.textPrimary)),
                const Text('Advance Given: ₹3,000 | Monthly Installment Deduction: ₹1,000', style: TextStyle(color: AppColors.textMuted)),
                const Divider(color: AppColors.cardBorderDark),
                Text('Net Salary Payable this month: ₹17,000', style: GoogleFonts.outfit(color: AppColors.pannaEmerald, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsTab() {
    final textCtrl = TextEditingController();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Broadcast Voice Announcement / Alert', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          TextField(
            controller: textCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Enter message to broadcast on Entrance Kiosk device...',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.inputBgDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.cardBorderDark),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.cardBorderDark),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.kesariSaffron),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.sindoorRed),
            icon: const Icon(Icons.campaign, color: Colors.white),
            label: const Text('BROADCAST EMERGENCY ALERT NOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Emergency alert broadcasted to Kiosk device!')),
              );
            },
          ),
        ],
      ),
    );
  }
}

