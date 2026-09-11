import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

class ApplyForStoreScreen extends StatefulWidget {
  const ApplyForStoreScreen({super.key});

  @override
  State<ApplyForStoreScreen> createState() => _ApplyForStoreScreenState();
}

class _ApplyForStoreScreenState extends State<ApplyForStoreScreen> {
  final _ownerNameController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _staffController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = false;
  bool _isLocating = false;
  String _error = '';

  @override
  void dispose() {
    _ownerNameController.dispose();
    _storeNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _staffController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _error = '';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _addressController.text = "Lat: ${position.latitude}, Lng: ${position.longitude}";
      });
    } catch (e) {
      setState(() => _error = "Location Error: $e");
    } finally {
      setState(() => _isLocating = false);
    }
  }

  Future<void> _submitApplication() async {
    final ownerName = _ownerNameController.text.trim();
    final storeName = _storeNameController.text.trim();
    final mobile = _mobileController.text.trim();
    final email = _emailController.text.trim();
    final staffStr = _staffController.text.trim();
    final address = _addressController.text.trim();

    if (ownerName.isEmpty || storeName.isEmpty || mobile.isEmpty || email.isEmpty || staffStr.isEmpty || address.isEmpty) {
      setState(() => _error = "Please fill out all fields.");
      return;
    }

    final staff = int.tryParse(staffStr);
    if (staff == null) {
      setState(() => _error = "Estimated staff must be a number.");
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      await Supabase.instance.client.from('store_applications').insert({
        'owner_name': ownerName,
        'store_name': storeName,
        'mobile_no': mobile,
        'email': email,
        'address': address,
        'estimated_staff': staff,
        'status': 'pending',
      });

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ThankYouScreen()),
        );
      }
    } catch (e) {
      setState(() => _error = "Error submitting application: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Apply for a Store", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.store_mall_directory, size: 64, color: Colors.blueAccent),
                const SizedBox(height: 16),
                const Text(
                  "Store Application",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Fill out this form to request a store setup. You will receive an email once approved.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 24),

                if (_error.isNotEmpty) ...[
                  Text(_error, style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                ],

                _buildTextField(_ownerNameController, "Owner Name", Icons.person),
                const SizedBox(height: 16),
                _buildTextField(_storeNameController, "Store Name", Icons.store),
                const SizedBox(height: 16),
                _buildTextField(_mobileController, "Mobile No.", Icons.phone, keyboardType: TextInputType.phone),
                const SizedBox(height: 16),
                _buildTextField(_emailController, "Email Address", Icons.email, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),
                _buildTextField(_staffController, "Estimated Staff", Icons.people, keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                
                // Address Field with GPS button
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(_addressController, "Store Address", Icons.location_on),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: _isLocating 
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.my_location, color: Colors.blueAccent),
                        onPressed: _isLocating ? null : _getCurrentLocation,
                        tooltip: "Use Current Location",
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitApplication,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Submit Application", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}

class ThankYouScreen extends StatelessWidget {
  const ThankYouScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 100),
              const SizedBox(height: 24),
              const Text(
                "Thank You!",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                "Your store application has been successfully submitted.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                "We will review your details and send the Admin ID and Password to your email shortly.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 200,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Back to Login", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
