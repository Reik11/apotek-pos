import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ============================================================
  // COLOR PALETTE — "Clinical Trust" (PRD v2.0)
  // ============================================================

  // Primary: Teal Hijau Tua (dari #1E3A5F → #0D5C4A)
  static const Color primary = Color(0xFF0D5C4A);
  static const Color primaryLight = Color(0xFF1A7A62);
  static const Color primaryLighter = Color(0xFF2E9E80);

  // Accent: Amber Hangat (dari #00B0F0 → #F4A340)
  static const Color accent = Color(0xFFF4A340);
  static const Color accentLight = Color(0xFFF7BA6B);

  // Semantic Colors
  static const Color success = Color(0xFF16A34A); // Green-600
  static const Color warning = Color(0xFFD97706); // Amber-600
  static const Color danger = Color(0xFFDC2626); // Red-600
  static const Color info = Color(0xFF0891B2); // Cyan-600

  // Neutrals & Background
  static const Color background = Color(0xFFF0FAFA); // Teal-tinted white
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF5FAFA); // Kartu sekunder
  static const Color border = Color(0xFFD1E8E4); // Border halus

  // Text
  static const Color textPrimary = Color(0xFF1C3D34); // Teal-900
  static const Color textSecondary = Color(0xFF5E8278); // Teal-600/muted
  static const Color textHint = Color(0xFF9BBAB5); // Teal-300

  // Sidebar
  static const Color sidebarBg = Color(0xFF0D5C4A); // Sama dgn primary
  static const Color sidebarActive =
      Color(0xFF1A7A62); // Satu tone lebih terang
  static const Color sidebarText = Color(0xFFE6F4F1);
  static const Color sidebarHint = Color(0xFF9BBAB5);

  // ============================================================
  // GRADIENTS
  // ============================================================
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D5C4A), Color(0xFF1A7A62)],
  );

  static const LinearGradient sidebarGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A4A3A), Color(0xFF0D5C4A)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF4A340), Color(0xFFF7BA6B)],
  );

  // Card gradient untuk stat cards dashboard
  static LinearGradient cardGradient1 = LinearGradient(
    colors: [Color(0xFF0D5C4A), Color(0xFF1A9E7A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static LinearGradient cardGradient2 = LinearGradient(
    colors: [Color(0xFF0891B2), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static LinearGradient cardGradient3 = LinearGradient(
    colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static LinearGradient cardGradient4 = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF9061F9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ============================================================
  // SPACING & RADIUS
  // ============================================================
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXL = 24.0;

  static const EdgeInsets paddingCard = EdgeInsets.all(20);
  static const EdgeInsets paddingPage = EdgeInsets.all(24);
  static const EdgeInsets paddingSection =
      EdgeInsets.symmetric(horizontal: 24, vertical: 16);

  // ============================================================
  // SHADOWS
  // ============================================================
  static List<BoxShadow> get shadowCard => [
        BoxShadow(
          color: Color(0xFF0D5C4A).withOpacity(0.06),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get shadowSubtle => [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ];

  // ============================================================
  // TYPOGRAPHY — Plus Jakarta Sans (heading) + Inter (body)
  // ============================================================
  static TextTheme get textTheme => TextTheme(
        // Headings — Plus Jakarta Sans
        displayLarge: GoogleFonts.plusJakartaSans(
            fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary),
        displayMedium: GoogleFonts.plusJakartaSans(
            fontSize: 28, fontWeight: FontWeight.w700, color: textPrimary),
        displaySmall: GoogleFonts.plusJakartaSans(
            fontSize: 24, fontWeight: FontWeight.w600, color: textPrimary),
        headlineLarge: GoogleFonts.plusJakartaSans(
            fontSize: 22, fontWeight: FontWeight.w600, color: textPrimary),
        headlineMedium: GoogleFonts.plusJakartaSans(
            fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        headlineSmall: GoogleFonts.plusJakartaSans(
            fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        // Body — Inter
        bodyLarge: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary),
        bodyMedium: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary),
        bodySmall: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w400, color: textSecondary),
        // Labels
        labelLarge: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
        labelMedium: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary),
        labelSmall: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w500, color: textHint),
      );

  // ============================================================
  // THEME DATA
  // ============================================================
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          secondary: accent,
          surface: surface,
          background: background,
          error: danger,
        ),
        scaffoldBackgroundColor: background,
        textTheme: textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: surface,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
            side: BorderSide(color: border, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMedium),
            ),
            textStyle:
                GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
            borderSide: BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
            borderSide: BorderSide(color: primary, width: 2),
          ),
          hintStyle: GoogleFonts.inter(fontSize: 14, color: textHint),
        ),
      );
}
