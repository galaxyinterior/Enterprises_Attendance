import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/email_notification_service.dart';
import '../../models/registration_request_model.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ownerNameController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _businessTypeController = TextEditingController(text: 'Retail Shop');
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController(text: 'Jharkhand');
  final _pincodeController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSubmitting = false;

  void _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final String appId = 'APP-${const Uuid().v4().substring(0, 8).toUpperCase()}';

      final request = RegistrationRequestModel(
        applicationId: appId,
        ownerName: _ownerNameController.text.trim(),
        shopName: _shopNameController.text.trim(),
        businessType: _businessTypeController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        employeeCount: 0,
        kioskCount: 1,
        notes: _notesController.text.trim(),
        status: AppConstants.statusPending,
        submittedAt: DateTime.now(),
      );

      // Save application to Firestore registrationRequests collection
      await FirebaseFirestore.instance
          .collection(AppConstants.colRegistrationRequests)
          .doc(appId)
          .set(request.toMap());

      // Send automated Gmail alert to Master Super Admin
      EmailNotificationService().sendNewRegistrationAlert(request);

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.cardBorderDark),
          ),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.pannaEmerald, size: 28),
              const SizedBox(width: 10),
              Text('Submitted Successfully', style: GoogleFonts.outfit(color: AppColors.textPrimary)),
            ],
          ),
          content: Text(
            'Your application ID is $appId.\n\nThe Master Administrator will review your registration and send your Shop ID & Login Credentials shortly.',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.kesariSaffron),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Back to Login
              },
              child: const Text('Back to Login', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting request: $e'),
          backgroundColor: AppColors.sindoorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.cardDark,
        title: Text('Register New Business / Shop', style: GoogleFonts.outfit(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorderDark),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shop Onboarding Form',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Fill out your business details to request access to the Smart Attendance Ecosystem.',
                    style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 24),

                  _buildTextField(_shopNameController, 'Shop / Business Name', Icons.store_rounded),
                  _buildTextField(_ownerNameController, 'Business Owner Name', Icons.person_outline),
                  _buildTextField(_phoneController, 'Phone Number (+91)', Icons.phone_outlined, keyboardType: TextInputType.phone),
                  _buildTextField(_emailController, 'Email Address', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                  _buildTextField(_businessTypeController, 'Business Type (Shop, Warehouse, Restaurant, Office)', Icons.business_outlined),
                  
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_cityController, 'City', Icons.location_city_outlined)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTextField(_stateController, 'State', Icons.map_outlined)),
                    ],
                  ),

                  _buildTextField(_addressController, 'Address', Icons.home_outlined),

                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: AppColors.saffronGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.kesariSaffron.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'SUBMIT APPLICATION',
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
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

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textMuted),
          prefixIcon: Icon(icon, color: AppColors.haldiGold),
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
        validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
      ),
    );
  }
}

