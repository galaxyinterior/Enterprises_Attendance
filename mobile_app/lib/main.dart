import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'screens/kiosk_screen.dart';
import 'screens/admin_panel.dart';
import 'screens/attendance_logs_screen.dart';
import 'screens/login_screen.dart';
import 'screens/face_data_screen.dart';
import 'screens/store_config_screen.dart';
import 'screens/employee_list_screen.dart';
import 'screens/onboarding_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'services/sync_service.dart';

List<CameraDescription> globalCameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Supabase.initialize(
      url: 'https://txvxgxcdkqrzfatinrqa.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4dnhneGNka3FyemZhdGlucnFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc3NTk2MTIsImV4cCI6MjEwMzMzNTYxMn0.sb05nzdgWkmDz9phz0-TumEn0xqPu42liS0LFUt-xOE',
    );
  } catch (e) {
    debugPrint("Supabase initialization failed: $e");
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
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = snapshot.data?.session;
          if (session != null) {
            return AuthenticatedApp(user: session.user, cameras: globalCameras);
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
  String? storeId;
  String? role;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('role, store_id')
          .eq('id', widget.user.id)
          .single();
          
      String? fetchedStoreId = data['store_id'] as String?;
      String storeStatus = 'active';

      if (fetchedStoreId != null) {
        try {
          final storeData = await Supabase.instance.client
              .from('stores')
              .select('status')
              .eq('id', fetchedStoreId)
              .single();
          storeStatus = storeData['status'] as String? ?? 'active';
        } catch (_) {}
      }

      if (storeStatus == 'locked') {
        await Supabase.instance.client.auth.signOut();
        return; // StreamBuilder will redirect to LoginScreen
      }

      setState(() {
        role = data['role'] as String?;
        storeId = fetchedStoreId;
        _isLoading = false;
      });

      if (storeId != null) {
        _setupAutoSync();
        SyncService.syncAllData(storeId!);
      }
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        // No profile found, navigate to OnboardingScreen
        debugPrint('Postgrest error: Profile not found. Navigating to OnboardingScreen.');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => OnboardingScreen(user: widget.user),
            ),
          );
        }
      } else {
        debugPrint('Postgrest error fetching profile: $e');
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Database Error"),
              content: Text(e.message),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
            ),
          );
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Error"),
            content: Text(e.toString()),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setupAutoSync() {
    if (storeId == null) return;
    _syncTimer = Timer.periodic(const Duration(hours: 3), (timer) {
      SyncService.syncAllData(storeId!);
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (!result.contains(ConnectivityResult.none)) {
        SyncService.syncAllData(storeId!);
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
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    if (storeId == null || role == null) {
      return const Scaffold(body: Center(child: Text("Error: Profile not found or incomplete.")));
    }

    if (role == "admin") {
      return AdminPanel(storeId: storeId!, cameras: widget.cameras);
    } else {
      return KioskNavigationContainer(cameras: widget.cameras, storeId: storeId!);
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
              onPressed: () => Supabase.instance.client.auth.signOut(),
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
              onPressed: () => Supabase.instance.client.auth.signOut(),
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

