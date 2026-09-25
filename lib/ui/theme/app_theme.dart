import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Color(0xFFFFFFFF); // White
  static const Color surfaceSecondary = Color(0xFFF1F5F9); // Slate 100
  static const Color surfaceSubtle = Color(0xFFE2E8F0); // Slate 200

  // Brand / Primary
  static const Color primary = Color(0xFF1E40AF); // Blue 800
  static const Color primaryLight = Color(0xFF3B82F6); // Blue 500
  static const Color primaryHover = Color(0xFF1D4ED8); // Blue 700
  static const Color primaryBackground = Color(0xFFEFF6FF); // Blue 50

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color borderStrong = Color(0xFFCBD5E1); // Slate 300

  // Typography
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF64748B); // Slate 500
  static const Color textLight = Color(0xFF94A3B8); // Slate 400

  // Semantic Status
  static const Color success = Color(0xFF059669); // Emerald 600
  static const Color successBg = Color(0xFFD1FAE5); // Emerald 100
  static const Color warning = Color(0xFFD97706); // Amber 600
  static const Color warningBg = Color(0xFFFEF3C7); // Amber 100
  static const Color error = Color(0xFFDC2626); // Red 600
  static const Color errorBg = Color(0xFFFEE2E2); // Red 100
  static const Color info = Color(0xFF0284C7); // Sky 600
  static const Color infoBg = Color(0xFFE0F2FE); // Sky 100
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Segoe UI',
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.primaryLight,
        surface: AppColors.surface,
        background: AppColors.background,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onBackground: AppColors.textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: AppColors.textSecondary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderStrong),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
