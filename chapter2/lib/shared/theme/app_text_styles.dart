import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized typography generator for Chapter 2.
/// Modeled after the ai_mentor design system for consistent scaling and clean styling.
class AppTextStyles {
  AppTextStyles._();

  // Font weights
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extraBold = FontWeight.w800;

  // Base generator
  static TextStyle _build(
    BuildContext context, {
    required double fontSize,
    FontWeight fontWeight = regular,
    Color? color,
    double height = 1.3,
    double? letterSpacing,
    String? fontFamily,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? AppColors.textPrimary,
      height: height,
      letterSpacing: letterSpacing,
      fontFamily: fontFamily,
    );
  }

  // Display sizes (for hero balance: $12,480.42)
  static TextStyle display(
    BuildContext context, {
    Color? color,
    FontWeight fontWeight = bold,
  }) =>
      _build(
        context,
        fontSize: 36,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: -1.0,
      );

  static TextStyle displaySub(
    BuildContext context, {
    Color? color,
    FontWeight fontWeight = semiBold,
  }) =>
      _build(
        context,
        fontSize: 22,
        fontWeight: fontWeight,
        color: color ?? AppColors.textSecondary,
        letterSpacing: -0.5,
      );

  // XXL: Section Headlines & Large Numbers
  static TextStyle xxl(
    BuildContext context, {
    Color? color,
    FontWeight fontWeight = bold,
  }) =>
      _build(context, fontSize: 26, fontWeight: fontWeight, color: color);

  // XL: Titles & Card Headers
  static TextStyle xl(
    BuildContext context, {
    Color? color,
    FontWeight fontWeight = bold,
  }) =>
      _build(context, fontSize: 20, fontWeight: fontWeight, color: color);

  // LG: Subheadings & Action Buttons
  static TextStyle lg(
    BuildContext context, {
    Color? color,
    FontWeight fontWeight = semiBold,
  }) =>
      _build(context, fontSize: 17, fontWeight: fontWeight, color: color);

  // MD: Standard Body Title
  static TextStyle md(
    BuildContext context, {
    Color? color,
    FontWeight fontWeight = medium,
  }) =>
      _build(context, fontSize: 15, fontWeight: fontWeight, color: color);

  // Base: Standard Content
  static TextStyle base(
    BuildContext context, {
    Color? color,
    FontWeight fontWeight = regular,
  }) =>
      _build(context, fontSize: 14, fontWeight: fontWeight, color: color);

  // SM: Captions & Descriptions
  static TextStyle sm(
    BuildContext context, {
    Color? color,
    FontWeight fontWeight = medium,
  }) =>
      _build(context, fontSize: 13, fontWeight: fontWeight, color: color ?? AppColors.textSecondary);

  // XS: Badges, Pills & Micro-labels
  static TextStyle xs(
    BuildContext context, {
    Color? color,
    FontWeight fontWeight = bold,
  }) =>
      _build(
        context,
        fontSize: 11,
        fontWeight: fontWeight,
        color: color ?? AppColors.textMuted,
        letterSpacing: 0.4,
      );

  // Monospace (for EVM addresses, Safe/Guard contracts, transaction hashes)
  static TextStyle mono(
    BuildContext context, {
    double fontSize = 12,
    Color? color,
    FontWeight fontWeight = regular,
  }) =>
      TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? AppColors.textSecondary,
        fontFamily: 'Courier',
        letterSpacing: -0.2,
      );
}
