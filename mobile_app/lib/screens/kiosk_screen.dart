import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

import '../models/attendance_log.dart';
import '../models/employee.dart';
import '../models/store_config.dart';
import '../services/ml_service.dart';
import '../services/database_helper.dart';
import '../services/camera_stream_helper.dart';
import '../repositories/attendance_repository.dart';
import '../services/tts_service.dart';
import '../services/sync_service.dart';

class KioskScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String storeId;
  const KioskScreen({super.key, required this.cameras, required this.storeId});

  @override
  State<KioskScreen> createState() => _KioskScreenState();
}

class _KioskScreenState extends State<KioskScreen> with WidgetsBindingObserver {
  final AttendanceRepository _attendanceRepo = AttendanceRepository();
  final MLService _mlService = MLService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Reusable FaceDetector - initialized once, closed on dispose
  late final FaceDetector _faceDetector;

  CameraController? _cameraController;
  CameraDescription? _selectedCamera;
  bool _isCameraInitializing = false;
  bool _isStreaming = false;

  // Frame gating & throttling (Target: ~2 FPS, dropped if busy)
  static const int _frameIntervalMs = 500;
  int _lastProcessedTimestamp = 0;
  bool _isProcessing = false;
  bool _isCoolingDown = false;
  bool _isAttendanceSubmitting = false;

  // In-memory Employee & Biometrics Cache
  List<Employee> _cachedEmployees = [];

  // Fine-grained UI State Notifiers (Avoid full-screen setState on camera frames)
  final ValueNotifier<Map<String, dynamic>?> _currentBBoxNotifier = ValueNotifier(null);
  final ValueNotifier<Size?> _imageSizeNotifier = ValueNotifier(null);
  final ValueNotifier<String> _statusNotifier = ValueNotifier("Position face in front of camera");
  final ValueNotifier<Map<String, dynamic>?> _lastMatchDataNotifier = ValueNotifier(null);

  // Timers & Subscriptions
  Timer? _heartbeatTimer;
  Timer? _cooldownTimer;
  RealtimeChannel? _notificationsChannel;
  String _selectedPunchMode = 'AUTO';
  DateTime _lastMatchTime = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastMatchedEmpId;
  StoreConfig? _storeConfig;

  // Liveness State
  String? _livenessEmpId;
  String _livenessState = 'idle';
  DateTime _livenessChallengeStartTime = DateTime.now();

