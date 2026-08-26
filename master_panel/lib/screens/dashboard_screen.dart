import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _firestore = FirebaseFirestore.instance;

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  Future<void> _toggleStoreStatus(String storeId, String currentStatus) async {
    final newStatus = currentStatus == 'active' ? 'paused' : 'active';
    await _firestore.collection('stores').doc(storeId).update({'status': newStatus});
  }

  Future<void> _deleteStore(String storeId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Delete Store?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Are you sure you want to permanently delete this store? This cannot be undone.",
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
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('stores').doc(storeId).delete();
    }
  }

  void _showAddStoreDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AddStoreDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Master Admin Dashboard", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.cyanAccent),
            onPressed: _logout,
            tooltip: "Logout",
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('stores').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.redAccent)));
          }

          final stores = snapshot.data?.docs ?? [];

          if (stores.isEmpty) {
            return const Center(
              child: Text("No stores found. Click + to add a store.", style: TextStyle(color: Colors.grey, fontSize: 18)),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 600 ? 2 : 1));
                
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: stores.length,
                  itemBuilder: (context, index) {
                    final store = stores[index].data() as Map<String, dynamic>;
                    final storeId = stores[index].id;
                    final name = store['name'] ?? 'Unknown Store';
                    final adminEmail = store['adminEmail'] ?? 'N/A';
                    final kioskEmail = store['kioskEmail'] ?? 'N/A';
                    final status = store['status'] ?? 'active';

                    return Card(
                      color: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: status == 'active' ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      color: status == 'active' ? Colors.greenAccent : Colors.orangeAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white24, height: 24),
                            Row(
                              children: [
                                const Icon(Icons.admin_panel_settings, color: Colors.grey, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(adminEmail, style: const TextStyle(color: Colors.grey, fontSize: 13), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.qr_code_scanner, color: Colors.grey, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(kioskEmail, style: const TextStyle(color: Colors.grey, fontSize: 13), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: Icon(status == 'active' ? Icons.pause : Icons.play_arrow, color: status == 'active' ? Colors.orangeAccent : Colors.greenAccent),
                                  label: Text(status == 'active' ? "Pause" : "Activate", style: TextStyle(color: status == 'active' ? Colors.orangeAccent : Colors.greenAccent)),
                                  onPressed: () => _toggleStoreStatus(storeId, status),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () => _deleteStore(storeId),
                                  tooltip: "Delete Store",
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
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStoreDialog,
        backgroundColor: Colors.cyanAccent,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text("Add Store", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// ADD STORE DIALOG (Handles Secondary Firebase App for Auth creation)
// ----------------------------------------------------------------------
class AddStoreDialog extends StatefulWidget {
  const AddStoreDialog({super.key});

  @override
  State<AddStoreDialog> createState() => _AddStoreDialogState();
}

class _AddStoreDialogState extends State<AddStoreDialog> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController(text: "password123");
  bool _isLoading = false;
  String _error = '';

  Future<void> _createStore() async {
    final storeName = _nameController.text.trim().replaceAll(' ', '').toLowerCase();
    final password = _passwordController.text.trim();

    if (storeName.isEmpty || password.length < 6) {
      setState(() => _error = "Valid Store ID (no spaces) and Password (6+ chars) required.");
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    FirebaseApp? secondaryApp;
    try {
      final adminEmail = "admin@$storeName.in";
      final kioskEmail = "kiosk@$storeName.in";

      // 1. Initialize Secondary Firebase App to create users without logging out Master Admin
      secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp_${DateTime.now().millisecondsSinceEpoch}',
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      // 2. Create Admin Account
      await secondaryAuth.createUserWithEmailAndPassword(email: adminEmail, password: password);
      
      // 3. Create Kiosk Account
      await secondaryAuth.createUserWithEmailAndPassword(email: kioskEmail, password: password);

      // 4. Save to Firestore (using primary app instance)
      await FirebaseFirestore.instance.collection('stores').doc(storeName).set({
        'name': _nameController.text.trim(),
        'storeId': storeName,
        'adminEmail': adminEmail,
        'kioskEmail': kioskEmail,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (secondaryApp != null) {
        await secondaryApp.delete();
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text("Register New Store", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "This will automatically generate the admin@ and kiosk@ email accounts for the store.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error, style: const TextStyle(color: Colors.redAccent)),
              ),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Store Name (e.g. My Shop)",
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Default Password",
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createStore,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
          child: _isLoading 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
            : const Text("Create Store", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
