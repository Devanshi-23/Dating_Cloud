import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final seeded = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    final onSurface = isLight ? AppColors.darkGray : AppColors.white;
    final scheme = seeded.copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.white,
      secondary: AppColors.secondary,
      onSecondary: AppColors.white,
      surface: isLight ? AppColors.background : AppColors.backgroundDark,
      onSurface: onSurface,
      onSurfaceVariant: isLight
          ? AppColors.textMuted
          : AppColors.white.withValues(alpha: 0.7),
      surfaceContainerLowest: isLight ? AppColors.white : AppColors.surfaceDark,
      surfaceContainerHighest: isLight
          ? AppColors.surfaceMuted
          : AppColors.surfaceMutedDark,
      outline: isLight ? AppColors.outline : AppColors.outlineDark,
      outlineVariant: isLight ? AppColors.outline : AppColors.outlineDark,
      inverseSurface: AppColors.darkGray,
      onInverseSurface: AppColors.white,
    );
    // Main call-to-action: dark gray pill on light, white pill on dark.
    final action = isLight ? AppColors.darkGray : AppColors.white;
    final onAction = isLight ? AppColors.white : AppColors.darkGray;
    final disabledFill = isLight ? AppColors.disabled : AppColors.outlineDark;
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    const pill = StadiumBorder();
    const buttonText = TextStyle(fontSize: 17, fontWeight: FontWeight.w700);
    bool selected(Set<WidgetState> s) => s.contains(WidgetState.selected);

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: AppTypography.apply(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: action,
          foregroundColor: onAction,
          disabledBackgroundColor: disabledFill,
          disabledForegroundColor: scheme.onSurfaceVariant.withValues(
            alpha: 0.6,
          ),
          minimumSize: const Size.fromHeight(56),
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: pill,
          foregroundColor: onSurface,
          side: BorderSide(color: scheme.outline, width: 1.5),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: onSurface,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
          fontWeight: FontWeight.w400,
        ),
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: pill,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        labelStyle: TextStyle(
          color: onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        color: WidgetStateProperty.resolveWith(
          (s) => selected(s)
              ? AppColors.primary.withValues(alpha: 0.10)
              : scheme.surfaceContainerHighest,
        ),
        side: WidgetStateBorderSide.resolveWith(
          (s) => selected(s)
              ? const BorderSide(color: AppColors.primary, width: 1.5)
              : const BorderSide(color: Colors.transparent, width: 1.5),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        fillColor: WidgetStateProperty.resolveWith(
          (s) => selected(s) ? AppColors.primary : null,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.white),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(AppColors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => selected(s) ? AppColors.primary : scheme.outline,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: scheme.outline,
        thumbColor: AppColors.white,
        overlayColor: AppColors.primary.withValues(alpha: 0.12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: scheme.outline,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: onSurface,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkGray,
        contentTextStyle: const TextStyle(color: AppColors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
      ),
    );
  }
}
