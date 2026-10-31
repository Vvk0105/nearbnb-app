import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The NearBnB palette, the same teal as the website (frontend/tailwind.config.js). Change the brand here and the whole app follows.
class Brand {
  static const b50 = Color(0xFFF0FDFA);
  static const b100 = Color(0xFFCCFBF1);
  static const b200 = Color(0xFF99F6E4);
  static const b300 = Color(0xFF5EEAD4);
  static const b400 = Color(0xFF2DD4BF);
  static const b500 = Color(0xFF14B8A6);
  static const b600 = Color(0xFF0D9488);
  static const b700 = Color(0xFF0F766E);
  static const b800 = Color(0xFF115E59);
  static const b900 = Color(0xFF134E4A);

  static const ink = Color(0xFF0F172A);       // headings and main text
  static const slate600 = Color(0xFF475569);  // secondary text
  static const slate400 = Color(0xFF94A3B8);  // hints
  static const line = Color(0xFFE2E8F0);      // borders
  static const canvas = Color(0xFFF8FAFC);    // page background
  static const amber = Color(0xFFF59E0B);     // "needs you" and stars
  static const danger = Color(0xFFDC2626);
  static const success = Color(0xFF16A34A);
}

class AppTheme {
  static const radius = 14.0;

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Brand.b600, primary: Brand.b600, surface: Colors.white, error: Brand.danger),
      scaffoldBackgroundColor: Brand.canvas,
    );
    final text = GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: Brand.ink, displayColor: Brand.ink);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    return base.copyWith(
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Brand.canvas,
        foregroundColor: Brand.ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Brand.b600,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: shape,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Brand.ink,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: Brand.line),
          shape: shape,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Brand.b700)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: const BorderSide(color: Brand.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: const BorderSide(color: Brand.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: const BorderSide(color: Brand.b500, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: const BorderSide(color: Brand.danger)),
        hintStyle: const TextStyle(color: Brand.slate400),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Brand.line)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Brand.b100,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontSize: 12,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
              color: s.contains(WidgetState.selected) ? Brand.b800 : Brand.slate600,
            )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? Brand.b800 : Brand.slate600)),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white,
        selectedColor: Brand.b100,
        side: const BorderSide(color: Brand.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Brand.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(color: Brand.line, space: 1),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
    );
  }
}
