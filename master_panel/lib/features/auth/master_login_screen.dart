import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../dashboard/master_control_panel_screen.dart';

class MasterLoginScreen extends StatefulWidget {
  const MasterLoginScreen({super.key});

  @override
  State<MasterLoginScreen> createState() => _MasterLoginScreenState();
}

class _MasterLoginScreenState extends State<MasterLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'master@admin.com');
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  void _handleMasterLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final inputEmail = _emailController.text.trim().toLowerCase();

    // Strict Enforcement: Only master@admin.com can access Master Control Panel
    if (inputEmail != 'master@admin.com') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Denied: Only master@admin.com is authorized to access Master Control Panel.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: inputEmail,
        password: _passwordController.text,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MasterControlPanelScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Master Authentication Failed: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19), // Ultra Dark Indigo / Navy
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            padding: const EdgeInsets.all(36.0),
            decoration: BoxDecoration(
              color: const Color(0xFF151D2A),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Master Shield Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF312E81)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'MASTER CONTROL PANEL',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SaaS Authoritative Control & Shop Provisioning Plane',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF94A3B8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),

                  // Email Input
                  TextFormField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Master Super Admin Email',
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.shield_outlined, color: Color(0xFF818CF8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter master email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Password Input
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Master Security Password',
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF818CF8)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: const Color(0xFF94A3B8),
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleMasterLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 6,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'AUTHENTICATE & ACCESS PANEL',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
