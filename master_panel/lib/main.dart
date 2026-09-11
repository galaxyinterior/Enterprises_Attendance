import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'core/constants/app_colors.dart';
import 'features/auth/master_login_screen.dart';
import 'features/dashboard/master_control_panel_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MasterPanelApp());
}

class MasterPanelApp extends StatelessWidget {
  const MasterPanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Master Control Panel - SaaS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bgDark,
        cardColor: AppColors.cardDark,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: AppColors.kesariSaffron,
          secondary: AppColors.haldiGold,
          surface: AppColors.cardDark,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.bgDark,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.kesariSaffron),
            ),
          );
        }

        final user = snapshot.data;
        if (user != null && user.email?.toLowerCase() == 'master@admin.com') {
          // Already logged in as master@admin.com -> Open Master Control Panel directly
          return const MasterControlPanelScreen();
        }

        // Not logged in or different account -> Show Master Login Screen
        return const MasterLoginScreen();
      },
    );
  }
}
