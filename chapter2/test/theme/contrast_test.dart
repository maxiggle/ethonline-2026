import 'dart:math' as math;

import 'package:chapter2/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.x relative luminance of a single sRGB channel (0-255).
double _linearizeChannel(int channel) {
  final c = channel / 255.0;
  if (c <= 0.03928) return c / 12.92;
  return math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double relativeLuminance(Color color) {
  final r = _linearizeChannel((color.r * 255.0).round());
  final g = _linearizeChannel((color.g * 255.0).round());
  final b = _linearizeChannel((color.b * 255.0).round());
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// WCAG contrast ratio between two colors, always >= 1.0.
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  const surfaces = {
    'background': AppColors.background,
    'surface': AppColors.surface,
    'surfaceRaised': AppColors.surfaceRaised,
  };

  group('AppColors contrast (WCAG)', () {
    for (final entry in surfaces.entries) {
      test('textPrimary on ${entry.key} is >= 7:1', () {
        expect(contrastRatio(AppColors.textPrimary, entry.value), greaterThanOrEqualTo(7.0));
      });

      test('textSecondary on ${entry.key} is >= 7:1', () {
        expect(contrastRatio(AppColors.textSecondary, entry.value), greaterThanOrEqualTo(7.0));
      });

      test('textMuted on ${entry.key} is >= 4.5:1', () {
        expect(contrastRatio(AppColors.textMuted, entry.value), greaterThanOrEqualTo(4.5));
      });

      test('allow verdict color on ${entry.key} is >= 4.5:1', () {
        expect(contrastRatio(AppColors.allow, entry.value), greaterThanOrEqualTo(4.5));
      });

      test('escalate verdict color on ${entry.key} is >= 4.5:1', () {
        expect(contrastRatio(AppColors.escalate, entry.value), greaterThanOrEqualTo(4.5));
      });

      test('block verdict color on ${entry.key} is >= 4.5:1', () {
        expect(contrastRatio(AppColors.block, entry.value), greaterThanOrEqualTo(4.5));
      });
    }

    test('onPrimary on primary is >= 4.5:1', () {
      expect(contrastRatio(AppColors.onPrimary, AppColors.primary), greaterThanOrEqualTo(4.5));
    });
  });
}
