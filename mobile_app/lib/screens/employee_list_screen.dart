import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../models/employee.dart';
import '../repositories/employee_repository.dart';
import 'face_data_screen.dart';

class EmployeeListScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String storeId;
  const EmployeeListScreen({super.key, required this.cameras, required this.storeId});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final EmployeeRepository _employeeRepo = EmployeeRepository();
  List<Employee> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    final data = await _employeeRepo.getAllEmployees();
    setState(() {
      _employees = data;
      _isLoading = false;
    });
  }

  void _openRegisterDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceDataScreen(cameras: widget.cameras, storeId: widget.storeId),
      ),
    ).then((_) {
      setState(() {});
    });
  }

  Future<void> _deleteEmployee(Employee emp) async {
    // First Confirmation
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Employee?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to delete ${emp.name}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Yes, Delete"),
          ),
        ],
      ),
    );

    if (confirm1 != true) return;

    // Second Strict Confirmation ("ha mai delete karna chahata hu")
    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Final Warning", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text("This action cannot be undone. All face data and history will be lost. Do you still want to proceed?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("ha mai delete karna chahata hu"),
          ),
        ],
      ),
    );

    if (confirm2 != true) return;

    // Delete locally and from Firestore
    try {
      await _employeeRepo.deleteEmployee(emp.empId, widget.storeId);
    } catch (e) {
      debugPrint("Could not delete employee: $e");
    }

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Employee permanently deleted.")));
    }
  }

  void _showEmployeeProfile(Employee emp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Employee ID Card", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00BFFF))),
              const SizedBox(height: 24),
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFF00BFFF).withValues(alpha: 0.2),
                child: Text(emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 32, color: Color(0xFF00BFFF), fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              Text(emp.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text(emp.designation, style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const Divider(height: 32),
              _buildProfileRow(Icons.badge, "Emp ID", emp.empId),
              _buildProfileRow(Icons.business, "Department", emp.department),
              _buildProfileRow(Icons.phone, "Phone", emp.phone),
              _buildProfileRow(Icons.email, "Email", emp.email),
              _buildProfileRow(Icons.cake, "DOB", emp.dob),
              _buildProfileRow(Icons.date_range, "Joined", emp.joiningDate),
              _buildProfileRow(Icons.access_time, "Duty Time", "${emp.dutyTime} - ${emp.dutyEndTime}"),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.delete),
                  label: const Text("Remove Employee"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                    foregroundColor: Colors.redAccent,
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteEmployee(emp);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00BFFF), size: 20),
          const SizedBox(width: 12),
          Text("$label:", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.black54))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Employee Directory", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF00BFFF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text("Add Employee", style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _openRegisterDialog,
      ),
      body: FutureBuilder<List<Employee>>(
        future: _employeeRepo.getAllEmployees(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00BFFF)));
          }
          
          final employees = snapshot.data ?? [];
          if (employees.isEmpty) {
            return const Center(
              child: Text("No employees registered yet.", style: TextStyle(fontSize: 16, color: Colors.grey)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: employees.length,
            itemBuilder: (context, index) {
              final emp = employees[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF00BFFF).withValues(alpha: 0.2),
                    child: Text(emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?', style: const TextStyle(color: Color(0xFF00BFFF), fontWeight: FontWeight.bold)),
                  ),
                  title: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text("${emp.designation} • ${emp.department}", style: const TextStyle(color: Colors.grey)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () => _showEmployeeProfile(emp),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CameraCaptureScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraCaptureScreen({super.key, required this.cameras});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _controller;
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.cameras.isNotEmpty) {
      // Prioritize front camera for face capture by default
      _selectedCameraIndex = widget.cameras.indexWhere((cam) => cam.lensDirection == CameraLensDirection.front);
      if (_selectedCameraIndex == -1) _selectedCameraIndex = 0;
      _initCamera(_selectedCameraIndex);
    }
  }

  Future<void> _initCamera(int index) async {
    _controller = CameraController(widget.cameras[index], ResolutionPreset.medium);
    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});
  }

  void _switchCamera() async {
    if (widget.cameras.length < 2) return;
    
    _selectedCameraIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
    
    await _controller?.dispose();
    setState(() {
      _controller = null; // Show loading while initializing new camera
    });
    
    await _initCamera(_selectedCameraIndex);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("Take Face Snapshot"),
        actions: [
          if (widget.cameras.length > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios),
              onPressed: _switchCamera,
              tooltip: 'Switch Camera',
            ),
        ],
      ),
      body: Stack(
        children: [
          CameraPreview(_controller!),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.cameras.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 20.0),
                    child: FloatingActionButton(
                      heroTag: 'switch_btn',
                      backgroundColor: Colors.grey[800],
                      onPressed: _switchCamera,
                      child: const Icon(Icons.cameraswitch, color: Colors.white),
                    ),
                  ),
                FloatingActionButton(
                  heroTag: 'capture_btn',
                  child: const Icon(Icons.camera),
                  onPressed: () async {
                    final xfile = await _controller!.takePicture();
                    if (!context.mounted) return;
                    Navigator.pop(context, File(xfile.path));
                  },
                ),
                if (widget.cameras.length > 1)
                  const SizedBox(width: 76), // To balance the layout visually
              ],
            ),
          ),
        ],
      ),
    );
  }
}
