import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart'; // To access adminSupabase

class StoreDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> store;

  const StoreDetailsScreen({super.key, required this.store});

  @override
  State<StoreDetailsScreen> createState() => _StoreDetailsScreenState();
}

class _StoreDetailsScreenState extends State<StoreDetailsScreen> {
  late String storeName;
  late String sanitizedStoreId;
  late String adminEmail;
  late String kioskEmail;
  bool _isResetting = false;

  @override
  void initState() {
    super.initState();
    storeName = widget.store['store_name'] ?? 'Unknown Store';
    sanitizedStoreId = widget.store['store_code'] ?? storeName.replaceAll(' ', '').toLowerCase();
    adminEmail = "admin@$sanitizedStoreId.in";
    kioskEmail = "kiosk@$sanitizedStoreId.in";
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$label copied to clipboard!")),
    );
  }

  Future<void> _resetPasswords() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Reset Passwords?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "This will reset the password for BOTH the Admin and Kiosk accounts to 'password123'. Are you sure?",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Reset", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isResetting = true);
    try {
      // Find admin user by email
      final adminUsers = await adminSupabase.auth.admin.listUsers();
      final adminUser = adminUsers.firstWhere((u) => u.email == adminEmail);
      await adminSupabase.auth.admin.updateUserById(
        adminUser.id,
        attributes: AdminUserAttributes(password: "password123"),
      );

      // Find kiosk user by email
      final kioskUser = adminUsers.firstWhere((u) => u.email == kioskEmail);
      await adminSupabase.auth.admin.updateUserById(
        kioskUser.id,
        attributes: AdminUserAttributes(password: "password123"),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Passwords reset to 'password123' successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error resetting passwords: \$e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  Widget _buildCredentialCard(String title, String email, IconData icon) {
    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.cyanAccent, size: 28),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildInfoRow("Login ID (Email)", email),
            const SizedBox(height: 16),
            _buildInfoRow("Default Password", "password123"),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.cyanAccent, size: 20),
                onPressed: () => _copyToClipboard(value, label),
                tooltip: "Copy $label",
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text("$storeName - Details", style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Onboarding Details",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                "Share these credentials with the store owner so they can log into the Mobile App.",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(child: _buildCredentialCard("Store Admin Account", adminEmail, Icons.admin_panel_settings)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildCredentialCard("Kiosk Account", kioskEmail, Icons.camera_front)),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: SizedBox(
                  height: 50,
                  width: 300,
                  child: ElevatedButton.icon(
                    onPressed: _isResetting ? null : _resetPasswords,
                    icon: _isResetting 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.lock_reset, color: Colors.white),
                    label: const Text("Reset Passwords to Default", style: TextStyle(color: Colors.white, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
