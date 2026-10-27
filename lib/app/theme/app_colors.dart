import 'package:flutter/material.dart';

/// Brand palette. Use these (or the theme's `ColorScheme`, which is built from
/// them) instead of ad-hoc colours.
abstract final class AppColors {
  static const primary = Color(0xFFFD2B7B);
  static const secondary = Color(0xFFFF7158);
  static const darkGray = Color(0xFF424242);
  static const white = Color(0xFFFFFFFF);

  static const primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Warm neutrals for screen backgrounds, option pills and hairlines. The
  /// theme maps them onto `ColorScheme` roles so dark mode can swap them.
  static const background = Color(0xFFF3F1F0);
  static const surfaceMuted = Color(0xFFE6E3E1);
  static const outline = Color(0xFFD9D5D3);
  static const textMuted = Color(0xFF6F6B69);
  static const disabled = Color(0xFFD6D2D0);

  static const backgroundDark = Color(0xFF121111);
  static const surfaceDark = Color(0xFF1E1C1C);
  static const surfaceMutedDark = Color(0xFF2C2A2A);
  static const outlineDark = Color(0xFF3D3A3A);

  /// Bottom fade behind text on full-bleed photos.
  static const photoScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.45, 1],
    colors: [Color(0x00000000), Color(0xE6000000)],
  );

  static const like = primary;
  static const pass = darkGray;
  static const superLike = secondary;

  /// Fallbacks for members without a photo, picked deterministically.
  static const avatarGradients = [
    [primary, secondary],
    [secondary, primary],
    [darkGray, primary],
    [primary, darkGray],
  ];
}
