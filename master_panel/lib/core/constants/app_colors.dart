import 'package:flutter/material.dart';

/// Curated Premium Indian SaaS Color Palette
class AppColors {
  // Primary Background & Card Tones - Deep Midnight Slate
  static const Color bgDark = Color(0xFF0B132B);          // Deep Indian Midnight
  static const Color cardDark = Color(0xFF1C2541);        // Royal Slate Card
  static const Color cardBorderDark = Color(0xFF334155);  // Warm Border
  static const Color inputBgDark = Color(0xFF0B132B);     // Deep Input Field

  // Signature Indian Vibrant Colors: Kesari Saffron, Haldi Gold, Mayur Blue, Panna Emerald, Sindoor Red
  static const Color kesariSaffron = Color(0xFFFF7722);     // Kesari Orange Saffron
  static const Color kesariSaffronDark = Color(0xFFEA580C); // Deep Saffron Accent
  static const Color haldiGold = Color(0xFFF59E0B);        // Haldi Warm Amber
  static const Color mayurBlue = Color(0xFF0284C7);        // Mayur Peacock Blue
  static const Color royalIndigo = Color(0xFF6366F1);      // Royal Indigo Accent
  static const Color pannaEmerald = Color(0xFF10B981);     // Panna Green / Present & Active
  static const Color sindoorRed = Color(0xFFEF4444);      // Sindoor Red / Alert & Absent
  static const Color royalPurple = Color(0xFF8B5CF6);      // Royal Purple

  // Responsive Indian Premium Gradients
  static const LinearGradient saffronGradient = LinearGradient(
    colors: [Color(0xFFFF7722), Color(0xFFEA580C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient peacockGradient = LinearGradient(
    colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF1C2541), Color(0xFF0B132B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Text Colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textSaffron = Color(0xFFFF9D5C);
}
