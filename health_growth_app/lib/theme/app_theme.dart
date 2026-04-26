import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta de cores do Health Growth App (criança/adolescente)
class AppColors {
  static const primary = Color(0xFF7C3AED); // Roxo vibrante
  static const primaryDark = Color(0xFF5B21B6);
  static const secondary = Color(0xFF06B6D4); // Ciano
  static const accent = Color(0xFFF59E0B); // Âmbar/dourado
  static const success = Color(0xFF10B981); // Verde
  static const danger = Color(0xFFEF4444); // Vermelho
  static const surface = Color(0xFF1E293B); // Superfície escura
  static const background = Color(0xFF0F172A); // Fundo escuro
}

class AppTheme {
  static TextTheme _buildTextTheme(TextTheme base) {
    return GoogleFonts.nunitoTextTheme(base).copyWith(
      displayLarge: GoogleFonts.nunito(
        fontSize: 32,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700),
      titleMedium: GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.nunito(fontSize: 16),
      bodyMedium: GoogleFonts.nunito(fontSize: 14),
      labelLarge: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700),
    );
  }

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        secondary: AppColors.secondary,
        tertiary: AppColors.accent,
        brightness: Brightness.light,
      ),
      textTheme: _buildTextTheme(base.textTheme),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.success;
          return null;
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        secondary: AppColors.secondary,
        tertiary: AppColors.accent,
        brightness: Brightness.dark,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: _buildTextTheme(base.textTheme),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: Color(0xFFA78BFA),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.success;
          return null;
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF334155),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
