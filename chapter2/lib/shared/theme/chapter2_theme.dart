import 'package:flutter/material.dart';
import 'app_colors.dart';

export 'app_colors.dart';
export 'app_text_styles.dart';

class Chapter2Theme {
  // Legacy mappings for backward compatibility
  static const Color background = AppColors.screenBackground;
  static const Color surface = AppColors.cardSurfacePure;
  static const Color surfaceElevated = AppColors.cardSurface;
  static const Color border = AppColors.cardBorder;

  static const Color primaryCyan = AppColors.brandPrimary;
  static const Color neonTeal = AppColors.allow;
  static const Color warningAmber = AppColors.escalate;
  static const Color alertRed = AppColors.block;
  static const Color textMuted = AppColors.textMuted;

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.screenBackground,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.cardSurfacePure,
        primary: AppColors.brandPrimary,
        secondary: AppColors.allow,
        error: AppColors.block,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.screenBackground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardSurfacePure,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
      ),
    );
  }
}
