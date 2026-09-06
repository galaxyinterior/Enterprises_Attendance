import '../models/employee.dart';
import '../services/database_helper.dart';

class EmployeeRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Employee>> getAllEmployees() async {
    return await _dbHelper.getAllEmployees();
  }

  Future<void> saveEmployee(Employee employee) async {
    await _dbHelper.insertEmployee(employee);
  }

  Future<void> deleteEmployee(String empId, String storeId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('employees', where: 'emp_id = ?', whereArgs: [empId]);
      await _dbHelper.insertOutbox(txn, 'employees', 'DELETE', {'emp_id': empId, 'store_id': storeId});
    });
  }

  Future<Employee?> getEmployeeById(String empId) async {
    final employees = await _dbHelper.getAllEmployees();
    try {
      return employees.firstWhere((e) => e.empId == empId);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateEmployeeSalary(String empId, double newSalary) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.update('employees', {'monthly_salary': newSalary}, where: 'emp_id = ?', whereArgs: [empId]);
      await _dbHelper.insertOutbox(txn, 'employees', 'UPDATE', {'emp_id': empId, 'monthly_salary': newSalary});
    });
  }

  Future<Map<String, dynamic>?> getPayrollRecord(String empId, String monthYear) async {
    final db = await _dbHelper.database;
    final result = await db.query('payroll_records', where: 'employee_id = ? AND month_year = ?', whereArgs: [empId, monthYear]);
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<void> savePayrollRecord(String empId, String monthYear, {double? bonus, double? deduction, int? paidAbsentDays}) async {
    await _dbHelper.savePayrollRecord(empId, monthYear, bonus: bonus, deduction: deduction, paidAbsentDays: paidAbsentDays);
  }
}
