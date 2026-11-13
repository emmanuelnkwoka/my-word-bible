import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../data/models/scripture_reference.dart';
import '../application/personalisation_providers.dart';
import '../application/scripture_presentation.dart';
import '../domain/presentation_layer_resolver.dart';
import '../domain/rendered_verse.dart';

/// Scripture as presented: canonical text, or an approved rendering with
/// the reader's name set in gold. Verses are joined with a space; verse
/// numbers are shown for multi-verse passages.
class PresentedScriptureText extends StatelessWidget {
  const PresentedScriptureText({
    super.key,
    required this.presentation,
    required this.style,
    this.textAlign = TextAlign.center,
    this.quotes = true,
    this.maxLines,
  });

  final ScripturePresentation presentation;
  final TextStyle style;
  final TextAlign textAlign;
  final bool quotes;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final verses = presentation.verses.where((v) => !v.source.isOmitted).toList();
    final numbered = verses.length > 1;
    final spans = <InlineSpan>[];
    if (quotes) spans.add(TextSpan(text: '“', style: style));
    for (var i = 0; i < verses.length; i++) {
      final v = verses[i];
      if (numbered) {
        spans.add(
          TextSpan(
            text: '${v.source.number} ',
            style: style.copyWith(
              fontSize: (style.fontSize ?? 18) * 0.55,
              color: c.primary,
              fontWeight: FontWeight.w700,
              fontFamily: context.mwb.text.caption.fontFamily,
            ),
          ),
        );
      }
      for (final s in v.segments) {
        spans.add(
          TextSpan(
            text: s.text,
            style: s.kind == SegmentKind.personalisation
                ? style.copyWith(color: c.nameInk, fontWeight: FontWeight.w600)
                : style,
          ),
        );
      }
      if (i < verses.length - 1) spans.add(TextSpan(text: ' ', style: style));
    }
    if (quotes) spans.add(TextSpan(text: '”', style: style));
    return Text.rich(
      TextSpan(children: spans),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}

/// A title in which [name] (if present) is set in gold.
class NamedTitle extends StatelessWidget {
  const NamedTitle({super.key, required this.text, required this.style, this.name, this.textAlign = TextAlign.center});
  final String text;
  final String? name;
  final TextStyle style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final n = name;
    final i = n == null || n.isEmpty ? -1 : text.indexOf(n);
    if (i < 0) return Text(text, style: style, textAlign: textAlign);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, i), style: style),
          TextSpan(text: n, style: style.copyWith(color: context.mwb.colors.nameInk)),
          TextSpan(text: text.substring(i + n!.length), style: style),
        ],
      ),
      textAlign: textAlign,
    );
  }
}

/// Labels a rendering made from a proposal that is not approved. Shown only
/// in reviewer builds with the review preview switched on.
class PreviewBadge extends StatelessWidget {
  const PreviewBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    const ink = Color(0xFF9B2C22);
    return Semantics(
      label: 'Review preview. This personalised rendering is not approved.',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: ink.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(MwbRadius.pill),
          border: Border.all(color: ink.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.rate_review_outlined, size: 13, color: ink),
            const SizedBox(width: 5),
            Text(
              'Review preview · not yet approved',
              style: t.caption.copyWith(color: ink, fontWeight: FontWeight.w600, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// The MY WORD BIBLE medallion: a gold disc with a fine cross.
class MwbBrandMark extends StatelessWidget {
  const MwbBrandMark({super.key, this.size = 30});
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(c.accent, Colors.white, 0.12)!, c.primaryStrong],
        ),
        boxShadow: [BoxShadow(color: c.primaryStrong.withValues(alpha: 0.25), blurRadius: size * 0.5, offset: Offset(0, size * 0.12))],
      ),
      child: CustomPaint(painter: _CrossPainter()),
    );
  }
}

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = const Color(0xFFFFFBF2)
      ..strokeWidth = s.width * 0.075
      ..strokeCap = StrokeCap.round;
    final cx = s.width / 2, cy = s.height / 2, r = s.width / 2;
    canvas.drawLine(Offset(cx, cy - r * 0.5), Offset(cx, cy + r * 0.5), p);
    canvas.drawLine(Offset(cx - r * 0.3, cy - r * 0.18), Offset(cx + r * 0.3, cy - r * 0.18), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// An approved personal reception shown beneath the unchanged verse: clearly
/// set apart from Scripture (its own label, typeface and accent rule), with
/// the reader's name in gold. Used by every screen that shows receptions.
class EditorialReception extends StatelessWidget {
  const EditorialReception({
    super.key,
    required this.layer,
    this.fontSize = 15,
    this.textColor,
    this.accent,
    this.maxLines,
    this.showLabel = true,
  });

  final ResolvedEditorialLayer layer;
  final double fontSize;
  final Color? textColor;
  final Color? accent;
  final int? maxLines;
  final bool showLabel;

  static const label = 'Personal reception';

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final ink = textColor ?? c.textPrimary;
    final rule = accent ?? c.primary;
    final style = t.body.copyWith(fontSize: fontSize, height: 1.5, color: ink.withValues(alpha: 0.92));
    final name = layer.name;
    final i = name == null || name.isEmpty ? -1 : layer.text.indexOf(name);
    final body = i < 0
        ? TextSpan(text: layer.text, style: style)
        : TextSpan(
            children: [
              TextSpan(text: layer.text.substring(0, i), style: style),
              TextSpan(
                text: name,
                style: style.copyWith(color: c.nameInk, fontWeight: FontWeight.w600),
              ),
              TextSpan(text: layer.text.substring(i + name!.length), style: style),
            ],
          );
    return Semantics(
      container: true,
      label: '$label. ${layer.text}',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(MwbSpace.sm, MwbSpace.xs, MwbSpace.sm, MwbSpace.xs),
        decoration: BoxDecoration(
          color: rule.withValues(alpha: 0.06),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(MwbRadius.md),
            bottomRight: Radius.circular(MwbRadius.md),
          ),
          border: Border(left: BorderSide(color: rule.withValues(alpha: 0.7), width: 2.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showLabel) ...[
              Row(
                children: [
                  Icon(Icons.favorite_outline_rounded, size: fontSize * 0.8, color: rule),
                  const SizedBox(width: 6),
                  Text(
                    label.toUpperCase(),
                    style: t.overline.copyWith(color: rule, fontSize: fontSize * 0.68, letterSpacing: 1.4),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Text.rich(body, maxLines: maxLines, overflow: maxLines == null ? null : TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// The approved title (above [child]) and reception (below it) for a
/// reference in the active MWB edition, from the shared layer engine.
/// Shows [child] alone when there are none (or the reader is in KJV/WEB).
class EditorialLayersAround extends ConsumerWidget {
  const EditorialLayersAround({super.key, required this.reference, required this.child, this.receptionFontSize = 14});

  final ScriptureReference reference;
  final Widget child;
  final double receptionFontSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final layers = ref.watch(activeEditorialLayersProvider(reference)).value?.values ?? const [];
    final title = layers.map((l) => l.title).nonNulls.firstOrNull;
    final reception = layers.map((l) => l.reception).nonNulls.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          NamedTitle(
            text: title.text,
            name: title.name,
            textAlign: TextAlign.left,
            style: t.cardTitle.copyWith(fontSize: 16, color: c.primaryStrong),
          ),
          const SizedBox(height: 6),
        ],
        child,
        if (reception != null) ...[
          const SizedBox(height: MwbSpace.sm),
          EditorialReception(layer: reception, fontSize: receptionFontSize),
        ],
      ],
    );
  }
}
