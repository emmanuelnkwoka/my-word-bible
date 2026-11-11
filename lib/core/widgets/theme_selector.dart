import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/mwb_palette.dart';
import '../theme/mwb_themes.dart';
import '../theme/mwb_tokens.dart';

/// Grid of the seven MWB themes. Each tile renders a miniature of the
/// theme's own palette (background, surface, text and brand detail).
class MwbThemeSelector extends StatelessWidget {
  const MwbThemeSelector({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.brightness,
    this.applied,
  });

  final MwbThemeId selected;
  final MwbThemeId? applied;
  final ValueChanged<MwbThemeId> onSelected;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 4 : (constraints.maxWidth >= 300 ? 2 : 1);
        const spacing = MwbSpace.sm;
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final def in MwbThemes.all)
              SizedBox(
                width: width,
                child: ThemeSwatchTile(
                  definition: def,
                  brightness: brightness,
                  selected: def.id == selected,
                  applied: def.id == applied,
                  onTap: () => onSelected(def.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ThemeSwatchTile extends StatelessWidget {
  const ThemeSwatchTile({
    super.key,
    required this.definition,
    required this.brightness,
    required this.selected,
    required this.onTap,
    this.applied = false,
  });

  final MwbThemeDefinition definition;
  final Brightness brightness;
  final bool selected;
  final bool applied;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final p = definition.paletteFor(brightness);
    return Semantics(
      button: true,
      selected: selected,
      label: '${definition.id.label} theme${applied ? ', currently applied' : ''}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: MwbMotion.fast,
        decoration: BoxDecoration(
          color: c.surfaceElevated,
          borderRadius: MwbRadius.mdAll,
          border: Border.all(color: selected ? c.primary : c.border, width: selected ? 1.6 : 1),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: MwbRadius.mdAll,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(MwbSpace.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Miniature(palette: p),
                  const SizedBox(height: MwbSpace.xs),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            definition.id.label,
                            style: t.label.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (applied) Icon(Icons.check_circle_rounded, size: 16, color: c.primary),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Miniature extends StatelessWidget {
  const _Miniature({required this.palette});
  final MwbPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return AspectRatio(
      aspectRatio: 1.7,
      child: Container(
        decoration: BoxDecoration(
          color: p.background,
          borderRadius: MwbRadius.smAll,
          border: Border.all(color: p.border),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 22, height: 2, color: p.primary),
            const SizedBox(height: 5),
            Container(
              width: 52,
              height: 5,
              decoration: BoxDecoration(color: p.textPrimary, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 4),
            Container(
              width: 38,
              height: 3,
              decoration: BoxDecoration(color: p.textSecondary, borderRadius: BorderRadius.circular(2)),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: p.surfaceElevated,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: p.border),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  width: 26,
                  height: 16,
                  decoration: BoxDecoration(color: p.primaryStrong, borderRadius: BorderRadius.circular(4)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
