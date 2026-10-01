import 'package:flutter/material.dart';

class AppColors {
  // Primary colors - Gradient pink/orange cho dating app
  static const primary = Color(0xFFFF3366);
  static const primaryDark = Color(0xFFE91E63);
  static const secondary = Color(0xFFFF6B9D);
  static const accent = Color(0xFFFFC444);
  
  // Gradient colors
  static const gradientStart = Color(0xFFFF3366);
  static const gradientMiddle = Color(0xFFFF6B9D);
  static const gradientEnd = Color(0xFFFFC444);
  
  // Background colors
  static const background = Color(0xFFF8F9FA);
  static const cardBackground = Colors.white;
  static const darkBackground = Color(0xFF1A1A1A);
  
  // Text colors
  static const textPrimary = Color(0xFF2D3436);
  static const textSecondary = Color(0xFF636E72);
  static const textLight = Color(0xFFB2BEC3);
  static const textWhite = Colors.white;
  
  // Border colors
  static const border = Color(0xFFE8E8E8);
  static const borderFocus = Color(0xFFFF3366);
  
  // Status colors
  static const success = Color(0xFF00B894);
  static const error = Color(0xFFFF7675);
  static const warning = Color(0xFFFDCB6E);
  static const info = Color(0xFF74B9FF);
  
  // Social colors
  static const facebook = Color(0xFF1877F2);
  static const google = Color(0xFFEA4335);
  static const apple = Color(0xFF000000);
  
  // Gradient
  static const primaryGradient = LinearGradient(
    colors: [gradientStart, gradientMiddle, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const softGradient = LinearGradient(
    colors: [Color(0xFFFFE9EF), Color(0xFFFFF5E9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
