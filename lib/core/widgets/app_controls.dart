import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// App icon drawn in the brand gradient.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32, this.color});

  final double size;

  /// Solid colour instead of the gradient, e.g. white on a gradient screen.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      Icons.cloud_rounded,
      size: size,
      color: color ?? AppColors.white,
    );
    if (color != null) return icon;
    return ShaderMask(
      shaderCallback: AppColors.primaryGradient.createShader,
      blendMode: BlendMode.srcIn,
      child: icon,
    );
  }
}

/// Bold, left-aligned page title used at the top of each tab.
class LargeTitle extends StatelessWidget {
  const LargeTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg - 4,
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.sm,
    ),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              text,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Thin rounded progress bar for multi-step flows.
class StepProgressBar extends StatelessWidget {
  const StepProgressBar({super.key, required this.value, this.width = 140});

  final double value;
  final double width;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Progress',
    value: '${(value * 100).round()}%',
    child: SizedBox(
      width: width,
      height: 4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outline,
          borderRadius: BorderRadius.circular(2),
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0, 1)),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: v,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Floating round button, e.g. back on full-screen forms or close on sheets.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 44,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  /// Dark gray with a white glyph instead of a white chip.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = filled
        ? AppColors.darkGray
        : scheme.surfaceContainerLowest;
    final foreground = filled ? AppColors.white : scheme.onSurface;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        elevation: filled ? 0 : 3,
        shadowColor: const Color(0x29000000),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Icon(icon, color: foreground, size: size * 0.5),
          ),
        ),
      ),
    );
  }
}

/// Circular "continue" button that sits above the keyboard on single-field
/// steps.
class CheckButton extends StatelessWidget {
  const CheckButton({
    super.key,
    required this.onPressed,
    this.isBusy = false,
    this.tooltip = 'Continue',
  });

  final VoidCallback? onPressed;
  final bool isBusy;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isBusy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      excludeSemantics: true,
      child: Material(
        color: enabled ? AppColors.darkGray : AppColors.disabled,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onPressed : null,
          child: SizedBox.square(
            dimension: 56,
            child: Center(
              child: isBusy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(
                      Icons.check_rounded,
                      color: AppColors.white,
                      size: 30,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width outlined pill for single- or multi-choice answers.
class PillOption extends StatelessWidget {
  const PillOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = StadiumBorder(
      side: BorderSide(
        color: selected ? AppColors.primary : scheme.outline,
        width: selected ? 2 : 1.5,
      ),
    );
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: Colors.transparent,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg - 4,
              vertical: AppSpacing.md - 2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// White rounded block of rows separated by hairlines, as on a settings page.
class GroupedSection extends StatelessWidget {
  const GroupedSection({
    super.key,
    this.title,
    this.footer,
    required this.children,
  });

  final String? title;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md + 4,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Text(title!, style: theme.textTheme.titleMedium),
          ),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Divider(
                    indent: AppSpacing.md,
                    endIndent: AppSpacing.md,
                  ),
                children[i],
              ],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md + 4,
              AppSpacing.sm,
              AppSpacing.md + 4,
              0,
            ),
            child: Text(
              footer!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// Muted rounded chip with an optional leading icon, for profile facts.
class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: scheme.onSurface),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
