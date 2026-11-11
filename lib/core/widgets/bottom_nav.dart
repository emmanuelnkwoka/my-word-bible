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

/// Refined five-destination bottom navigation: hairline top border, quiet
/// inactive icons and a fine brand marker above the active destination.
class MwbBottomNav extends StatelessWidget {
  const MwbBottomNav({super.key, required this.items, required this.currentIndex, required this.onSelected});

  final List<MwbNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
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
                    activeColor: c.primary,
                    inactiveColor: c.textSecondary,
                    textStyle: t.caption,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.active,
    required this.onTap,
    required this.activeColor,
    required this.inactiveColor,
    required this.textStyle,
  });

  final MwbNavItem item;
  final bool active;
  final VoidCallback onTap;
  final Color activeColor;
  final Color inactiveColor;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : inactiveColor;
    return Semantics(
      button: true,
      selected: active,
      label: '${item.label} tab',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        highlightShape: BoxShape.rectangle,
        containedInkWell: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: MwbMotion.medium,
              curve: MwbMotion.curve,
              width: active ? 18 : 0,
              height: 2,
              margin: const EdgeInsets.only(bottom: 7),
              decoration: BoxDecoration(color: activeColor, borderRadius: BorderRadius.circular(1)),
            ),
            AnimatedSwitcher(
              duration: MwbMotion.fast,
              child: Icon(active ? item.activeIcon : item.icon, key: ValueKey(active), color: color, size: 23),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: textStyle.copyWith(
                color: color,
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
