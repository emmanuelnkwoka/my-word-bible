import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/mwb_tokens.dart';

/// A tappable card with a clear selected state (border, tint, check mark).
class MwbSelectionCard extends StatelessWidget {
  const MwbSelectionCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.multiSelect = false,
    this.enabled = true,
    this.trailingNote,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final bool multiSelect;
  final bool enabled;
  final String? trailingNote;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final fg = enabled ? c.textPrimary : c.disabled;
    return Semantics(
      selected: selected,
      enabled: enabled,
      button: true,
      inMutuallyExclusiveGroup: !multiSelect,
      child: AnimatedContainer(
        duration: MwbMotion.fast,
        curve: MwbMotion.curve,
        decoration: BoxDecoration(
          color: selected ? c.selected : c.surfaceElevated,
          borderRadius: MwbRadius.mdAll,
          border: Border.all(color: selected ? c.primary : c.border, width: selected ? 1.4 : 1),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: MwbRadius.mdAll,
            onTap: enabled && onTap != null
                ? () {
                    HapticFeedback.selectionClick();
                    onTap!();
                  }
                : null,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: MwbSpace.md, vertical: dense ? MwbSpace.sm : MwbSpace.md),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 22, color: selected ? c.primary : (enabled ? c.textSecondary : c.disabled)),
                    const SizedBox(width: MwbSpace.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: t.cardTitle.copyWith(fontSize: 15, color: fg)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!, style: t.caption.copyWith(color: enabled ? c.textSecondary : c.disabled)),
                        ],
                      ],
                    ),
                  ),
                  if (trailingNote != null) ...[
                    const SizedBox(width: MwbSpace.xs),
                    Text(trailingNote!, style: t.caption),
                  ],
                  const SizedBox(width: MwbSpace.xs),
                  _Indicator(selected: selected, multi: multiSelect, enabled: enabled),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.selected, required this.multi, required this.enabled});
  final bool selected;
  final bool multi;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final radius = multi ? BorderRadius.circular(6) : BorderRadius.circular(12);
    return AnimatedContainer(
      duration: MwbMotion.fast,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: selected ? c.primaryStrong : Colors.transparent,
        borderRadius: radius,
        border: Border.all(color: selected ? c.primaryStrong : (enabled ? c.border : c.divider), width: 1.5),
      ),
      child: selected ? Icon(Icons.check_rounded, size: 15, color: c.onPrimary) : null,
    );
  }
}

/// Single-choice list built from [MwbSelectionCard]s.
class MwbRadioGroup<T> extends StatelessWidget {
  const MwbRadioGroup({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.labelOf,
    this.subtitleOf,
    this.iconOf,
    this.enabledOf,
    this.spacing = MwbSpace.xs,
    this.dense = false,
  });

  final List<T> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;
  final String? Function(T)? subtitleOf;
  final IconData? Function(T)? iconOf;
  final bool Function(T)? enabledOf;
  final double spacing;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          MwbSelectionCard(
            title: labelOf(options[i]),
            subtitle: subtitleOf?.call(options[i]),
            icon: iconOf?.call(options[i]),
            selected: options[i] == value,
            enabled: enabledOf?.call(options[i]) ?? true,
            dense: dense,
            onTap: () => onChanged(options[i]),
          ),
        ],
      ],
    );
  }
}

/// Labelled checkbox row with a full-width touch target.
class MwbCheckbox extends StatelessWidget {
  const MwbCheckbox({super.key, required this.value, required this.onChanged, required this.label, this.description});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    return Semantics(
      checked: value,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: MwbRadius.smAll,
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: MwbSpace.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: _Indicator(selected: value, multi: true, enabled: true),
              ),
              const SizedBox(width: MwbSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: t.label.copyWith(fontSize: 14, color: c.textPrimary)),
                    if (description != null) Text(description!, style: t.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Settings-style switch row.
class MwbSwitchTile extends StatelessWidget {
  const MwbSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    return MergeSemantics(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        minVerticalPadding: MwbSpace.sm,
        leading: icon == null ? null : Icon(icon, color: c.textSecondary),
        title: Text(title, style: t.label.copyWith(fontSize: 15)),
        subtitle: subtitle == null ? null : Text(subtitle!, style: t.caption),
        trailing: Switch(value: value, onChanged: onChanged),
        onTap: onChanged == null ? null : () => onChanged!(!value),
      ),
    );
  }
}

/// Compact pill chip used for topics and filters.
class MwbChip extends StatelessWidget {
  const MwbChip({super.key, required this.label, this.selected = false, this.onTap, this.icon, this.count});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: AnimatedContainer(
        duration: MwbMotion.fast,
        decoration: BoxDecoration(
          color: selected ? c.textPrimary : c.surfaceElevated,
          borderRadius: BorderRadius.circular(MwbRadius.pill),
          border: Border.all(color: selected ? c.textPrimary : c.border),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(MwbRadius.pill),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: selected ? c.background : c.primary),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: t.label.copyWith(
                        color: selected ? c.background : c.textPrimary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '$count',
                        style: t.caption.copyWith(
                          color: selected ? c.background.withValues(alpha: 0.75) : c.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrolling row of chips that bleeds to the screen edge.
class MwbChipRow extends StatelessWidget {
  const MwbChipRow({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: MwbSpace.xs), children[i]],
        ],
      ),
    );
  }
}
