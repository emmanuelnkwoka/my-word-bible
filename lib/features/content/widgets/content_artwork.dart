import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_palette.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/content.dart';

IconData iconForType(ContentType t) => switch (t) {
  ContentType.audio => Icons.graphic_eq_rounded,
  ContentType.video => Icons.play_arrow_rounded,
  ContentType.article => Icons.article_outlined,
  ContentType.scriptureReference => Icons.menu_book_outlined,
};

/// Tonal backgrounds derived from the active palette so artwork always
/// belongs to the current theme.
Color artworkTone(MwbPalette p, int tone) {
  final bases = [p.primary, p.secondary, p.accent, p.primaryStrong, p.textSecondary, p.primary, p.secondary];
  final base = bases[tone % bases.length];
  final amount = p.isDark ? 0.22 + (tone % 3) * 0.05 : 0.14 + (tone % 3) * 0.05;
  return Color.lerp(p.isDark ? p.surfaceElevated : p.surface, base, amount)!;
}

/// Typographic, motif-based artwork used in place of thumbnails until
/// hosted imagery exists. Quiet, theme-aware and free of stock imagery.
class ContentArtworkView extends StatelessWidget {
  const ContentArtworkView({
    super.key,
    required this.item,
    this.aspectRatio = 16 / 10,
    this.showTypeBadge = true,
    this.showDuration = true,
    this.radius = MwbRadius.md,
    this.iconSize = 22,
    this.showIcon = true,
  });

  final bool showIcon;

  final ContentItem item;
  final double aspectRatio;
  final bool showTypeBadge;
  final bool showDuration;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final p = context.mwb.colors;
    final t = context.mwb.text;
    final bg = artworkTone(p, item.artwork.tone);
    final duration = item.duration;
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: DecoratedBox(
            decoration: BoxDecoration(color: bg),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _MotifPainter(item.artwork.motif, p.primary.withValues(alpha: p.isDark ? 0.28 : 0.22)),
                ),
                if (showIcon)
                  Center(
                    child: Container(
                      width: iconSize * 2.1,
                      height: iconSize * 2.1,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.surfaceElevated.withValues(alpha: 0.92),
                        border: Border.all(color: p.primary.withValues(alpha: 0.35)),
                      ),
                      child: Icon(iconForType(item.type), size: iconSize, color: p.primaryStrong),
                    ),
                  ),
                if (showTypeBadge)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: _Badge(text: item.type.label.toUpperCase(), palette: p, style: t.caption),
                  ),
                if (showDuration && duration != null && item.type != ContentType.article)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: _Badge(text: formatDuration(duration), palette: p, style: t.caption),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.palette, required this.style});
  final String text;
  final MwbPalette palette;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: palette.surfaceElevated.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: style.copyWith(
          fontSize: 10,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w600,
          color: palette.textPrimary,
        ),
      ),
    );
  }
}

class _MotifPainter extends CustomPainter {
  _MotifPainter(this.motif, this.color);

  final ArtworkMotif motif;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final c = Offset(size.width / 2, size.height / 2);
    switch (motif) {
      case ArtworkMotif.arcs:
        for (var i = 1; i <= 6; i++) {
          canvas.drawCircle(c, size.shortestSide * 0.14 * i, paint);
        }
      case ArtworkMotif.rays:
        for (var i = 0; i < 24; i++) {
          final a = i * math.pi / 12;
          final r1 = size.shortestSide * 0.32;
          final r2 = size.longestSide;
          canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * r1, c + Offset(math.cos(a), math.sin(a)) * r2, paint);
        }
      case ArtworkMotif.lines:
        for (var y = 12.0; y < size.height; y += 9) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
      case ArtworkMotif.grid:
        const step = 18.0;
        for (var x = step; x < size.width; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        for (var y = step; y < size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
    }
  }

  @override
  bool shouldRepaint(_MotifPainter old) => old.motif != motif || old.color != color;
}
