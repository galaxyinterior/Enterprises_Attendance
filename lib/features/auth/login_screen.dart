import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_routing_service.dart';
import '../master/master_dashboard_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../kiosk/kiosk_attendance_screen.dart';
import 'registration_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthRoutingService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _authService.loginUser(
        email: _emailController.text,
        password: _passwordController.text,
      );

      final role = result['role'] ?? AppConstants.roleShopAdmin;

      if (!mounted) return;

      if (role == AppConstants.roleMaster) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MasterDashboardScreen()),
        );
      } else if (role == AppConstants.roleKiosk) {
        final shopId = result['shopId'] ?? 'SHOP001';
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => KioskAttendanceScreen(
              shopId: shopId,
              businessId: result['businessId'] ?? shopId,
            ),
          ),
        );
      } else {
        final shopId = result['shopId'] ?? 'SHOP001';
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AdminDashboardScreen(
              shopId: shopId,
              businessId: result['businessId'] ?? shopId,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Authentication Failed: ${e.toString()}'),
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
      backgroundColor: const Color(0xFF0F172A), // Dark Slate
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.9), // Glassmorphism container
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App Branding Logo Icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.fingerprint_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Smart Attendance Ecosystem',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Login as Master, Shop Admin, or Kiosk',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF94A3B8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Email / Login ID Field
                  TextFormField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email / Login ID (e.g. ABC001@admin.in)',
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF818CF8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter your login ID';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password',
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
                  const SizedBox(height: 28),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'LOGIN TO SYSTEM',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // New Shop Registration Link
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegistrationScreen()),
                      );
                    },
                    child: Text(
                      'New Business? Register Your Shop Here →',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF818CF8),
                        fontWeight: FontWeight.w600,
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
