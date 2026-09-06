import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart'; // To get globalCameras and AuthenticatedApp
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final User user;
  const OnboardingScreen({super.key, required this.user});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isLoading = false;
  String _storeCode = '';
  String _role = '';

  final _storeNameController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _locationController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _extractInfo();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _adminNameController.dispose();
    _mobileController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _extractInfo() {
    final email = widget.user.email ?? '';
    if (email.contains('@')) {
      final parts = email.split('@');
      _role = parts[0]; 
      if (parts[1].contains('.')) {
        _storeCode = parts[1].split('.')[0]; 
      }
    }
  }

  Future<void> _linkProfile() async {
    if (_storeNameController.text.isEmpty || _adminNameController.text.isEmpty || _mobileController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all required fields."), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() { _isLoading = true; });
    try {
      if (_storeCode.isEmpty) {
        throw Exception("Could not determine Store Code from your email.");
      }
      
      await Supabase.instance.client.rpc('setup_new_store_profile', params: {
        'p_store_code': _storeCode,
        'p_role': _role,
        'p_store_name': _storeNameController.text.trim(),
        'p_admin_name': _adminNameController.text.trim(),
        'p_mobile_no': _mobileController.text.trim(),
        'p_location': _locationController.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account setup complete!"), backgroundColor: Colors.green),
      );
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => AuthenticatedApp(user: widget.user, cameras: globalCameras)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        title: const Text("Account Setup", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Complete Your Store Profile",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                "Store Code: ${_storeCode.toUpperCase()} | Role: ${_role.toUpperCase()}",
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              
              _buildTextField("Admin Name *", _adminNameController),
              _buildTextField("Store Name *", _storeNameController),
              _buildTextField("Mobile Number *", _mobileController, type: TextInputType.phone),
              _buildTextField("Location (Optional)", _locationController),
              
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _linkProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text("Complete Setup", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                child: const Text("Cancel & Sign Out", style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
