import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../models/employee.dart';
import '../models/attendance_log.dart';
import 'package:jiffy/jiffy.dart';

class PayrollScreen extends StatefulWidget {
  final String storeId;
  const PayrollScreen({super.key, required this.storeId});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  List<Employee> _employees = [];
  List<AttendanceLog> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final emps = await DatabaseHelper.instance.getAllEmployees();
    final logs = await DatabaseHelper.instance.getAllAttendanceLogs();
    
    setState(() {
      _employees = emps;
      _logs = logs;
      _isLoading = false;
    });
  }

  void _showPayrollBottomSheet(Employee emp) async {
    final now = DateTime.now();
    final currentMonthStr = "${now.year}-${now.month.toString().padLeft(2, '0')}";
    final daysInMonth = Jiffy.parseFromDateTime(now).daysInMonth;

    // Calculate present days
    final empLogs = _logs.where((l) => l.empId == emp.empId && l.punchTime.startsWith(currentMonthStr)).toList();
    // Unique days present
    final presentDaysSet = empLogs.map((l) => l.punchTime.split(' ')[0]).toSet();
    final presentCount = presentDaysSet.length;
    
    // Fetch Overrides
    final overrides = await DatabaseHelper.instance.getPayrollRecord(emp.empId, currentMonthStr);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _PayrollDetailsSheet(
          employee: emp,
          daysInMonth: daysInMonth,
          presentCount: presentCount,
          currentMonthStr: currentMonthStr,
          initialBonus: overrides?['bonus'] ?? 0.0,
          initialDeduction: overrides?['deduction'] ?? 0.0,
          initialPaidAbsent: overrides?['paid_absent_days'] ?? 0,
          onUpdate: _loadData,
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Staff Management & Payroll", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF00BFFF)))
        : _employees.isEmpty 
          ? const Center(child: Text("No employees found."))
          : ListView.builder(
              itemCount: _employees.length,
              itemBuilder: (context, index) {
                final emp = _employees[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF00BFFF),
                      child: Text(emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("ID: ${emp.empId} | Salary: ₹${emp.monthlySalary.toStringAsFixed(0)}"),
                    trailing: const Icon(Icons.calculate, color: Colors.green),
                    onTap: () => _showPayrollBottomSheet(emp),
                  ),
                );
              },
            ),
    );
  }
}

class _PayrollDetailsSheet extends StatefulWidget {
  final Employee employee;
  final int daysInMonth;
  final int presentCount;
  final String currentMonthStr;
  final double initialBonus;
  final double initialDeduction;
  final int initialPaidAbsent;
  final VoidCallback onUpdate;

  const _PayrollDetailsSheet({
    required this.employee,
    required this.daysInMonth,
    required this.presentCount,
    required this.currentMonthStr,
    required this.initialBonus,
    required this.initialDeduction,
    required this.initialPaidAbsent,
    required this.onUpdate,
  });

  @override
  State<_PayrollDetailsSheet> createState() => _PayrollDetailsSheetState();
}

class _PayrollDetailsSheetState extends State<_PayrollDetailsSheet> {
  late TextEditingController _salaryCtrl;
  late double _bonus;
  late double _deduction;
  late int _paidAbsent;

  @override
  void initState() {
    super.initState();
    _salaryCtrl = TextEditingController(text: widget.employee.monthlySalary.toStringAsFixed(0));
    _bonus = widget.initialBonus;
    _deduction = widget.initialDeduction;
    _paidAbsent = widget.initialPaidAbsent;
  }

  @override
  void dispose() {
    _salaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSalary() async {
    final val = double.tryParse(_salaryCtrl.text) ?? 0.0;
    await DatabaseHelper.instance.updateEmployeeSalary(widget.employee.empId, val);
    widget.onUpdate();
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Salary Updated")));
    setState(() {}); // Trigger recalc
  }

  Future<void> _saveOverrides() async {
    await DatabaseHelper.instance.savePayrollRecord(
      widget.employee.empId, 
      widget.currentMonthStr,
      bonus: _bonus,
      deduction: _deduction,
      paidAbsentDays: _paidAbsent
    );
    widget.onUpdate();
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Adjustments Saved")));
  }

  @override
  Widget build(BuildContext context) {
    final currentSalary = double.tryParse(_salaryCtrl.text) ?? 0.0;
    final perDay = currentSalary / widget.daysInMonth;
    
    // Days logic
    final elapsedDays = DateTime.now().day; // Or total days in month depending on policy
    final absentCount = elapsedDays - widget.presentCount;
    
    // Final Calculation
    final billableDays = widget.presentCount + _paidAbsent;
    final basePay = billableDays * perDay;
    final finalPay = basePay + _bonus - _deduction;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${widget.employee.name}'s Payroll", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(widget.currentMonthStr, style: const TextStyle(color: Colors.grey)),
            const Divider(height: 32),
            
            // Set Salary
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _salaryCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Monthly Salary (₹)", border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _saveSalary, child: const Text("Update")),
              ],
            ),
            const SizedBox(height: 16),
            
            Text("Per-Day Salary: ₹${perDay.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w500)),
            Text("Present: ${widget.presentCount} days | Absent: ${absentCount > 0 ? absentCount : 0} days"),
            const Divider(height: 32),

            // Adjustments
            const Text("Adjustments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Mark Absent as Paid Days:"),
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () {
                      if (_paidAbsent > 0) setState(() => _paidAbsent--);
                    }),
                    Text("$_paidAbsent", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: () {
                      setState(() => _paidAbsent++);
                    }),
                  ],
                )
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Bonus (₹)", prefixText: "+"),
                    onChanged: (val) => setState(() => _bonus = double.tryParse(val) ?? 0.0),
                    controller: TextEditingController(text: _bonus.toStringAsFixed(0))..selection = TextSelection.collapsed(offset: _bonus.toStringAsFixed(0).length),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Penalty/Deduction (₹)", prefixText: "-"),
                    onChanged: (val) => setState(() => _deduction = double.tryParse(val) ?? 0.0),
                    controller: TextEditingController(text: _deduction.toStringAsFixed(0))..selection = TextSelection.collapsed(offset: _deduction.toStringAsFixed(0).length),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveOverrides,
                child: const Text("Save Adjustments"),
              ),
            ),
            const Divider(height: 32),

            // Final
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Estimated Final Payout:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text("₹${finalPay.toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
