import 'package:flutter/material.dart';

/// WE-IRED Accessible Design System Theme per SDD 4.1 & WCAG AAA.
class AppTheme {
  AppTheme._();

  // Status Colors
  static const Color statusAman = Color(0xFF16A34A);         // Green
  static const Color statusTitikKumpul = Color(0xFF2563EB);   // Blue
  static const Color statusButuhBantuan = Color(0xFFEA580C);  // Orange
  static const Color statusKritis = Color(0xFFDC2626);        // Red
  static const Color statusBelumMelapor = Color(0xFF6B7280);  // Gray

  // Connectivity Status Colors
  static const Color connCloud = Color(0xFF16A34A);
  static const Color connPosko = Color(0xFF6366F1);
  static const Color connOffline = Color(0xFFDC2626);

  // Brand Palette
  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color secondaryTeal = Color(0xFF0D9488);
  static const Color alertWarning = Color(0xFFF59E0B);
  static const Color bgCanvas = Color(0xFFF8FAFC);
  static const Color bgSurface = Color(0xFFFFFFFF);
  static const Color textMain = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: secondaryTeal,
        surface: bgSurface,
      ),
      scaffoldBackgroundColor: bgCanvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: bgSurface,
        foregroundColor: textMain,
        elevation: 1,
      ),
      cardTheme: CardTheme(
        color: bgSurface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
    );
  }
}
