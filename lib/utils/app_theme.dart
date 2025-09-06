import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- Colors ---
  static const Color primaryColor = Color(0xFF0D47A1); // Deep Blue
  static const Color secondaryColor = Color(0xFF00ACC1); // Cyan
  static const Color accentColor = Color(0xFFFFAB00); // Amber

  static const Color successColor = Color(0xFF388E3C); // Green
  static const Color errorColor = Color(0xFFD32F2F); // Red
  static const Color warningColor = Color(0xFFFFA000); // Orange

  static const Color backgroundColor = Color(0xFFF5F7FA); // Light Grey
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF333333);
  static const Color subtextColor = Color(0xFF757575);

  // --- Text Styles ---
  static final TextTheme _textTheme = TextTheme(
    displayLarge: GoogleFonts.poppins(fontSize: 57, fontWeight: FontWeight.w300, letterSpacing: -0.25, color: textColor),
    displayMedium: GoogleFonts.poppins(fontSize: 45, fontWeight: FontWeight.w400, color: textColor),
    displaySmall: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.w400, color: textColor),
    headlineLarge: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: textColor),
    headlineMedium: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: textColor),
    headlineSmall: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: textColor),
    titleLarge: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, color: textColor),
    titleMedium: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.15, color: textColor),
    titleSmall: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1, color: textColor),
    bodyLarge: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5, color: textColor),
    bodyMedium: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25, color: textColor),
    bodySmall: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4, color: subtextColor),
    labelLarge: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1.25, color: Colors.white),
    labelMedium: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 1.0, color: textColor),
    labelSmall: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w400, letterSpacing: 1.5, color: textColor),
  );

  // --- Main Theme Data ---
  static ThemeData get theme {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      textTheme: _textTheme,

      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: secondaryColor,
        onSecondary: Colors.white,
        error: errorColor,
        onError: Colors.white,
        background: backgroundColor,
        onBackground: textColor,
        surface: cardColor,
        onSurface: textColor,
        tertiary: accentColor,
      ),

      cardTheme: const CardThemeData(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: _textTheme.titleLarge,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: _textTheme.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: _textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black.withOpacity(0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        labelStyle: _textTheme.bodyMedium?.copyWith(color: subtextColor),
        floatingLabelStyle: _textTheme.bodyMedium?.copyWith(color: primaryColor),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        indicatorColor: primaryColor.withOpacity(0.15),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return _textTheme.labelSmall?.copyWith(color: primaryColor, fontWeight: FontWeight.bold);
          }
          return _textTheme.labelSmall?.copyWith(color: subtextColor);
        }),
        iconTheme: MaterialStateProperty.resolveWith((states) {
           if (states.contains(MaterialState.selected)) {
            return const IconThemeData(color: primaryColor, size: 28);
          }
          return const IconThemeData(color: subtextColor, size: 26);
        })
      )
    );
  }
}
