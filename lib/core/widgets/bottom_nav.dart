import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/mwb_tokens.dart';

class MwbNavItem {
  const MwbNavItem({required this.label, required this.icon, required this.activeIcon});
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Floating five-destination navigation (reference design): a rounded pill
/// that floats above the page with a soft shadow. The active destination
/// sits on a warm champagne capsule in the brand colour; inactive ones are
/// ink-coloured. It occupies its own space in the layout (it is not drawn
/// over the page), so it never hides content, and it respects the system
/// gesture or three-button navigation inset.
class MwbBottomNav extends StatelessWidget {
  const MwbBottomNav({super.key, required this.items, required this.currentIndex, required this.onSelected});

  final List<MwbNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const double barHeight = 66;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 6, 14, bottomInset > 0 ? bottomInset + 4 : 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surfaceElevated.withValues(alpha: c.isDark ? 0.96 : 0.98),
                borderRadius: BorderRadius.circular(barHeight / 2),
                border: Border.all(color: c.isDark ? c.border : const Color(0x1F28170D), width: 1),
                boxShadow: c.softShadow,
              ),
              child: SizedBox(
                height: barHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                  child: Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _NavButton(
                            item: items[i],
                            active: i == currentIndex,
                            onTap: () {
                              if (i != currentIndex) HapticFeedback.selectionClick();
                              onSelected(i);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.active, required this.onTap});

  final MwbNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final color = active ? c.primaryStrong : c.textPrimary.withValues(alpha: c.isDark ? 0.86 : 0.88);
    return Semantics(
      button: true,
      selected: active,
      label: '${item.label} tab',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: MwbMotion.medium,
          curve: MwbMotion.curve,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: active ? c.selected.withValues(alpha: c.isDark ? 0.9 : 1) : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: MwbMotion.fast,
                transitionBuilder: (child, a) => ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(a), child: child),
                child: Icon(active ? item.activeIcon : item.icon, key: ValueKey(active), color: color, size: 24),
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: t.caption.copyWith(
                  color: color,
                  fontSize: 11.5,
                  height: 1.1,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
