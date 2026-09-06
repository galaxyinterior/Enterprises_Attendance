import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:intl/intl.dart';
import '../models/attendance_log.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/ml_service.dart';
import '../models/employee.dart';
import '../services/database_helper.dart';
import '../repositories/attendance_repository.dart';
import '../services/tts_service.dart';

import '../services/sync_service.dart';
import '../models/store_config.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class KioskScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String storeId;
  const KioskScreen({super.key, required this.cameras, required this.storeId});

  @override
  State<KioskScreen> createState() => _KioskScreenState();
}

class _KioskScreenState extends State<KioskScreen> {
  final AttendanceRepository _attendanceRepo = AttendanceRepository();
  CameraController? _cameraController;
  bool _isProcessing = false;
  Timer? _scanTimer;
  Timer? _heartbeatTimer;
  String _selectedPunchMode = 'AUTO';
  
  Map<String, dynamic>? _lastMatchData;
  String _statusMessage = "Position face in front of camera";
  DateTime _lastMatchTime = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastMatchedEmpId;
  Map<String, dynamic>? _currentBBox;
  Size? _imageSize;
  StoreConfig? _storeConfig;

  // Liveness State
  String? _livenessEmpId;
  String _livenessState = 'idle'; // idle -> waiting_neutral -> waiting_smile -> verified
  DateTime _livenessChallengeStartTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _initCamera();
    _triggerInitialSync();
    _listenForNotifications();
    _startHeartbeat();
  }

  void _startHeartbeat() {
    // Send a heartbeat every 5 minutes
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _sendHeartbeat();
    });
    _sendHeartbeat(); // initial ping
  }

  Future<void> _sendHeartbeat() async {
    try {
      // In a real app, use the actual device ID
      final deviceId = 'kiosk_${widget.storeId}';
      
      await Supabase.instance.client
          .from('devices')
          .upsert({
            'device_uuid': deviceId,
            'store_id': widget.storeId,
            'device_name': 'Main Kiosk',
            'status': 'online',
            'last_seen_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      debugPrint('Heartbeat failed: $e');
    }
  }

  Future<void> _loadConfig() async {
    _storeConfig = await DatabaseHelper.instance.getStoreConfig();
  }

  Future<void> _triggerInitialSync() async {
    // Firestore handles syncing automatically when online
  }

  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty) return;
    
    CameraDescription selectedCam = widget.cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras.first,
    );

    _cameraController = CameraController(
      selectedCam,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.jpeg : ImageFormatGroup.bgra8888,
    );

    try {
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {});
      _startScanning();
    } catch (e) {
      setState(() {
        _statusMessage = "Camera initialization error: $e";
      });
    }
  }

  void _startScanning() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      _captureAndProcessFrame();
    });
  }

  void _listenForNotifications() {
    Supabase.instance.client
        .channel('public:notifications')
        .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'store_id',
              value: widget.storeId,
            ),
            callback: (payload) async {
              final newRecord = payload.newRecord;
              if (newRecord.isEmpty) return;

              final msg = newRecord['message'] as String;
              final audioPath = newRecord['audio_path'] as String?; // Expected to be full URL or base64
              
              if (audioPath != null && audioPath.isNotEmpty) {
                try {
                  // If it's a URL or base64 we can play it
                  if (audioPath.startsWith('http')) {
                     final player = AudioPlayer();
                     await player.play(UrlSource(audioPath));
                  } else {
                     final bytes = base64Decode(audioPath);
                     final dir = await getTemporaryDirectory();
                     final file = File('${dir.path}/announcement_playback.m4a');
                     await file.writeAsBytes(bytes);
                     final player = AudioPlayer();
                     await player.play(DeviceFileSource(file.path));
                  }
                } catch (e) {
                  debugPrint('Error playing voice announcement: $e');
                  TtsService.speakMessage(msg, _storeConfig?.ttsLanguage ?? 'en-IN');
                }
              } else {
                TtsService.speakMessage(msg, _storeConfig?.ttsLanguage ?? 'en-IN');
              }
              
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Announcement: $msg")));
            })
        .subscribe();
  }

  Future<void> _captureAndProcessFrame() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isProcessing) {
      return;
    }

    _isProcessing = true;

    try {
      final XFile file = await _cameraController!.takePicture();
      final File imageFile = File(file.path);

      final decodedImage = await decodeImageFromList(await file.readAsBytes());
      if (!mounted) return;
      _imageSize = Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());

      final inputImage = InputImage.fromFile(imageFile);
      final faceDetector = FaceDetector(options: FaceDetectorOptions(enableClassification: true));
      final faces = await faceDetector.processImage(inputImage);
      faceDetector.close();

      if (faces.isNotEmpty) {
        final face = faces.first;
        final bbox = {
          'x': face.boundingBox.left,
          'y': face.boundingBox.top,
          'width': face.boundingBox.width,
          'height': face.boundingBox.height,
        };

        setState(() {
          _currentBBox = bbox;
        });

        final mlService = MLService();
        await mlService.initialize();
        final currentEmbedding = await mlService.getEmbedding(imageFile, bbox);

        if (currentEmbedding != null) {
          final employees = await DatabaseHelper.instance.getAllEmployees();
          double minDistance = 999.0;
          Employee? bestMatch;

          for (var emp in employees) {
            if (emp.faceEmbedding != null) {
              double distance = mlService.calculateEuclideanDistance(currentEmbedding, emp.faceEmbedding!);
              if (distance < minDistance) {
                minDistance = distance;
                bestMatch = emp;
              }
            }
          }

          if (bestMatch != null && minDistance < 1.0) {
            final empId = bestMatch.empId;
            final now = DateTime.now();

            if (_lastMatchedEmpId == empId && now.difference(_lastMatchTime).inSeconds < 10) {
              setState(() {
                _statusMessage = "Welcome ${bestMatch!.name} (Already Marked)";
              });
              _isProcessing = false;
              return;
            }

            // ---- Liveness Detection: Blink to Verify ----
            double leftEye = face.leftEyeOpenProbability ?? 1.0;
            double rightEye = face.rightEyeOpenProbability ?? 1.0;
            bool isBlinking = leftEye < 0.2 && rightEye < 0.2;
            
            if (_livenessEmpId != empId || now.difference(_livenessChallengeStartTime).inSeconds > 10) {
              _livenessEmpId = empId;
              _livenessChallengeStartTime = now;
              _livenessState = 'waiting_blink';
            }

            if (_livenessState == 'waiting_blink') {
              if (!isBlinking) {
                setState(() {
                  _statusMessage = "Please BLINK both eyes to verify!";
                });
                _isProcessing = false;
                return;
              } else {
                _livenessState = 'verified';
              }
            }
            // ---------------------------------------------

            _lastMatchedEmpId = empId;
            _lastMatchTime = now;

            String punchType = _selectedPunchMode;
            if (punchType == 'AUTO') {
               final lastPunch = await _attendanceRepo.getLastPunch(empId);
               punchType = (lastPunch == 'IN') ? 'OUT' : 'IN';
            }

            String statusFlag = "Present";
            if ((2.0 - minDistance) * 50 < 0.6) {
              statusFlag = "Suspicious";
            }

            if (_storeConfig != null) {
              final nowTime = TimeOfDay.now();
              if (punchType == "IN") {
                if (!_isTimeBetween(nowTime, _storeConfig!.punchInStart, _storeConfig!.punchInEnd)) {
                  setState(() => _statusMessage = "Too early/late for Punch IN");
                  await TtsService.speakMessage("Punch IN not allowed at this time", _storeConfig?.ttsLanguage ?? 'en-IN');
                  _isProcessing = false;
                  return;
                }
              } else if (punchType == "OUT") {
                if (!_isTimeBetween(nowTime, _storeConfig!.punchOutStart, _storeConfig!.punchOutEnd)) {
                  setState(() => _statusMessage = "Too early/late for Punch OUT");
                  await TtsService.speakMessage("Punch OUT not allowed at this time", _storeConfig?.ttsLanguage ?? 'en-IN');
                  _isProcessing = false;
                  return;
                }
              }
            }

            final confidence = (2.0 - minDistance) * 50;
            final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

            try {
              final newLog = AttendanceLog(
                empId: empId,
                empName: bestMatch.name,
                department: bestMatch.department,
                punchTime: formattedTime,
                punchType: punchType,
                confidence: confidence,
                status: statusFlag,
                isSynced: 0,
              );
              await _attendanceRepo.logAttendance(newLog);
              SyncService.syncAllData(widget.storeId);
            } catch (e) {
              debugPrint("Failed to save log: $e");
            }

            int presentDays = await _attendanceRepo.getPresentDaysThisMonth(empId);
            String? checkInTime = await _attendanceRepo.getTodaysCheckInTime(empId);
            
            final result = {
              'employee': bestMatch,
              'punch_type': punchType,
              'confidence': confidence,
              'time': DateFormat('hh:mm a').format(now),
              'present_days': presentDays,
              'check_in_time': checkInTime ?? DateFormat('hh:mm a').format(now),
            };

            TtsService.speakAttendance(bestMatch.name, punchType, _storeConfig?.ttsLanguage ?? 'en-IN');

            _livenessState = 'idle';
            _livenessEmpId = null;

            setState(() {
              _lastMatchData = result;
              _statusMessage = "Verified!";
            });
            
          } else {
            setState(() {
              _statusMessage = "Face not recognized. Please register first.";
              _lastMatchData = null;
            });
          }
        }
      } else {
        setState(() {
          _statusMessage = "Searching for faces...";
          _currentBBox = null;
        });
      }

      if (await imageFile.exists()) {
        await imageFile.delete();
      }
    } catch (e) {
      debugPrint("Frame processing error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  bool _isTimeBetween(TimeOfDay time, String startStr, String endStr) {
    try {
      final startParts = startStr.split(':');
      final endParts = endStr.split(':');
      final s = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final e = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
      final t = time.hour * 60 + time.minute;
      
      if (s > e) return t >= s || t <= e;
      return t >= s && t <= e;
    } catch (_) {
      return true;
    }
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _cameraController?.dispose();
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Premium Dark Blue background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.storefront, color: Color(0xFF00BFFF)),
            const SizedBox(width: 12),
            Text(widget.storeId.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButton<String>(
              value: _selectedPunchMode,
              dropdownColor: const Color(0xFF1E293B),
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00BFFF)),
              items: const [
                DropdownMenuItem(value: 'AUTO', child: Text("AUTO TOGGLE", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                DropdownMenuItem(value: 'IN', child: Text("FORCE IN", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                DropdownMenuItem(value: 'OUT', child: Text("FORCE OUT", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedPunchMode = val);
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Camera Preview
          if (_cameraController != null && _cameraController!.value.isInitialized)
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.height,
                  height: _cameraController!.value.previewSize!.width,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),
          
          // Dark Gradient Overlay for premium feel
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0F172A).withValues(alpha: 0.7),
                  Colors.transparent,
                  const Color(0xFF0F172A).withValues(alpha: 0.9),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Face Bounding Box & Status Text
          if (_lastMatchData == null && _currentBBox != null && _imageSize != null)
            Positioned.fill(
              child: CustomPaint(
                painter: FaceBoundingBoxPainter(
                  bbox: _currentBBox!,
                  imageSize: _imageSize!,
                  screenSize: MediaQuery.of(context).size,
                  color: _livenessState == 'waiting_blink' ? Colors.orangeAccent : const Color(0xFF00BFFF),
                ),
              ),
            ),
            
          if (_lastMatchData == null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 250),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Success ID Card Overlay
          if (_lastMatchData != null)
            Center(
              child: TweenAnimationBuilder(
                duration: const Duration(milliseconds: 500),
                tween: Tween<double>(begin: 0.8, end: 1.0),
                curve: Curves.elasticOut,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: Container(
                  width: 340,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF00BFFF).withValues(alpha: 0.2), blurRadius: 30, spreadRadius: 10),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Using a simple Icon since we don't have a lottie asset downloaded,
                      // but we can add the lottie widget if they have the asset. 
                      // The user just said "lottie animation", we will use a highly styled success icon for now
                      // to simulate the effect, as we don't have the .json file in assets.
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle, color: Colors.green, size: 80),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "PUNCH ${_lastMatchData!['punch_type']}",
                        style: TextStyle(
                          color: _lastMatchData!['punch_type'] == 'IN' ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                          letterSpacing: 2,
                        ),
                      ),
                      const Text("VERIFIED SUCCESSFULLY", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Divider(thickness: 2),
                      ),
                      
                      // ID Card Details
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: const Color(0xFF00BFFF).withValues(alpha: 0.1),
                            child: Text(
                              (_lastMatchData!['employee'] as Employee).name[0].toUpperCase(),
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF00BFFF)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (_lastMatchData!['employee'] as Employee).name,
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                                Text(
                                  (_lastMatchData!['employee'] as Employee).designation,
                                  style: const TextStyle(color: Color(0xFF00BFFF), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _buildInfoRow(Icons.badge, "Emp ID", (_lastMatchData!['employee'] as Employee).empId),
                            const SizedBox(height: 8),
                            _buildInfoRow(Icons.business, "Dept", (_lastMatchData!['employee'] as Employee).department),
                            const SizedBox(height: 8),
                            _buildInfoRow(Icons.access_time, "Punch", _lastMatchData!['time']),
                            const SizedBox(height: 8),
                            _buildInfoRow(Icons.calendar_today, "Present (Month)", "${_lastMatchData!['present_days']} Days"),
                            const SizedBox(height: 8),
                            _buildInfoRow(Icons.login, "Check-in (Today)", _lastMatchData!['check_in_time']),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text("$label: ", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14)),
      ],
    );
  }
}

class FaceBoundingBoxPainter extends CustomPainter {
  final Map<String, dynamic> bbox;
  final Size imageSize;
  final Size screenSize;
  final Color color;

  FaceBoundingBoxPainter({
    required this.bbox,
    required this.imageSize,
    required this.screenSize,
    this.color = const Color(0xFF00BFFF),
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Assuming portrait mode scaling. Camera images are typically rotated 90 degrees in portrait.
    // So imageSize.height becomes the width in portrait mode, and imageSize.width becomes the height.
    final bool isPortrait = screenSize.height > screenSize.width;
    
    final double imgW = isPortrait ? imageSize.height : imageSize.width;
    final double imgH = isPortrait ? imageSize.width : imageSize.height;

    final double scaleX = size.width / imgW;
    final double scaleY = size.height / imgH;

    // ML Kit returns coordinates. We map them.
    // In portrait, x and y might be swapped depending on sensor orientation,
    // but typically ML Kit Normalizes it if we passed the correct rotation.
    // Since we don't handle rotation perfectly in MLService, we just do a direct map.
    // If it's mirrored (front camera), we might need to invert X.
    double left = bbox['x'] * scaleX;
    double top = bbox['y'] * scaleY;
    double width = bbox['width'] * scaleX;
    double height = bbox['height'] * scaleY;

    // Simple mirroring for front camera horizontally
    left = size.width - left - width;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    double cornerLength = 30.0;
    Path path = Path();

    // Top-Left corner
    path.moveTo(left, top + cornerLength);
    path.lineTo(left, top);
    path.lineTo(left + cornerLength, top);

    // Top-Right corner
    path.moveTo(left + width - cornerLength, top);
    path.lineTo(left + width, top);
    path.lineTo(left + width, top + cornerLength);

    // Bottom-Left corner
    path.moveTo(left, top + height - cornerLength);
    path.lineTo(left, top + height);
    path.lineTo(left + cornerLength, top + height);

    // Bottom-Right corner
    path.moveTo(left + width - cornerLength, top + height);
    path.lineTo(left + width, top + height);
    path.lineTo(left + width, top + height - cornerLength);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant FaceBoundingBoxPainter oldDelegate) {
    return oldDelegate.bbox != bbox || oldDelegate.screenSize != screenSize || oldDelegate.imageSize != imageSize || oldDelegate.color != color;
  }
}


