import 'package:flutter/material.dart';

/// Large, tight, heavy headings over quiet body text.
abstract final class AppTypography {
  static TextTheme apply(TextTheme base) => base.copyWith(
    headlineLarge: base.headlineLarge?.copyWith(
      fontSize: 32,
      height: 1.15,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
    ),
    headlineMedium: base.headlineMedium?.copyWith(
      fontSize: 28,
      height: 1.15,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    ),
    headlineSmall: base.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.2,
    ),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    bodyLarge: base.bodyLarge?.copyWith(height: 1.35),
    bodyMedium: base.bodyMedium?.copyWith(height: 1.35),
  );
}
