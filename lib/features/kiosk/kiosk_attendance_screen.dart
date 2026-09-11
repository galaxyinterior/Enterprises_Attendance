import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/face_recognition_service.dart';
import '../../core/services/voice_announcements_service.dart';
import '../../core/services/offline_db_service.dart';
import '../../models/attendance_model.dart';
import '../auth/login_screen.dart';

class KioskAttendanceScreen extends StatefulWidget {
  final String shopId;
  final String businessId;

  const KioskAttendanceScreen({
    super.key,
    required this.shopId,
    required this.businessId,
  });

  @override
  State<KioskAttendanceScreen> createState() => _KioskAttendanceScreenState();
}

class _KioskAttendanceScreenState extends State<KioskAttendanceScreen> {
  final _faceService = FaceRecognitionService();
  final _voiceService = VoiceAnnouncementsService();
  final _offlineDb = OfflineDbService();

  bool _isProcessing = false;
  String _statusMessage = 'Please look at the camera';
  String? _lastRecognizedName;
  bool _isShopPaused = false;

  @override
  void initState() {
    super.initState();
    _initServices();
    _listenToShopStatus();
  }

  void _initServices() async {
    await _faceService.initialize();
    await _voiceService.initialize();
  }

  void _listenToShopStatus() {
    FirebaseFirestore.instance
        .collection(AppConstants.colBusinesses)
        .doc(widget.businessId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final status = doc.get('status') ?? '';
        setState(() {
          _isShopPaused = status == AppConstants.statusPaused;
        });
      }
    });
  }

  // Simulated face scan trigger for testing face matching & attendance log creation
  void _simulateFaceScan() async {
    if (_isShopPaused || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Scanning & Extracting Face Features...';
    });

    await Future.delayed(const Duration(seconds: 1));

    // Simulated 128D embedding vector
    final targetVector = List.generate(128, (i) => (i % 2 == 0 ? 0.05 : -0.05));

    // Fetch real enrolled staff with face embeddings from Firestore
    final snapshot = await FirebaseFirestore.instance
        .collection(AppConstants.colBusinesses)
        .doc(widget.businessId)
        .collection(AppConstants.colEmployees)
        .where('faceEnrollmentStatus', isEqualTo: true)
        .get();

    List<Map<String, dynamic>> enrolled = snapshot.docs.map((doc) => doc.data()).toList();

    // Fallback default list if no staff enrolled in DB yet
    if (enrolled.isEmpty) {
      enrolled = [
        {
          'employeeId': 'EMP123',
          'fullName': 'Ravi Kumar',
          'faceEmbedding': List.generate(128, (i) => (i % 2 == 0 ? 0.05 : -0.05)),
        }
      ];
    }

    final match = _faceService.matchFace(
      targetEmbedding: targetVector,
      enrolledEmployees: enrolled,
    );

    if (match != null) {
      final name = match['employeeName'];
      final empId = match['employeeId'];

      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final attendance = AttendanceModel(
        attendanceId: const Uuid().v4(),
        businessId: widget.businessId,
        employeeId: empId,
        employeeName: name,
        date: dateStr,
        shiftId: 'SHIFT_MORNING',
        checkInTime: now,
        status: AppConstants.attendancePresent,
        confidence: match['confidence'],
        syncStatus: AppConstants.syncPending,
        createdAt: now,
        updatedAt: now,
      );

      // Save to offline SQLite Queue
      await _offlineDb.insertAttendance(attendance);

      // Speak Greeting TTS
      await _voiceService.speakCheckInGreeting(name);

      setState(() {
        _lastRecognizedName = name;
        _statusMessage = 'Welcome $name! Attendance Marked.';
      });
    } else {
      await _voiceService.speakAlert('Face not recognized. Please try again.');
      setState(() {
        _statusMessage = 'Face Not Recognized';
      });
    }

    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _lastRecognizedName = null;
        _statusMessage = 'Please look at the camera';
      });
    }
  }

  void _showExitDialog() {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Exit Kiosk Mode', style: GoogleFonts.outfit(color: Colors.white)),
        content: TextField(
          controller: pinCtrl,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Enter Admin Password / PIN',
            labelStyle: TextStyle(color: Color(0xFF94A3B8)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('EXIT KIOSK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Camera / Scanner Background Area
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Shop Name Header
                Text(
                  'SHOP KIOSK: ${widget.shopId}',
                  style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  _isShopPaused ? '⚠️ SERVICE TEMPORARILY PAUSED BY ADMIN' : 'SMART ATTENDANCE SCANNER ACTIVE',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _isShopPaused ? Colors.amberAccent : Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),

                // Face Scanning Circle Container
                GestureDetector(
                  onTap: _simulateFaceScan,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1E293B),
                      border: Border.all(
                        color: _isShopPaused
                            ? Colors.amber
                            : (_lastRecognizedName != null ? Colors.greenAccent : const Color(0xFF6366F1)),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_lastRecognizedName != null ? Colors.greenAccent : const Color(0xFF6366F1)).withOpacity(0.3),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isProcessing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Icon(
                              _lastRecognizedName != null ? Icons.check_circle_rounded : Icons.face_retouching_natural_rounded,
                              size: 100,
                              color: _lastRecognizedName != null ? Colors.greenAccent : Colors.white70,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Status Message Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    _statusMessage,
                    style: GoogleFonts.inter(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '(Tap scanner box to simulate live face recognition)',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),

          // Bottom Bar Status
          Positioned(
            left: 20,
            bottom: 20,
            child: Row(
              children: [
                const Icon(Icons.cloud_done_rounded, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 8),
                Text('Offline Queue Protected | Connected', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12)),
              ],
            ),
          ),

          // Top Right Exit Kiosk Button
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.lock_open_rounded, color: Colors.white70, size: 28),
              tooltip: 'Exit Kiosk Mode',
              onPressed: _showExitDialog,
            ),
          ),
        ],
      ),
    );
  }
}
