import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart'; // To access adminSupabase
import 'login_screen.dart';
import 'store_details_screen.dart';
import 'applications_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _stores = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchStores();
  }

  Future<void> _fetchStores() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final response = await adminSupabase.from('stores').select().order('created_at', ascending: false);
      setState(() {
        _stores = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      setState(() {
        _error = "Error fetching stores: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  Future<void> _toggleStoreStatus(String storeId, String currentStatus) async {
    final newStatus = currentStatus == 'active' ? 'locked' : 'active';
    try {
      await adminSupabase.from('stores').update({'status': newStatus}).eq('id', storeId);
      _fetchStores();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
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
      try {
        await adminSupabase.from('stores').delete().eq('id', storeId);
        _fetchStores();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting store: $e')));
        }
      }
    }
  }

  void _showAddStoreDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AddStoreDialog(onStoreAdded: _fetchStores),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text("Master Admin Dashboard", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            labelColor: Colors.cyanAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.cyanAccent,
            tabs: [
              Tab(icon: Icon(Icons.store), text: "Active Stores"),
              Tab(icon: Icon(Icons.pending_actions), text: "Pending Applications"),
            ],
          ),
          actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
            onPressed: _fetchStores,
            tooltip: "Refresh",
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.cyanAccent),
            onPressed: _logout,
            tooltip: "Logout",
          ),
        ],
      ),
        body: TabBarView(
          children: [
            // TAB 1: STORES
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                : _error.isNotEmpty
                    ? Center(child: Text(_error, style: const TextStyle(color: Colors.redAccent)))
                    : _stores.isEmpty
                        ? const Center(
                            child: Text("No stores found. Click + to add a store.", style: TextStyle(color: Colors.grey, fontSize: 18)),
                          )
                        : Padding(
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
                            itemCount: _stores.length,
                            itemBuilder: (context, index) {
                              final store = _stores[index];
                              final storeId = store['id'];
                              final name = store['store_name'] ?? 'Unknown Store';
                              final status = store['status'] ?? 'active';

                              return InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => StoreDetailsScreen(store: store),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Card(
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
                                                color: status == 'active' ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                status.toUpperCase(),
                                                style: TextStyle(
                                                  color: status == 'active' ? Colors.greenAccent : Colors.redAccent,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Divider(color: Colors.white24, height: 24),
                                        const Text("Manage this store via the options below.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                        const Spacer(),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton.icon(
                                              icon: Icon(status == 'active' ? Icons.lock : Icons.lock_open, color: status == 'active' ? Colors.redAccent : Colors.greenAccent),
                                              label: Text(status == 'active' ? "Lock" : "Enable", style: TextStyle(color: status == 'active' ? Colors.redAccent : Colors.greenAccent)),
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
                                ),
                              );
                            },
                          );
                        }
                      ),
                    ),
            // TAB 2: APPLICATIONS
            ApplicationsTab(onApplicationApproved: _fetchStores),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddStoreDialog,
          backgroundColor: Colors.cyanAccent,
          icon: const Icon(Icons.add, color: Colors.black),
          label: const Text("Add Store", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// ADD STORE DIALOG (Handles Supabase Admin API for Auth creation)
// ----------------------------------------------------------------------
class AddStoreDialog extends StatefulWidget {
  final VoidCallback onStoreAdded;
  const AddStoreDialog({super.key, required this.onStoreAdded});

  @override
  State<AddStoreDialog> createState() => _AddStoreDialogState();
}

class _AddStoreDialogState extends State<AddStoreDialog> {
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController(text: "password123");
  bool _isLoading = false;
  String _error = '';

  Future<void> _createStore() async {
    final storeNameStr = _nameController.text.trim();
    final storeIdStr = _idController.text.trim();
    final sanitizedStoreId = storeIdStr.replaceAll(' ', '').toLowerCase();
    final password = _passwordController.text.trim();

    if (storeNameStr.isEmpty || sanitizedStoreId.isEmpty || password.length < 6) {
      setState(() => _error = "Valid Store Name, Store ID, and Password (6+ chars) required.");
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final adminEmail = "admin@$sanitizedStoreId.in";
      final kioskEmail = "kiosk@$sanitizedStoreId.in";

      // 1. Insert store into 'stores' table using standard client
      final storeResponse = await adminSupabase.from('stores').insert({
        'store_name': storeNameStr,
        'store_code': sanitizedStoreId,
        'status': 'active',
      }).select().single();
      
      final String storeId = storeResponse['id'];

      // 2. Create Admin Account via Admin API (bypasses email confirmation)
      final adminUserResponse = await adminSupabase.auth.admin.createUser(
        AdminUserAttributes(
          email: adminEmail,
          password: password,
          emailConfirm: true,
        )
      );

      // 3. Create Kiosk Account via Admin API
      final kioskUserResponse = await adminSupabase.auth.admin.createUser(
        AdminUserAttributes(
          email: kioskEmail,
          password: password,
          emailConfirm: true,
        )
      );
      
      // 4. Update profiles to set roles and store_id
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

      if (mounted) {
        widget.onStoreAdded();
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
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
                labelText: "Store Name (e.g. Akm tech Multidivision)",
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _idController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Store ID/Code (e.g. akm)",
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
