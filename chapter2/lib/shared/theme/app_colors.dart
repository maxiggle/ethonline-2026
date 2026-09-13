import 'package:flutter/material.dart';

/// Single accessible dark palette for Chapter 2. Every text token here is
/// verified against [background], [surface] and [surfaceRaised] by
/// `test/theme/contrast_test.dart`.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0B0D10);
  static const Color surface = Color(0xFF15181D);
  static const Color surfaceRaised = Color(0xFF1D2127);
  static const Color border = Color(0xFF2A2F37);

  static const Color textPrimary = Color(0xFFF2F4F7);
  static const Color textSecondary = Color(0xFFB4BCC8);
  static const Color textMuted = Color(0xFF8A94A3);

  static const Color primary = Color(0xFF7C83FF);
  static const Color onPrimary = Color(0xFF0B0D10);

  static const Color allow = Color(0xFF32D583);
  static const Color escalate = Color(0xFFFDB022);
  static const Color block = Color(0xFFF97066);

  static const Color ledgerOrange = Color(0xFFFF7A2E);

  // Verdict badge fills/borders: decorative low-alpha tints of the verdict
  // color, not subject to the text contrast rule.
  static Color get allowBackground => allow.withValues(alpha: 0.16);
  static Color get allowBorder => allow.withValues(alpha: 0.4);
  static const Color allowText = allow;

  static Color get escalateBackground => escalate.withValues(alpha: 0.16);
  static Color get escalateBorder => escalate.withValues(alpha: 0.4);
  static const Color escalateText = escalate;

  static Color get blockBackground => block.withValues(alpha: 0.16);
  static Color get blockBorder => block.withValues(alpha: 0.4);
  static const Color blockText = block;
}
