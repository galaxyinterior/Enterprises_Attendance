import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart'; // adminSupabase
import '../utils/email_sender.dart';

class ApplicationsTab extends StatefulWidget {
  final VoidCallback onApplicationApproved;

  const ApplicationsTab({super.key, required this.onApplicationApproved});

  @override
  State<ApplicationsTab> createState() => _ApplicationsTabState();
}

class _ApplicationsTabState extends State<ApplicationsTab> {
  List<Map<String, dynamic>> _applications = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchApplications();
  }

  Future<void> _fetchApplications() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final response = await adminSupabase
          .from('store_applications')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      setState(() {
        _applications = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      setState(() => _error = "Error fetching applications: \$e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _approveApplication(Map<String, dynamic> app) async {
    final codeController = TextEditingController();
    
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text("Approve ${app['store_name']}", style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Please assign a unique Store ID/Code for this store.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Store ID (e.g. akm)",
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
            onPressed: () {
              if (codeController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Store ID is required')));
                return;
              }
              Navigator.of(ctx).pop(true);
            },
            child: const Text("Approve & Send Email", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final storeCode = codeController.text.trim().replaceAll(' ', '').toLowerCase();
    
    setState(() => _isLoading = true);

    try {
      final generatedPassword = EmailSender.generatePassword();
      final adminEmail = "admin@$storeCode.in";
      final kioskEmail = "kiosk@$storeCode.in";

      // 1. Create store
      final storeResponse = await adminSupabase.from('stores').insert({
        'store_name': app['store_name'],
        'store_code': storeCode,
        'status': 'active',
      }).select().single();

      final String storeId = storeResponse['id'];

      // 2. Create Auth users
      final adminUserResponse = await adminSupabase.auth.admin.createUser(
        AdminUserAttributes(
          email: adminEmail,
          password: generatedPassword,
          emailConfirm: true,
        )
      );

      final kioskUserResponse = await adminSupabase.auth.admin.createUser(
        AdminUserAttributes(
          email: kioskEmail,
          password: generatedPassword,
          emailConfirm: true,
        )
      );

      // 3. Update Profiles
      if (adminUserResponse.user != null) {
        await adminSupabase.from('profiles').insert({
          'id': adminUserResponse.user!.id,
          'role': 'admin',
          'store_id': storeId,
        });
      }
      
      if (kioskUserResponse.user != null) {
        await adminSupabase.from('profiles').insert({
          'id': kioskUserResponse.user!.id,
          'role': 'kiosk',
          'store_id': storeId,
        });
      }

      // 4. Send Email
      await EmailSender.sendApprovalEmail(
        recipientEmail: app['email'],
        ownerName: app['owner_name'],
        storeName: app['store_name'],
        storeCode: storeCode,
        adminPassword: generatedPassword,
        kioskPassword: generatedPassword,
      );

      // 5. Update application status
      await adminSupabase.from('store_applications').update({'status': 'approved'}).eq('id', app['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Store created and email sent successfully!"), backgroundColor: Colors.green));
        widget.onApplicationApproved();
        _fetchApplications();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectApplication(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Reject Application?", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to reject this application?", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Reject", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await adminSupabase.from('store_applications').update({'status': 'rejected'}).eq('id', id);
        _fetchApplications();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
    }
    
    if (_error.isNotEmpty) {
      return Center(child: Text(_error, style: const TextStyle(color: Colors.redAccent)));
    }
    
    if (_applications.isEmpty) {
      return const Center(
        child: Text("No pending applications.", style: TextStyle(color: Colors.grey, fontSize: 18)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _applications.length,
      itemBuilder: (context, index) {
        final app = _applications[index];
        return Card(
          color: const Color(0xFF1E293B),
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app['store_name'], style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Owner: ${app['owner_name']}", style: const TextStyle(color: Colors.grey)),
                Text("Mobile: ${app['mobile_no']}", style: const TextStyle(color: Colors.grey)),
                Text("Email: ${app['email']}", style: const TextStyle(color: Colors.grey)),
                Text("Address: ${app['address']}", style: const TextStyle(color: Colors.grey)),
                Text("Est. Staff: ${app['estimated_staff']}", style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _rejectApplication(app['id']),
                      child: const Text("Reject", style: TextStyle(color: Colors.redAccent)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                      onPressed: () => _approveApplication(app),
                      child: const Text("Approve", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
