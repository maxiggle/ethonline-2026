import 'package:flutter/material.dart';

/// Centralized color palette for Chapter 2.
/// Matches the visual reference layout and follows the ai_mentor design system pattern.
class AppColors {
  AppColors._();

  // Screen background (deep dark bezel framing)
  static const Color screenBackground = Color(0xFF0D0F12);
  static const Color screenBackgroundElevated = Color(0xFF14171C);

  // Card surfaces (sculpted dual-card layout from visual reference)
  static const Color cardSurface = Color(0xFFF4F5F7);
  static const Color cardSurfacePure = Color(0xFFFFFFFF);
  static const Color cardSurfaceMuted = Color(0xFFEAECF0);
  static const Color cardBorder = Color(0xFFE4E7EC);

  // Floating middle action pill bar
  static const Color actionPillBackground = Color(0xFF1E2024);
  static const Color actionPillBorder = Color(0xFF2E3238);
  static const Color actionPillForeground = Color(0xFFFFFFFF);
  static const Color actionPillIconBackground = Color(0xFF2C3036);

  // Typography tokens (on light cards)
  static const Color textPrimary = Color(0xFF0A0D12);
  static const Color textSecondary = Color(0xFF414651);
  static const Color textMuted = Color(0xFF717680);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textLightMuted = Color(0xFF94A3B8);

  // Tri-Verdict Semantic States
  // 1. ALLOW (Calm, positive, autonomous execution)
  static const Color allow = Color(0xFF12B76A);
  static const Color allowBackground = Color(0xFFECFDF3);
  static const Color allowBorder = Color(0xFFA6F4C5);
  static const Color allowText = Color(0xFF027A48);

  // 2. ESCALATE (High-risk, human Face ID review required)
  static const Color escalate = Color(0xFFF59E0B);
  static const Color escalateBackground = Color(0xFFFEF0C7);
  static const Color escalateBorder = Color(0xFFFEDF89);
  static const Color escalateText = Color(0xFFB54708);

  // 3. BLOCK (Adversarial interception, definitively halted)
  static const Color block = Color(0xFFF04438);
  static const Color blockBackground = Color(0xFFFEE4E2);
  static const Color blockBorder = Color(0xFFFECDCA);
  static const Color blockText = Color(0xFFB42318);

  // Brand and Networks
  static const Color brandPrimary = Color(0xFF6366F1);
  static const Color brandPrimarySubtle = Color(0xFFEEF2FF);
  static const Color networkBase = Color(0xFF0052FF);
  static const Color ledgerOrange = Color(0xFFFF5A00);
}
