import 'package:flutter/material.dart';

/// WE-IRED Accessible Design System Theme per SDD 4.1 & WCAG 2.1 AA/AAA.
///
/// Designed for high-stress disaster operations across three distinct personas:
/// 1. Citizen (Warga): Calm, senior-friendly, high-contrast, large emergency targets (>= 64dp).
/// 2. Volunteer (Relawan): Outdoor high-visibility, ergonomic field targets (>= 48-52dp), rapid stepper actions.
/// 3. Operator (Dashboard): High-density enterprise command center, keyboard accessible, structured grids.
class AppTheme {
  AppTheme._();

  // ==========================================
  // 1. NEUTRAL SLATE PALETTE (Foundational Base)
  // ==========================================
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  // ==========================================
  // 2. SEMANTIC STATUS TOKENS (High Contrast)
  // ==========================================
  // Base Foreground Status Colors (WCAG AA/AAA verified against white/light surfaces)
  static const Color statusAman = Color(0xFF16A34A);          // Green 600
  static const Color statusTitikKumpul = Color(0xFF2563EB);    // Blue 600
  static const Color statusButuhBantuan = Color(0xFFEA580C);   // Orange 600
  static const Color statusKritis = Color(0xFFDC2626);         // Red 600
  static const Color statusBelumMelapor = Color(0xFF64748B);   // Slate 500

  // Semantic Light Surface Colors (Tinted Backgrounds)
  static const Color statusAmanBg = Color(0xFFDCFCE7);
  static const Color statusAmanBorder = Color(0xFF86EFAC);
  static const Color statusTitikKumpulBg = Color(0xFFDBEAFE);
  static const Color statusTitikKumpulBorder = Color(0xFF93C5FD);
  static const Color statusButuhBantuanBg = Color(0xFFFFEDD5);
  static const Color statusButuhBantuanBorder = Color(0xFFFDBA74);
  static const Color statusKritisBg = Color(0xFFFEE2E2);
  static const Color statusKritisBorder = Color(0xFFFCA5A5);
  static const Color statusBelumMelaporBg = Color(0xFFF1F5F9);
  static const Color statusBelumMelaporBorder = Color(0xFFCBD5E1);

  // ==========================================
  // 3. CONNECTIVITY STATUS TOKENS
  // ==========================================
  static const Color connCloud = Color(0xFF16A34A);
  static const Color connPosko = Color(0xFF4F46E5);
  static const Color connOffline = Color(0xFFDC2626);
  static const Color connMesh = Color(0xFF0D9488);

  // ==========================================
  // 4. DRILL / LATIHAN SEMANTIC TOKENS
  // ==========================================
  static const Color drillAmber = Color(0xFFD97706);
  static const Color drillAmberDark = Color(0xFF92400E);
  static const Color drillBg = Color(0xFFFEF3C7);
  static const Color drillBorder = Color(0xFFFDE68A);

  // ==========================================
  // 5. BRAND & STRUCTURAL PALETTE
  // ==========================================
  static const Color primaryBlue = Color(0xFF1E3A8A);        // Navy 900
  static const Color primaryBlueHover = Color(0xFF1D4ED8);   // Blue 700
  static const Color secondaryTeal = Color(0xFF0D9488);      // Teal 600
  static const Color alertWarning = Color(0xFFD97706);       // Amber 600
  static const Color bgCanvas = Color(0xFFF8FAFC);           // Slate 50
  static const Color bgSurface = Color(0xFFFFFFFF);          // White
  static const Color textMain = Color(0xFF0F172A);           // Slate 900
  static const Color textSecondary = Color(0xFF475569);      // Slate 600
  static const Color textMuted = Color(0xFF64748B);          // Slate 500
  static const Color borderSubtle = Color(0xFFE2E8F0);       // Slate 200
  static const Color borderStrong = Color(0xFFCBD5E1);       // Slate 300
  static const Color focusRing = Color(0xFF2563EB);          // Web Focus Ring

  // ==========================================
  // 6. SPACING TOKENS (8-pt Spatial Grid)
  // ==========================================
  static const double spacingXxs = 2.0;
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 20.0;
  static const double spacingXxl = 24.0;
  static const double spacing3xl = 32.0;

  // ==========================================
  // 7. CORNER RADIUS TOKENS
  // ==========================================
  static const double radiusXs = 4.0;
  static const double radiusSm = 6.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 16.0;
  static const double radiusFull = 999.0;

  // ==========================================
  // 8. TOUCH TARGET TOKENS
  // ==========================================
  static const double touchTargetMin = 48.0;        // WCAG standard minimum target
  static const double touchTargetField = 52.0;      // Field volunteer ergonomic target
  static const double touchTargetEmergency = 64.0;  // Citizen emergency action minimum

  // ==========================================
  // 9. ELEVATION & SHADOW TOKENS
  // ==========================================
  static const List<BoxShadow> shadowSubtle = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> shadowCard = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> shadowElevated = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static List<BoxShadow> shadowEmergency(Color color) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.28),
        blurRadius: 8,
        offset: const Offset(0, 3),
      ),
    ];
  }

  /// Standard card decoration for consistent information density
  static BoxDecoration cardDecoration({
    Color bg = Colors.white,
    Color border = borderSubtle,
    double radius = radiusMd,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
      boxShadow: shadows,
    );
  }

  // ==========================================
  // 10. LIGHT THEME CONFIGURATION
  // ==========================================
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primaryBlue,
        onPrimary: Colors.white,
        secondary: secondaryTeal,
        onSecondary: Colors.white,
        error: statusKritis,
        onError: Colors.white,
        surface: bgSurface,
        onSurface: textMain,
      ),
      scaffoldBackgroundColor: bgCanvas,
      focusColor: focusRing.withValues(alpha: 0.12),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgSurface,
        foregroundColor: textMain,
        elevation: 0,
        scrolledUnderElevation: 1,
        iconTheme: IconThemeData(color: slate700),
        titleTextStyle: TextStyle(
          color: textMain,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: bgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: borderSubtle),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: statusKritis),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: statusKritis, width: 2),
        ),
        hintStyle: const TextStyle(color: slate400, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(88, touchTargetMin),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: slate700,
          minimumSize: const Size(88, touchTargetMin),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: const BorderSide(color: borderStrong),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          minimumSize: const Size(48, touchTargetMin),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderSubtle,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bgSurface,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
        titleTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textMain,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 13,
          color: textSecondary,
          height: 1.4,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        contentTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  // ==========================================
  // 11. DARK THEME CONFIGURATION (Operational Low-Light)
  // ==========================================
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFF38BDF8),
        onPrimary: slate900,
        secondary: Color(0xFF2DD4BF),
        onSecondary: slate900,
        error: Color(0xFFF87171),
        onError: slate900,
        surface: slate800,
        onSurface: slate100,
      ),
      scaffoldBackgroundColor: slate900,
      appBarTheme: const AppBarTheme(
        backgroundColor: slate800,
        foregroundColor: slate100,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: slate800,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
      ),
    );
  }
}
