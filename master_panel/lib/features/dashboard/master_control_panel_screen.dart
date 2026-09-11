import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/shop_provisioning_service.dart';
import '../../models/registration_request_model.dart';
import '../../models/business_model.dart';
import '../auth/master_login_screen.dart';

class MasterControlPanelScreen extends StatefulWidget {
  const MasterControlPanelScreen({super.key});

  @override
  State<MasterControlPanelScreen> createState() => _MasterControlPanelScreenState();
}

class _MasterControlPanelScreenState extends State<MasterControlPanelScreen> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.cardDark,
        elevation: 4,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  gradient: AppColors.saffronGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'MASTER CONTROL PANEL',
                style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: isMobile ? 15 : 18),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.pannaEmerald.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.pannaEmerald.withValues(alpha: 0.4)),
                  ),
                  child: const Text('SUPER ADMIN', style: TextStyle(color: AppColors.pannaEmerald, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.sindoorRed),
            tooltip: 'Sign Out Master Panel',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const MasterLoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Metrics Bar (Horizontally Scrollable for Mobile)
          _buildMetricsBar(isMobile),

          // Navigation Tabs (Horizontally Scrollable for Mobile)
          Container(
            width: double.infinity,
            color: AppColors.cardDark,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTabButton('Pending Registrations', 0, Icons.assignment_turned_in_outlined),
                  _buildTabButton('Registered Shops Directory', 1, Icons.storefront_rounded),
                  _buildTabButton('Audit Logs & Health', 2, Icons.shield_outlined),
                ],
              ),
            ),
          ),

          // Main View Content
          Expanded(
            child: IndexedStack(
              index: _selectedTabIndex,
              children: [
                _buildPendingRequestsTab(isMobile),
                _buildShopsDirectoryTab(isMobile),
                _buildAuditLogsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsBar(bool isMobile) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(AppConstants.colBusinesses).snapshots(),
      builder: (context, snapshot) {
        int totalShops = 0;
        int activeShops = 0;
        int pausedShops = 0;

        if (snapshot.hasData) {
          totalShops = snapshot.data!.docs.length;
          for (var doc in snapshot.data!.docs) {
            final status = doc.get('status') ?? '';
            if (status == AppConstants.statusActive) activeShops++;
            if (status == AppConstants.statusPaused) pausedShops++;
          }
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.bgDark,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMetricCard('Total Shops', '$totalShops', AppColors.kesariSaffron, Icons.store_rounded, isMobile),
                const SizedBox(width: 12),
                _buildMetricCard('Active Shops', '$activeShops', AppColors.pannaEmerald, Icons.check_circle_rounded, isMobile),
                const SizedBox(width: 12),
                _buildMetricCard('Paused Shops', '$pausedShops', AppColors.haldiGold, Icons.pause_circle_rounded, isMobile),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String count, Color color, IconData icon, bool isMobile) {
    return Container(
      constraints: BoxConstraints(minWidth: isMobile ? 140 : 180),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: isMobile ? 26 : 32),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(count, style: GoogleFonts.outfit(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Text(title, style: GoogleFonts.inter(fontSize: isMobile ? 11 : 12, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index, IconData icon) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.kesariSaffron : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? AppColors.kesariSaffron : AppColors.textMuted, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingRequestsTab(bool isMobile) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.colRegistrationRequests)
          .where('status', isEqualTo: AppConstants.statusPending)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.kesariSaffron));

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.task_alt_rounded, size: 56, color: AppColors.pannaEmerald),
                const SizedBox(height: 14),
                Text('No Pending Applications', style: GoogleFonts.outfit(fontSize: 18, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  'All new shop registrations have been reviewed and provisioned.',
                  style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(isMobile ? 12 : 20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final request = RegistrationRequestModel.fromMap(data);

            return Card(
              color: AppColors.cardDark,
              margin: const EdgeInsets.only(bottom: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.cardBorderDark),
              ),
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 14 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            request.shopName,
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Chip(
                          label: Text(request.applicationId, style: const TextStyle(color: Colors.white, fontSize: 11)),
                          backgroundColor: AppColors.kesariSaffron,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Owner: ${request.ownerName} | Phone: ${request.phone}', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
                    Text('Email: ${request.email}', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
                    Text('Location: ${request.city}, ${request.state} | Type: ${request.businessType} | Staff: ${request.employeeCount}', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.saffronGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            icon: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                            label: const Text('APPROVE & PROVISION SHOP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () => _approveRequest(request),
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.sindoorRed,
                            side: const BorderSide(color: AppColors.sindoorRed),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('REJECT', style: TextStyle(fontSize: 12)),
                          onPressed: () => _rejectRequest(request),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _generateAutoPassword(String rolePrefix) {
    final randomNum = 1000 + Random().nextInt(9000);
    return '$rolePrefix@$randomNum';
  }

  void _approveRequest(RegistrationRequestModel request) async {
    final defaultShopId = 'SHOP${const Uuid().v4().substring(0, 4).toUpperCase()}';
    final shopIdController = TextEditingController(text: defaultShopId);
    final adminPasswordController = TextEditingController(text: _generateAutoPassword('Admin'));
    final kioskPasswordController = TextEditingController(text: _generateAutoPassword('Kiosk'));
    final emailController = TextEditingController(text: request.email);

    final formKey = GlobalKey<FormState>();
    bool isProcessing = false;
    bool obscureAdminPass = true;
    bool obscureKioskPass = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentShopId = shopIdController.text.trim().toUpperCase();
            final adminEmailPreview = currentShopId.isNotEmpty ? '$currentShopId@admin.in' : '-';
            final kioskEmailPreview = currentShopId.isNotEmpty ? '$currentShopId@kiosk.in' : '-';

            return AlertDialog(
              backgroundColor: AppColors.cardDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.cardBorderDark),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.pannaEmerald.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.storefront_rounded, color: AppColors.pannaEmerald, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Approve & Provision Shop', style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(request.shopName, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 480,
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Shop ID & Passwords are auto-generated. You can customize them or click 🔄 to re-generate.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 16),

                        // Manual Shop ID Field
                        TextFormField(
                          controller: shopIdController,
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, letterSpacing: 1),
                          decoration: InputDecoration(
                            labelText: 'Shop ID (Editable)',
                            labelStyle: const TextStyle(color: AppColors.haldiGold),
                            hintText: 'e.g. SHOP001',
                            prefixIcon: const Icon(Icons.fingerprint, color: AppColors.haldiGold),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.refresh, color: AppColors.textMuted),
                              tooltip: 'Auto-generate new Shop ID',
                              onPressed: () {
                                setDialogState(() {
                                  shopIdController.text = 'SHOP${const Uuid().v4().substring(0, 4).toUpperCase()}';
                                });
                              },
                            ),
                            filled: true,
                            fillColor: AppColors.inputBgDark,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.cardBorderDark),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.cardBorderDark),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.kesariSaffron),
                            ),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Shop ID cannot be empty';
                            if (val.trim().length < 3) return 'Shop ID must be at least 3 chars';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // User Email Address Field
                        TextFormField(
                          controller: emailController,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Recipient Email Address',
                            labelStyle: const TextStyle(color: AppColors.textMuted),
                            prefixIcon: const Icon(Icons.email_outlined, color: AppColors.haldiGold),
                            filled: true,
                            fillColor: AppColors.inputBgDark,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.cardBorderDark),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.cardBorderDark),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.kesariSaffron),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty || !val.contains('@')) return 'Enter a valid email address';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Admin Password Field
                        TextFormField(
                          controller: adminPasswordController,
                          obscureText: obscureAdminPass,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Shop Admin Password (Auto-generated)',
                            labelStyle: const TextStyle(color: AppColors.textMuted),
                            prefixIcon: const Icon(Icons.admin_panel_settings_outlined, color: AppColors.haldiGold),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.refresh_rounded, color: AppColors.haldiGold),
                                  tooltip: 'Re-generate Auto Password',
                                  onPressed: () {
                                    setDialogState(() {
                                      adminPasswordController.text = _generateAutoPassword('Admin');
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: Icon(obscureAdminPass ? Icons.visibility_off : Icons.visibility, color: AppColors.textMuted),
                                  onPressed: () => setDialogState(() => obscureAdminPass = !obscureAdminPass),
                                ),
                              ],
                            ),
                            filled: true,
                            fillColor: AppColors.inputBgDark,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.cardBorderDark),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.cardBorderDark),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.kesariSaffron),
                            ),
                          ),
                          validator: (val) => (val == null || val.trim().length < 6) ? 'Password must be at least 6 characters' : null,
                        ),
                        const SizedBox(height: 14),

                        // Kiosk Password Field
                        TextFormField(
                          controller: kioskPasswordController,
                          obscureText: obscureKioskPass,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Kiosk App Password (Auto-generated)',
                            labelStyle: const TextStyle(color: AppColors.textMuted),
                            prefixIcon: const Icon(Icons.desktop_windows_outlined, color: AppColors.mayurBlue),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.refresh_rounded, color: AppColors.mayurBlue),
                                  tooltip: 'Re-generate Auto Password',
                                  onPressed: () {
                                    setDialogState(() {
                                      kioskPasswordController.text = _generateAutoPassword('Kiosk');
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: Icon(obscureKioskPass ? Icons.visibility_off : Icons.visibility, color: AppColors.textMuted),
                                  onPressed: () => setDialogState(() => obscureKioskPass = !obscureKioskPass),
                                ),
                              ],
                            ),
                            filled: true,
                            fillColor: AppColors.inputBgDark,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.cardBorderDark),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.cardBorderDark),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.kesariSaffron),
                            ),
                          ),
                          validator: (val) => (val == null || val.trim().length < 6) ? 'Password must be at least 6 characters' : null,
                        ),
                        const SizedBox(height: 16),

                        // Live Credentials Preview Card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.inputBgDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.cardBorderDark),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('GENERATED LOGIN CREDENTIALS:', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.admin_panel_settings, color: AppColors.haldiGold, size: 16),
                                  const SizedBox(width: 6),
                                  Text('Admin ID: ', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
                                  Text(adminEmailPreview, style: GoogleFonts.inter(color: AppColors.pannaEmerald, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.computer, color: AppColors.mayurBlue, size: 16),
                                  const SizedBox(width: 6),
                                  Text('Kiosk ID: ', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
                                  Text(kioskEmailPreview, style: GoogleFonts.inter(color: AppColors.mayurBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.saffronGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: isProcessing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    label: Text(
                      isProcessing ? 'PROVISIONING...' : 'PROVISION & SEND MAIL',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    onPressed: isProcessing
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setDialogState(() => isProcessing = true);

                            final result = await ShopProvisioningService().provisionShop(
                              request: request,
                              customShopId: shopIdController.text,
                              adminPassword: adminPasswordController.text,
                              kioskPassword: kioskPasswordController.text,
                              userEmail: emailController.text,
                            );

                            if (!dialogCtx.mounted) return;
                            Navigator.pop(dialogCtx);

                            if (!mounted) return;

                            if (result.success) {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: AppColors.cardDark,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: const BorderSide(color: AppColors.cardBorderDark),
                                  ),
                                  title: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: AppColors.pannaEmerald, size: 28),
                                      const SizedBox(width: 10),
                                      Text('Shop Provisioned!', style: GoogleFonts.outfit(color: AppColors.textPrimary)),
                                    ],
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Assigned Shop ID: ${result.shopId}', style: const TextStyle(color: AppColors.pannaEmerald, fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 12),
                                      Text('Firebase Auth Admin: ${result.adminEmail}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                                      Text('Firebase Auth Kiosk: ${result.kioskEmail}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: result.emailSent ? AppColors.pannaEmerald.withValues(alpha: 0.15) : AppColors.haldiGold.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: result.emailSent ? AppColors.pannaEmerald : AppColors.haldiGold),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(result.emailSent ? Icons.mark_email_read : Icons.warning_amber_rounded,
                                                color: result.emailSent ? AppColors.pannaEmerald : AppColors.haldiGold, size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                result.emailSent
                                                    ? 'Credentials Email successfully sent to ${emailController.text}!'
                                                    : 'Shop provisioned but credentials email could not be sent. Check SMTP credentials.',
                                                style: TextStyle(color: result.emailSent ? AppColors.pannaEmerald : AppColors.haldiGold, fontSize: 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.kesariSaffron),
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Provisioning Failed: ${result.errorMessage}'),
                                  backgroundColor: AppColors.sindoorRed,
                                ),
                              );
                            }
                          },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _rejectRequest(RegistrationRequestModel request) async {
    await FirebaseFirestore.instance
        .collection(AppConstants.colRegistrationRequests)
        .doc(request.applicationId)
        .update({'status': AppConstants.statusRejected});
  }

  Widget _buildShopsDirectoryTab(bool isMobile) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(AppConstants.colBusinesses).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.kesariSaffron));

        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: EdgeInsets.all(isMobile ? 12 : 20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final biz = BusinessModel.fromMap(data);
            final isPaused = biz.status == AppConstants.statusPaused;

            return Card(
              color: AppColors.cardDark,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.cardBorderDark),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(biz.shopName, style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                              Chip(
                                label: Text(biz.status, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                backgroundColor: isPaused ? AppColors.haldiGold : AppColors.pannaEmerald,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('ID: ${biz.shopId} | Owner: ${biz.ownerName}', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                          Text('City: ${biz.city} | Email: ${biz.email}', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isPaused ? AppColors.pannaEmerald : AppColors.haldiGold,
                              ),
                              icon: Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: Colors.white, size: 18),
                              label: Text(isPaused ? 'RESUME SHOP' : 'PAUSE SHOP', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              onPressed: () => _toggleShopStatus(biz),
                            ),
                          ),
                        ],
                      )
                    : ListTile(
                        title: Text(biz.shopName, style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Text('Shop ID: ${biz.shopId} | Owner: ${biz.ownerName} | City: ${biz.city} | Email: ${biz.email}', style: GoogleFonts.inter(color: AppColors.textMuted)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(
                              label: Text(biz.status, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              backgroundColor: isPaused ? AppColors.haldiGold : AppColors.pannaEmerald,
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isPaused ? AppColors.pannaEmerald : AppColors.haldiGold,
                              ),
                              icon: Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: Colors.white),
                              label: Text(isPaused ? 'RESUME SHOP' : 'PAUSE SHOP', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              onPressed: () => _toggleShopStatus(biz),
                            ),
                          ],
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }

  void _toggleShopStatus(BusinessModel biz) async {
    final newStatus = biz.status == AppConstants.statusActive
        ? AppConstants.statusPaused
        : AppConstants.statusActive;

    await FirebaseFirestore.instance
        .collection(AppConstants.colBusinesses)
        .doc(biz.businessId)
        .update({
      'status': newStatus,
      'pausedAt': newStatus == AppConstants.statusPaused ? DateTime.now().toIso8601String() : null,
      'pauseReason': newStatus == AppConstants.statusPaused ? 'Paused by Master Super Admin' : null,
    });
  }

  Widget _buildAuditLogsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.security_rounded, color: AppColors.haldiGold, size: 64),
          const SizedBox(height: 16),
          Text('Master Audit Trail & Security Logs', style: GoogleFonts.outfit(fontSize: 20, color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              'All shop provisions, pause/resume actions, and administrative operations are securely recorded.',
              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

