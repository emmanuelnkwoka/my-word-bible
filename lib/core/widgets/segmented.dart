import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/mwb_tokens.dart';

/// Quiet segmented control (e.g. System / Light / Dark, text sizes).
class MwbSegmentedControl<T> extends StatelessWidget {
  const MwbSegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.labelOf,
    this.iconOf,
  });

  final List<T> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;
  final IconData Function(T)? iconOf;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: MwbRadius.mdAll,
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: o == value,
                inMutuallyExclusiveGroup: true,
                label: labelOf(o),
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (o != value) HapticFeedback.selectionClick();
                    onChanged(o);
                  },
                  child: AnimatedContainer(
                    duration: MwbMotion.fast,
                    curve: MwbMotion.curve,
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    decoration: BoxDecoration(
                      color: o == value ? c.surfaceElevated : Colors.transparent,
                      borderRadius: BorderRadius.circular(MwbRadius.sm),
                      border: Border.all(color: o == value ? c.border : Colors.transparent),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (iconOf != null) ...[
                          Icon(iconOf!(o), size: 16, color: o == value ? c.primary : c.textSecondary),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            labelOf(o),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.label.copyWith(
                              color: o == value ? c.textPrimary : c.textSecondary,
                              fontWeight: o == value ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