  // Diagnostic Counters (Debug performance safety controls)
  int _totalFramesReceived = 0;
  int _framesProcessed = 0;
  int _framesDropped = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize FaceDetector with performance-focused options
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.15,
      ),
    );

    _mlService.initialize();
    _loadConfig();
    _loadEmployeesCache();
    _initCamera();
    _listenForNotifications();
    _startHeartbeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stopCameraStream();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
      _loadEmployeesCache(); // Refresh cache on resume
    }
  }

  /// Caches all employees and their embeddings into memory so scanning performs 0 SQLite queries
  Future<void> _loadEmployeesCache() async {
    try {
      final allEmployees = await DatabaseHelper.instance.getAllEmployees();
      _cachedEmployees = allEmployees.where((emp) => emp.faceEmbedding != null).toList();
      debugPrint("[KioskScreen] Cached ${_cachedEmployees.length} employee face embeddings in memory.");
    } catch (e) {
      debugPrint("[KioskScreen] Error loading employee cache: $e");
    }
  }

  Future<void> _loadConfig() async {
    _storeConfig = await DatabaseHelper.instance.getStoreConfig();
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (_) => _sendHeartbeat());
    _sendHeartbeat();
  }

  Future<void> _sendHeartbeat() async {
    try {
      final deviceId = 'kiosk_${widget.storeId}';
      await Supabase.instance.client.from('devices').upsert({
        'device_uuid': deviceId,
        'store_id': widget.storeId,
        'device_name': 'Main Kiosk',
        'status': 'online',
        'last_seen_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[KioskScreen] Heartbeat failed: $e');
    }
  }

  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty || _isCameraInitializing) return;
    _isCameraInitializing = true;

    try {
      // Clean up previous controller safely if any
      await _stopCameraStream();
      if (_cameraController != null) {
        await _cameraController!.dispose();
        _cameraController = null;
      }

      _selectedCamera = widget.cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => widget.cameras.first,
      );

      final controller = CameraController(
        _selectedCamera!,
        ResolutionPreset.low, // 352x288 / 320x240 for high performance & minimal thermals
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;
      setState(() {});

      _startCameraStream();
    } catch (e) {
      debugPrint("[KioskScreen] Camera initialization error: $e");
      _statusNotifier.value = "Camera error: $e";
    } finally {
      _isCameraInitializing = false;
    }
  }

  void _startCameraStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isStreaming) return;

    try {
      _isStreaming = true;
      _cameraController!.startImageStream(_handleCameraFrame);
    } catch (e) {
      debugPrint("[KioskScreen] Error starting image stream: $e");
      _isStreaming = false;
    }
  }

  Future<void> _stopCameraStream() async {
    if (_cameraController != null && _isStreaming) {
      try {
        await _cameraController!.stopImageStream();
      } catch (e) {
        debugPrint("[KioskScreen] Error stopping image stream: $e");
      } finally {
        _isStreaming = false;
      }
    }
  }

  /// High-performance frame gate. Drops frames during processing, cooldown, or when within throttling threshold.
  void _handleCameraFrame(CameraImage image) {
    _totalFramesReceived++;

    // 1. Drop frame immediately if busy or in post-attendance cooldown
    if (_isProcessing || _isCoolingDown || _isAttendanceSubmitting) {
      _framesDropped++;
      return;
    }

    // 2. Frame rate throttle gate (~2 FPS / 500ms)
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastProcessedTimestamp < _frameIntervalMs) {
      _framesDropped++;
      return;
    }

    _lastProcessedTimestamp = now;
    _isProcessing = true;
    _framesProcessed++;

    if (kDebugMode && _totalFramesReceived % 100 == 0) {
      debugPrint("[KioskPerf] Rx: $_totalFramesReceived, Processed: $_framesProcessed, Dropped: $_framesDropped");
    }

    _processFrame(image);
  }

  /// Complete in-memory zero-disk recognition pipeline
  Future<void> _processFrame(CameraImage image) async {
    try {
      if (_selectedCamera == null || !mounted) return;

      // 1. Convert frame to InputImage directly from memory
      final inputImage = CameraStreamHelper.inputImageFromCameraImage(
        image: image,
        camera: _selectedCamera!,
      );

      if (inputImage == null) return;

      // 2. Fast face detection using reusable FaceDetector
      final faces = await _faceDetector.processImage(inputImage);

      if (!mounted || _isCoolingDown) return;

      if (faces.isEmpty) {
        _currentBBoxNotifier.value = null;
        if (_lastMatchDataNotifier.value == null) {
          _statusNotifier.value = "Position face in front of camera";
        }
        return;
      }

      final face = faces.first;
      final bbox = {
        'x': face.boundingBox.left,
        'y': face.boundingBox.top,
        'width': face.boundingBox.width,
        'height': face.boundingBox.height,
      };

      _currentBBoxNotifier.value = bbox;
      _imageSizeNotifier.value = Size(image.width.toDouble(), image.height.toDouble());

      // 3. Convert YUV to rotated in-memory image ONLY when a face is detected
      final rotatedImg = CameraStreamHelper.convertYuv420ToRotatedImage(
        image,
        _selectedCamera!.sensorOrientation,
      );

      // 4. Extract Face Embedding via TFLite MobileFaceNet with typed Float32List buffer
      final currentEmbedding = await _mlService.getEmbeddingFromImage(rotatedImg, bbox);
      if (currentEmbedding == null || !mounted) return;

      // 5. Match against In-Memory Employee Cache (Zero SQLite queries!)
      double minDistance = 999.0;
      Employee? bestMatch;

      for (final emp in _cachedEmployees) {
        if (emp.faceEmbedding != null) {
          final double distance = _mlService.calculateEuclideanDistance(currentEmbedding, emp.faceEmbedding!);
          if (distance < minDistance) {
            minDistance = distance;
            bestMatch = emp;
          }
        }
      }

      // Recognition match threshold (MobileFaceNet distance < 1.0)
      if (bestMatch != null && minDistance < 1.0) {
        await _handleMatchedFace(bestMatch, minDistance, face);
      } else {
        if (_lastMatchDataNotifier.value == null) {
          _statusNotifier.value = "Face not recognized. Please register first.";
        }
      }
    } catch (e) {
      debugPrint("[KioskScreen] Frame processing error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _handleMatchedFace(Employee bestMatch, double minDistance, Face face) async {
    final empId = bestMatch.empId;
    final now = DateTime.now();

    // Prevent immediate duplicate punches for the same person
    if (_lastMatchedEmpId == empId && now.difference(_lastMatchTime).inSeconds < 10) {
      _statusNotifier.value = "Welcome ${bestMatch.name} (Already Marked)";
      return;
    }

    // Liveness Detection: Blink to Verify
    final double leftEye = face.leftEyeOpenProbability ?? 1.0;
    final double rightEye = face.rightEyeOpenProbability ?? 1.0;
    final bool isBlinking = leftEye < 0.2 && rightEye < 0.2;

    if (_livenessEmpId != empId || now.difference(_livenessChallengeStartTime).inSeconds > 10) {
      _livenessEmpId = empId;
      _livenessChallengeStartTime = now;
      _livenessState = 'waiting_blink';
    }

    if (_livenessState == 'waiting_blink') {
      if (!isBlinking) {
        _statusNotifier.value = "Please BLINK both eyes to verify!";
        return;
      } else {
        _livenessState = 'verified';
      }
    }

    // Success Punch Flow
    _lastMatchedEmpId = empId;
    _lastMatchTime = now;
    _isAttendanceSubmitting = true;

    String punchType = _selectedPunchMode;
    if (punchType == 'AUTO') {
      final lastPunch = await _attendanceRepo.getLastPunch(empId);
      punchType = (lastPunch == 'IN') ? 'OUT' : 'IN';
    }

    String statusFlag = "Present";
    if ((2.0 - minDistance) * 50 < 0.6) {
      statusFlag = "Suspicious";
    }

    // Check store schedule constraints
    if (_storeConfig != null) {
      final nowTime = TimeOfDay.now();
      if (punchType == "IN") {
        if (!_isTimeBetween(nowTime, _storeConfig!.punchInStart, _storeConfig!.punchInEnd)) {
          _statusNotifier.value = "Too early/late for Punch IN";
          await TtsService.speakMessage("Punch IN not allowed at this time", _storeConfig?.ttsLanguage ?? 'en-IN');
          _isAttendanceSubmitting = false;
          return;
        }
      } else if (punchType == "OUT") {
        if (!_isTimeBetween(nowTime, _storeConfig!.punchOutStart, _storeConfig!.punchOutEnd)) {
          _statusNotifier.value = "Too early/late for Punch OUT";
          await TtsService.speakMessage("Punch OUT not allowed at this time", _storeConfig?.ttsLanguage ?? 'en-IN');
          _isAttendanceSubmitting = false;
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

      // Save local attendance record
      await _attendanceRepo.logAttendance(newLog);

      // Instant lightweight upload of pending outbox without downloading remote database
      SyncService.uploadPendingOutbox(widget.storeId);
    } catch (e) {
      debugPrint("[KioskScreen] Failed to save log: $e");
    }

    final int presentDays = await _attendanceRepo.getPresentDaysThisMonth(empId);
    final String? checkInTime = await _attendanceRepo.getTodaysCheckInTime(empId);

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

    // Display Success Card
    _lastMatchDataNotifier.value = result;
    _statusNotifier.value = "Verified!";

    // --- PAUSE SCANNING & COOLDOWN ---
    // Pause face recognition for 3.5 seconds to prevent re-triggering and let device rest
    _isCoolingDown = true;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        _lastMatchDataNotifier.value = null;
        _currentBBoxNotifier.value = null;
        _statusNotifier.value = "Position face in front of camera";
        _isCoolingDown = false;
        _isAttendanceSubmitting = false;
      }
    });
  }

  void _listenForNotifications() {
    _notificationsChannel = Supabase.instance.client
        .channel('public:notifications:kiosk_${widget.storeId}')
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
            if (newRecord.isEmpty || !mounted) return;

            final msg = newRecord['message'] as String;
            final audioPath = newRecord['audio_path'] as String?;

            if (audioPath != null && audioPath.isNotEmpty) {
              try {
                await _audioPlayer.stop(); // Stop any currently playing audio
                if (audioPath.startsWith('http')) {
                  await _audioPlayer.play(UrlSource(audioPath));
                } else {
                  final bytes = base64Decode(audioPath);
                  final dir = await getTemporaryDirectory();
                  final file = File('${dir.path}/announcement_playback.m4a');
                  await file.writeAsBytes(bytes);
                  await _audioPlayer.play(DeviceFileSource(file.path));
                }
              } catch (e) {
                debugPrint('[KioskScreen] Audio playback error: $e');
                TtsService.speakMessage(msg, _storeConfig?.ttsLanguage ?? 'en-IN');
              }
            } else {
              TtsService.speakMessage(msg, _storeConfig?.ttsLanguage ?? 'en-IN');
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Announcement: $msg")));
            }
          },
        );

    _notificationsChannel?.subscribe();
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
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTimer?.cancel();
    _heartbeatTimer?.cancel();

    _stopCameraStream();
    _cameraController?.dispose();
    _cameraController = null;

    _faceDetector.close();
    _audioPlayer.dispose();

    if (_notificationsChannel != null) {
      Supabase.instance.client.removeChannel(_notificationsChannel!);
    }

    _currentBBoxNotifier.dispose();
    _imageSizeNotifier.dispose();
    _statusNotifier.dispose();
    _lastMatchDataNotifier.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
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
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.height,
                  height: _cameraController!.value.previewSize!.width,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),

          // Dark Gradient Overlay
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

          // Target Bounding Box Painter - Rebuilds only when bbox changes
          ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: _lastMatchDataNotifier,
            builder: (context, matchData, _) {
              if (matchData != null) return const SizedBox.shrink();

              return ValueListenableBuilder<Map<String, dynamic>?>(
                valueListenable: _currentBBoxNotifier,
                builder: (context, bbox, _) {
                  if (bbox == null) return const SizedBox.shrink();

                  return ValueListenableBuilder<Size?>(
                    valueListenable: _imageSizeNotifier,
                    builder: (context, imgSize, _) {
                      if (imgSize == null) return const SizedBox.shrink();

                      return Positioned.fill(
                        child: CustomPaint(
                          painter: FaceBoundingBoxPainter(
                            bbox: bbox,
                            imageSize: imgSize,
                            screenSize: MediaQuery.of(context).size,
                            color: _livenessState == 'waiting_blink' ? Colors.orangeAccent : const Color(0xFF00BFFF),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),

          // Status Badge Pill - Rebuilds only when status string updates
          ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: _lastMatchDataNotifier,
            builder: (context, matchData, _) {
              if (matchData != null) return const SizedBox.shrink();

              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 250),
                    const SizedBox(height: 32),
                    ValueListenableBuilder<String>(
                      valueListenable: _statusNotifier,
                      builder: (context, status, _) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 1.1,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),

          // Success ID Card Overlay
          ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: _lastMatchDataNotifier,
            builder: (context, matchData, _) {
              if (matchData == null) return const SizedBox.shrink();

              final employee = matchData['employee'] as Employee;
              final punchType = matchData['punch_type'] as String;

              return Center(
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 400),
                  tween: Tween<double>(begin: 0.85, end: 1.0),
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
                        BoxShadow(
                          color: const Color(0xFF00BFFF).withValues(alpha: 0.25),
                          blurRadius: 30,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_circle, color: Colors.green, size: 72),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "PUNCH $punchType",
                          style: TextStyle(
                            color: punchType == 'IN' ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                            letterSpacing: 2,
                          ),
                        ),
                        const Text(
                          "VERIFIED SUCCESSFULLY",
                          style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(thickness: 1.5),
                        ),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: const Color(0xFF00BFFF).withValues(alpha: 0.1),
                              child: Text(
                                employee.name.isNotEmpty ? employee.name[0].toUpperCase() : 'E',
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF00BFFF)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    employee.name,
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                  Text(
                                    employee.designation,
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
                              _buildInfoRow(Icons.badge, "Emp ID", employee.empId),
                              const SizedBox(height: 8),
                              _buildInfoRow(Icons.business, "Dept", employee.department),
                              const SizedBox(height: 8),
                              _buildInfoRow(Icons.access_time, "Punch", matchData['time'] as String),
                              const SizedBox(height: 8),
                              _buildInfoRow(Icons.calendar_today, "Present (Month)", "${matchData['present_days']} Days"),
                              const SizedBox(height: 8),
                              _buildInfoRow(Icons.login, "Check-in (Today)", matchData['check_in_time'] as String),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
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
    final bool isPortrait = screenSize.height > screenSize.width;
    final double imgW = isPortrait ? imageSize.height : imageSize.width;
    final double imgH = isPortrait ? imageSize.width : imageSize.height;

    final double scaleX = size.width / imgW;
    final double scaleY = size.height / imgH;

    double left = (bbox['x'] as num).toDouble() * scaleX;
    double top = (bbox['y'] as num).toDouble() * scaleY;
    double width = (bbox['width'] as num).toDouble() * scaleX;
    double height = (bbox['height'] as num).toDouble() * scaleY;

    // Horizontal mirroring for front camera
    left = size.width - left - width;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const double cornerLength = 28.0;
    final Path path = Path();

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
    return oldDelegate.bbox != bbox ||
        oldDelegate.screenSize != screenSize ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.color != color;
  }
}
