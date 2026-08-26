import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../models/employee.dart';
import '../services/database_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/ml_service.dart';
import '../services/sync_service.dart';
import 'employee_list_screen.dart'; // For CameraCaptureScreen

class FaceDataScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String storeId;
  const FaceDataScreen({super.key, required this.cameras, required this.storeId});

  @override
  State<FaceDataScreen> createState() => _FaceDataScreenState();
}

class _FaceDataScreenState extends State<FaceDataScreen> {
  final _empIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _joiningDateController = TextEditingController();
  final _dutyTimeController = TextEditingController();
  final _dutyEndTimeController = TextEditingController();
  final _designationController = TextEditingController();
  final _emailController = TextEditingController();
  String _selectedDept = 'Engineering';
  File? _capturedImage;
  bool _isRegistering = false;

  void _capturePhoto() async {
    final file = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => CameraCaptureScreen(cameras: widget.cameras),
      ),
    );
    if (file != null) {
      setState(() {
        _capturedImage = file;
      });
    }
  }

  void _registerFaceData() async {
    if (_empIdController.text.isEmpty || _nameController.text.isEmpty || _capturedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill required fields & capture a face photo.")),
      );
      return;
    }

    setState(() {
      _isRegistering = true;
    });

    final inputImage = InputImage.fromFile(_capturedImage!);
    final faceDetector = FaceDetector(options: FaceDetectorOptions());
    final faces = await faceDetector.processImage(inputImage);
    faceDetector.close();

    if (faces.isEmpty) {
      setState(() => _isRegistering = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No face detected in photo! Please retake."), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final face = faces.first;
    final bbox = {
      'x': face.boundingBox.left,
      'y': face.boundingBox.top,
      'width': face.boundingBox.width,
      'height': face.boundingBox.height,
    };

    final mlService = MLService();
    await mlService.initialize();
    final embedding = await mlService.getEmbedding(_capturedImage!, bbox);

    if (!mounted) return;

    setState(() {
      _isRegistering = false;
    });

    if (embedding != null) {
      String? photoUrl;
      final empId = _empIdController.text.trim();
      
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final facesDir = Directory('${appDir.path}/employee_faces');
        if (!await facesDir.exists()) {
          await facesDir.create(recursive: true);
        }
        await _capturedImage!.copy('${facesDir.path}/$empId.jpg');
      } catch (e) {
        debugPrint("Error saving photo locally: $e");
      }

      try {
        final newEmp = Employee(
          empId: empId,
          name: _nameController.text.trim(),
          department: _selectedDept,
          faceEmbedding: embedding,
          phone: _phoneController.text.trim().isEmpty ? 'N/A' : _phoneController.text.trim(),
          dob: _dobController.text.trim().isEmpty ? 'N/A' : _dobController.text.trim(),
          joiningDate: _joiningDateController.text.trim().isEmpty ? 'N/A' : _joiningDateController.text.trim(),
          dutyTime: _dutyTimeController.text.trim().isEmpty ? 'N/A' : _dutyTimeController.text.trim(),
          dutyEndTime: _dutyEndTimeController.text.trim().isEmpty ? 'N/A' : _dutyEndTimeController.text.trim(),
          designation: _designationController.text.trim().isEmpty ? 'N/A' : _designationController.text.trim(),
          email: _emailController.text.trim().isEmpty ? 'N/A' : _emailController.text.trim(),
        );
        await DatabaseHelper.instance.insertEmployee(newEmp);

        SyncService.syncAllData(widget.storeId);
      } catch (e) {
        debugPrint("Error saving employee to DB: $e");
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Face Data Registered Successfully!"), backgroundColor: Colors.green),
      );

      Navigator.pop(context); // Go back to list
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration failed. Ensure face is clearly visible."), backgroundColor: Colors.redAccent),
      );
    }
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          prefixIcon: Icon(icon, color: const Color(0xFF00BFFF)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Employee Profile", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Register New Employee",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00BFFF)),
            ),
            const SizedBox(height: 8),
            const Text(
              "Fill out the comprehensive employee profile and enroll their face.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  _buildTextField(_empIdController, "Employee ID (Required)", Icons.badge),
                  _buildTextField(_nameController, "Full Name (Required)", Icons.person),
                  _buildTextField(_designationController, "Designation", Icons.work),
                  _buildTextField(_phoneController, "Phone Number", Icons.phone),
                  _buildTextField(_emailController, "Email Address", Icons.email),
                  _buildTextField(_dobController, "Date of Birth (DD/MM/YYYY)", Icons.cake),
                  _buildTextField(_joiningDateController, "Joining Date", Icons.date_range),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_dutyTimeController, "Duty Start", Icons.access_time)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField(_dutyEndTimeController, "Duty End", Icons.access_time)),
                    ],
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: DropdownButtonFormField<String>(
                      value: _selectedDept,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        labelText: "Department",
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.business, color: Color(0xFF00BFFF)),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Engineering', child: Text("Engineering")),
                        DropdownMenuItem(value: 'Human Resources', child: Text("Human Resources")),
                        DropdownMenuItem(value: 'Operations', child: Text("Operations")),
                        DropdownMenuItem(value: 'Finance', child: Text("Finance")),
                        DropdownMenuItem(value: 'Sales & Marketing', child: Text("Sales & Marketing")),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedDept = val);
                      },
                    ),
                  ),
                  
                  // Image Capture Area
                  InkWell(
                    onTap: _capturePhoto,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      height: 180,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _capturedImage == null ? const Color(0xFF00BFFF).withValues(alpha: 0.5) : Colors.green,
                          width: 2,
                        ),
                      ),
                      child: _capturedImage == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, size: 48, color: Color(0xFF00BFFF)),
                                SizedBox(height: 12),
                                Text("Tap to Capture Face Photo", style: TextStyle(color: Color(0xFF00BFFF), fontWeight: FontWeight.bold)),
                              ],
                            )
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(_capturedImage!, fit: BoxFit.cover),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.black.withValues(alpha: 0.4),
                                  ),
                                ),
                                const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle, size: 48, color: Colors.greenAccent),
                                      SizedBox(height: 8),
                                      Text("Face Captured! Tap to retake", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isRegistering ? null : _registerFaceData,
                      icon: _isRegistering 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: Text(
                        _isRegistering ? "Saving Profile..." : "Save Profile & Register Face",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BFFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

