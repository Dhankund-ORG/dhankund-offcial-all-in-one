import 'package:flutter/material.dart';

class AppTheme {
  // Brand colors (Mapped to Clean Corporate Light Theme)
  static const Color obsidianDark = Color(0xFFF8F9FC);   // Scaffold background (Slate 50)
  static const Color obsidianMedium = Color(0xFFFFFFFF); // Card background (White)
  static const Color obsidianLight = Color(0xFFF1F5F9);  // Input background / Hover (Slate 100)
  static const Color royalGold = Color(0xFF4F46E5);      // Primary Accent (Indigo 600)
  static const Color brightGold = Color(0xFF2563EB);     // Secondary Accent (Blue 600)
  static const Color emeraldGreen = Color(0xFF10B981);   // Success status (Emerald 500)
  static const Color rubyRed = Color(0xFFEF4444);        // Error status (Rose 500)
  static const Color textPrimary = Color(0xFF0F172A);    // Primary Text (Slate 900)
  static const Color textSecondary = Color(0xFF64748B);  // Secondary Text (Slate 500)
  static const Color goldAccent = Color(0xFF818CF8);     // Highlight Accent

  // Background Solid / Soft Gradient
  static const BoxDecoration backgroundGradient = BoxDecoration(
    color: obsidianDark,
  );

  // Glassmorphic Decoration (Clean Light Cards)
  static BoxDecoration glassDecoration({
    Color color = Colors.white,
    double borderRadius = 16.0,
    double borderWidth = 1.0,
    bool showBorder = true,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius),
      border: showBorder
          ? Border.all(
              color: const Color(0xFFE2E8F0), // Slate 200 clean border
              width: borderWidth,
            )
          : null,
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.04), // soft premium grey shadow
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Highlighted Glassmorphic Decoration (Indigo accent tint)
  static BoxDecoration goldGlassDecoration({
    double borderRadius = 16.0,
  }) {
    return BoxDecoration(
      color: royalGold.withOpacity(0.05), // Indigo 50 tint
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: royalGold.withOpacity(0.2), // Indigo 200 border
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: royalGold.withOpacity(0.02),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static ThemeData get themeData {
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: obsidianDark,
      primaryColor: royalGold,
      colorScheme: const ColorScheme.light().copyWith(
        primary: royalGold,
        secondary: brightGold,
        background: obsidianDark,
        surface: obsidianMedium,
        error: rubyRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: textPrimary, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        headlineMedium: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
        labelLarge: TextStyle(color: royalGold, fontSize: 14, fontWeight: FontWeight.bold),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: royalGold, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: royalGold,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: royalGold,
          side: const BorderSide(color: royalGold),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
