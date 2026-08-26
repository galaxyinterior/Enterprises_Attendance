import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'screens/kiosk_screen.dart';
import 'screens/admin_panel.dart';
import 'screens/attendance_logs_screen.dart';
import 'screens/login_screen.dart';
import 'screens/face_data_screen.dart';
import 'screens/store_config_screen.dart';
import 'screens/employee_list_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'services/sync_service.dart';

List<CameraDescription> globalCameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }

  try {
    globalCameras = await availableCameras();
  } catch (e) {
    debugPrint("Failed to load device cameras: $e");
  }
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Enterprise Face Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00BFFF), // Laser Blue
          brightness: Brightness.light,       // Premium White background
          primary: const Color(0xFF00BFFF),
          surface: const Color(0xFFF8F9FA),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return AuthenticatedApp(user: snapshot.data!, cameras: globalCameras);
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

class AuthenticatedApp extends StatefulWidget {
  final User user;
  final List<CameraDescription> cameras;

  const AuthenticatedApp({super.key, required this.user, required this.cameras});

  @override
  State<AuthenticatedApp> createState() => _AuthenticatedAppState();
}

class _AuthenticatedAppState extends State<AuthenticatedApp> {
  Timer? _syncTimer;
  StreamSubscription? _connectivitySubscription;
  late String storeId;
  late String role;

  @override
  void initState() {
    super.initState();
    _parseUserDetails();
    _setupAutoSync();
    
    // Trigger initial restore/sync on login
    SyncService.syncAllData(storeId);
  }

  void _parseUserDetails() {
    final email = widget.user.email ?? "";
    if (email.contains("@")) {
      final parts = email.split("@");
      role = parts[0];
      final domain = parts[1];
      storeId = domain.split(".")[0];
    } else {
      role = "kiosk";
      storeId = "default";
    }
  }

  void _setupAutoSync() {
    _syncTimer = Timer.periodic(const Duration(hours: 3), (timer) {
      SyncService.syncAllData(storeId);
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (!result.contains(ConnectivityResult.none)) {
        SyncService.syncAllData(storeId);
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (role == "admin") {
      return AdminPanel(storeId: storeId, cameras: widget.cameras);
    } else {
      return KioskNavigationContainer(cameras: widget.cameras, storeId: storeId);
    }
  }
}

class KioskNavigationContainer extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String storeId;
  const KioskNavigationContainer({super.key, required this.cameras, required this.storeId});

  @override
  State<KioskNavigationContainer> createState() => _KioskNavigationContainerState();
}

class _KioskNavigationContainerState extends State<KioskNavigationContainer> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      Scaffold(
        appBar: AppBar(
          title: Text("Kiosk - ${widget.storeId}", style: const TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: () => FirebaseAuth.instance.signOut(),
            )
          ],
        ),
        body: KioskScreen(cameras: widget.cameras, storeId: widget.storeId),
      ),
      Scaffold(
        appBar: AppBar(
          title: Text("Logs - ${widget.storeId}", style: const TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: () => FirebaseAuth.instance.signOut(),
            )
          ],
        ),
        body: AttendanceLogsScreen(storeId: widget.storeId),
      ),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        indicatorColor: const Color(0xFF00BFFF).withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.camera_front_outlined),
            selectedIcon: Icon(Icons.camera_front, color: Color(0xFF00BFFF)),
            label: "Scanner",
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: Color(0xFF00BFFF)),
            label: "Logs & Sync",
          ),
        ],
      ),
    );
  }
}

