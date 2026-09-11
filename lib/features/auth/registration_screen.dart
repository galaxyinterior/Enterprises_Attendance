import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
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
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 28),
              const SizedBox(width: 10),
              Text('Submitted Successfully', style: GoogleFonts.outfit(color: Colors.white)),
            ],
          ),
          content: Text(
            'Your application ID is $appId.\n\nThe Master Administrator will review your registration and send your Shop ID & Login Credentials shortly.',
            style: GoogleFonts.inter(color: const Color(0xFFCBD5E1)),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
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
        SnackBar(content: Text('Error submitting request: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Register New Business / Shop', style: GoogleFonts.outfit(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Fill out your business details to request access to the Smart Attendance Ecosystem.',
                    style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
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
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
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
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
          prefixIcon: Icon(icon, color: const Color(0xFF818CF8)),
          filled: true,
          fillColor: const Color(0xFF0F172A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
      ),
    );
  }
}
