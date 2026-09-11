import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/employee.dart';
import '../models/attendance_log.dart';

class ApiService {
  // Use 10.0.2.2 for Android Emulator, localhost for iOS/Web, or custom Server IP
  static String baseUrl = "http://10.0.2.2:8000/api";

  static Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Recognize Frame Image from Mobile Camera
  static Future<Map<String, dynamic>?> recognizeFaceFrame(File imageFile, {String? manualPunchType}) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/recognize'));
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      
      if (manualPunchType != null && manualPunchType != 'AUTO') {
        request.fields['manual_punch_type'] = manualPunchType;
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 4));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint("API Recognize error: $e");
    }
    return null;
  }

  // Register Employee with Photo
  static Future<bool> registerEmployee({
    required String empId,
    required String name,
    required String department,
    required File photoFile,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/register'));
      request.fields['emp_id'] = empId;
      request.fields['name'] = name;
      request.fields['department'] = department;
      request.files.add(await http.MultipartFile.fromPath('file', photoFile.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("API Register error: $e");
      return false;
    }
  }

  // Fetch Master Employees from Cloud
  static Future<List<Employee>> fetchEmployeesFromCloud() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/sync/employees'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List list = data['employees'] ?? [];
        return list.map((json) => Employee.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint("API Fetch Employees error: $e");
    }
    return [];
  }

  // Push Lightweight Attendance Payload to Cloud
  static Future<List<int>> uploadAttendanceLogs(List<AttendanceLog> unsyncedLogs) async {
    try {
      final payload = {
        'records': unsyncedLogs.map((log) => log.toSyncPayload()).toList()
      };

      final response = await http.post(
        Uri.parse('$baseUrl/sync/attendance'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List ids = data['synced_local_ids'] ?? [];
        return ids.cast<int>();
      }
    } catch (e) {
      debugPrint("API Upload Logs error: $e");
    }
    return [];
  }
}
