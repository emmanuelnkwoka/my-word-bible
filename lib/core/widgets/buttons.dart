import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/mwb_tokens.dart';

/// Filled brand button. Uses the deeper brand tone for legible text.
class MwbPrimaryButton extends StatelessWidget {
  const MwbPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final enabled = onPressed != null && !loading;
    final button = FilledButton(
      onPressed: enabled ? onPressed : null,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(64, 54)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: MwbSpace.xl)),
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: MwbRadius.mdAll)),
        elevation: const WidgetStatePropertyAll(0),
        textStyle: WidgetStatePropertyAll(t.button),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? c.disabled.withValues(alpha: 0.45) : c.primaryStrong,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? c.textSecondary : c.onPrimary,
        ),
        overlayColor: WidgetStatePropertyAll(c.onPrimary.withValues(alpha: 0.08)),
      ),
      child: AnimatedSwitcher(
        duration: MwbMotion.fast,
        child: loading
            ? SizedBox(
                key: const ValueKey('loading'),
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.onPrimary),
              )
            : Row(
                key: const ValueKey('label'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
                  if (icon != null) ...[const SizedBox(width: MwbSpace.xs), Icon(icon, size: 18)],
                ],
              ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Outlined secondary button.
class MwbSecondaryButton extends StatelessWidget {
  const MwbSecondaryButton({super.key, required this.label, required this.onPressed, this.icon, this.expand = true});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final button = OutlinedButton(
      onPressed: onPressed,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(64, 54)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: MwbSpace.lg)),
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: MwbRadius.mdAll)),
        textStyle: WidgetStatePropertyAll(context.mwb.text.button),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? c.disabled : c.textPrimary,
        ),
        side: WidgetStateProperty.resolveWith(
          (s) => BorderSide(color: s.contains(WidgetState.disabled) ? c.divider : c.border, width: 1.2),
        ),
        backgroundColor: WidgetStatePropertyAll(c.surfaceElevated),
        overlayColor: WidgetStatePropertyAll(c.primary.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: MwbSpace.xs)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Low-emphasis text action in the brand colour.
class MwbTextButton extends StatelessWidget {
  const MwbTextButton({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: c.primary,
        minimumSize: const Size(kMwbMinTouchTarget, kMwbMinTouchTarget),
        textStyle: context.mwb.text.label.copyWith(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: MwbSpace.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (icon != null) ...[const SizedBox(width: 4), Icon(icon, size: 16)],
        ],
      ),
    );
  }
}

/// Circular icon action with an accessible label and 48dp target.
class MwbIconButton extends StatelessWidget {
  const MwbIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.selectedIcon,
    this.filled = false,
    this.size = 22,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      isSelected: selected,
      iconSize: size,
      constraints: const BoxConstraints(minWidth: kMwbMinTouchTarget, minHeight: kMwbMinTouchTarget),
      style: IconButton.styleFrom(
        foregroundColor: selected ? c.primary : c.textPrimary,
        backgroundColor: filled ? c.surfaceElevated : null,
        side: filled ? BorderSide(color: c.border) : null,
        disabledForegroundColor: c.disabled,
      ),
      icon: Icon(icon),
      selectedIcon: Icon(selectedIcon ?? icon),
    );
  }
}
