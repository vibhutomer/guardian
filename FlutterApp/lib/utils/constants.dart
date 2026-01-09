import 'package:flutter/material.dart';

class AppColors {
  // Background is now a dark gradient, not just black
  static const Color backgroundStart = Color(0xFF1A1A1A);
  static const Color backgroundEnd = Color(0xFF000000);

  // Neon/Modern Green
  static const Color primaryGreen = Color(0xFF00E676); 
  static const Color glowingGreen = Color(0xFF69F0AE);

  // Alert Red (Brighter for emergency)
  static const Color alertRed = Color(0xFFFF1744);
  static const Color alertOrange = Color(0xFFFF5252);

  // Card Colors (Dark Grey with slight transparency)
  static const Color cardColor = Color(0xFF2C2C2C);
  
  static const Color textWhite = Colors.white;
  static const Color textGrey = Colors.white54;
}

class AppStrings {
  static const String appName = "Guardian";
  static const String monitoring = "Active Monitoring";
  static const String safeMode = "Safe Drive Mode On";
  static const String crashDetected = "CRASH DETECTED";
}