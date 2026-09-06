import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
const String supabaseUrl = 'https://txvxgxcdkqrzfatinrqa.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4dnhneGNka3FyemZhdGlucnFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc3NTk2MTIsImV4cCI6MjEwMzMzNTYxMn0.sb05nzdgWkmDz9phz0-TumEn0xqPu42liS0LFUt-xOE';
const String supabaseServiceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4dnhneGNka3FyemZhdGlucnFhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Nzc1OTYxMiwiZXhwIjoyMTAzMzM1NjEyfQ.uUZFbLhxtri-UEcqSw_PImapsBB1th9jJr3F1Z7Sofw';

// Admin client used specifically for user creation
final adminSupabase = SupabaseClient(supabaseUrl, supabaseServiceRoleKey);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  runApp(const MasterPanelApp());
}

class MasterPanelApp extends StatelessWidget {
  const MasterPanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Master Panel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final session = snapshot.data?.session;
          if (session != null) {
            return const DashboardScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
