import 'package:flutter/material.dart';

/// Colors matching data_maintenance_tools web portal (`app.css`).
class AppColors {
  static const bgTop = Color(0xFF1A1A1A);
  static const bgBottom = Color(0xFF2D2D2D);
  static const panel = Color(0xFF2A2A2A);
  static const panelBorder = Color(0xFF404040);
  static const navPanel = Color(0xFF242424);
  static const navBorder = Color(0xFF3A3A3A);
  static const accent = Color(0xFFFF6B35);
  static const accentHover = Color(0xFFFF8555);
  static const brandSteel = Color(0xFFC8C4BC);
  static const secondaryBtn = Color(0xFF555555);
  static const inputBg = Color(0xFF141414);
  static const inputBorder = Color(0xFF4A4A4A);
  static const muted = Color(0xFF8E8E8E);
  static const label = Color(0xFFC9C9C9);
  static const heading = Color(0xFFE8E8E8);
  static const successBg = Color(0xFF1F3D1F);
  static const successBorder = Color(0xFF33CC33);
  static const successText = Color(0xFF99FF99);
  static const errorBg = Color(0xFF3D1F1F);
  static const errorBorder = Color(0xFFCC3333);
  static const errorText = Color(0xFFFF9999);
}

ThemeData buildPromoterTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: base.copyWith(
      primary: AppColors.accent,
      secondary: AppColors.secondaryBtn,
      surface: AppColors.panel,
    ),
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: AppColors.heading,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.inputBg,
      hintStyle: const TextStyle(color: AppColors.muted),
      labelStyle: const TextStyle(color: AppColors.label),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFF3A3A3A),
        disabledForegroundColor: const Color(0xFF777777),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: AppColors.secondaryBtn,
        disabledForegroundColor: const Color(0xFF777777),
        disabledBackgroundColor: const Color(0xFF333333),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    dataTableTheme: const DataTableThemeData(
      headingTextStyle: TextStyle(
        color: AppColors.label,
        fontWeight: FontWeight.w700,
      ),
      dataTextStyle: TextStyle(color: Colors.white),
    ),
  );
}
