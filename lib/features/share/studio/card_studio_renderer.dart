import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../core/theme/mwb_typography.dart';
import '../scripture_image_composer.dart';
import 'card_design.dart';

/// A page plan with the geometry it was planned for (public for tests).
@immutable
class CardPagePlan {
  const CardPagePlan({required this.page, required this.bodyTop, required this.bodyBottom, required this.bodyHeight});

  final SharePagePlan page;

  /// The band the Scripture may occupy on this page.
  final double bodyTop;
  final double bodyBottom;

  /// Measured height of the Scripture at the planned size.
  final double bodyHeight;

  bool get fits => bodyHeight <= bodyBottom - bodyTop + 0.5;
}

/// Renders Card Studio designs to PNG on the device (no network).
///
/// The Classic template is the existing quick-share composition, unchanged.
/// Every other template uses its own composition but the same completeness
/// algorithm ([ScriptureImageComposer.paginate]): the whole selection is
/// always shown, across several images if necessary, and is never cut.
/// The preview shows these exact PNG bytes, so it matches the export.
class CardStudioRenderer {
  const CardStudioRenderer();

  // ---------------------------------------------------------------------------
  // Geometry
  // ---------------------------------------------------------------------------

  static bool _isShort(ShareScripture s) => s.verses.length == 1 && !s.numbered && s.length <= 240;

  static bool _numbered(ShareScripture s, CardDesign d) => d.showVerseNumbers && (s.verses.length > 1 || s.numbered);

  static TextAlign alignFor(ShareScripture s, CardDesign d) => switch (d.alignment) {
    CardAlignment.left => TextAlign.left,
    CardAlignment.centre => TextAlign.center,
    CardAlignment.auto => _isShort(s) ? d.template.shortAlign : TextAlign.left,
  };

  static double _marginX(CardDesign d) {
    final w = d.format.width.toDouble();
    final base = switch (d.template) {
      CardTemplate.ivoryGold => 0.12,
      CardTemplate.navy || CardTemplate.devotional => 0.105,
      _ => 0.09,
    } * math.min(w, 1080);
    // Keep wide lines readable in landscape.
    return math.max(base, (w - 1480) / 2);
  }

  static double _textWidth(CardDesign d) => d.format.width - 2 * _marginX(d);

  /// Story formats keep clear of the status/Story chrome of WhatsApp,
  /// Instagram and Facebook (top and bottom safe zones).
  static double _topPad(CardDesign d) => switch (d.format) {
    ShareFormat.story => 230,
    ShareFormat.landscape => 84,
    _ => d.template == CardTemplate.ivoryGold ? 120 : 104,
  };

  static double _bottomPad(CardDesign d) => switch (d.format) {
    ShareFormat.story => 250,
    ShareFormat.landscape => 70,
    _ => d.template == CardTemplate.ivoryGold ? 112 : 92,
  };

  static double _decoTop(CardDesign d) {
    if (!d.decorations) return 0;
    return switch (d.template) {
      CardTemplate.ivoryGold || CardTemplate.navy || CardTemplate.devotional => 54,
      CardTemplate.editorial || CardTemplate.minimal => 40,
      // Leafy branches across the top corners.
      CardTemplate.nature => d.format == ShareFormat.story ? 0 : 40,
      _ => 0,
    };
  }

  static List<double> _ladder(ShareScripture s, CardDesign d) {
    final f = d.format;
    final short = _isShort(s);
    final List<double> base = short
        ? switch (f) {
            ShareFormat.story => [78, 72, 66, 60, 56, 52, 48],
            ShareFormat.square => [60, 56, 52, 48, 44, 40],
            ShareFormat.landscape => [64, 58, 52, 48, 44, 40],
            ShareFormat.portrait => [66, 62, 58, 54, 50, 46, 42],
          }
        : switch (f) {
            ShareFormat.story => [58, 54, 50, 47, 44, 42],
            ShareFormat.square => [48, 45, 42, 40, 38],
            ShareFormat.landscape => [48, 45, 42, 40, 38],
            ShareFormat.portrait => [52, 49, 46, 44, 42, 40],
          };
    final boost = d.template == CardTemplate.vibrant && short ? 1.08 : 1.0;
    final k = d.textScale * d.effectiveFont.sizeFactor * boost;
    return [for (final v in base) (v * k).roundToDouble()];
  }

  static TextStyle _scriptureStyle(CardDesign d, double size) {
    final font = d.effectiveFont;
    final shadow = d.template == CardTemplate.cinematic || d.template == CardTemplate.vibrant;
    return TextStyle(
      fontFamily: font.family,
      fontWeight: font.weight,
      fontSize: size,
      height: font.lineHeight,
      color: d.effectiveInk,
      shadows: shadow
          ? const [Shadow(color: Color(0x66000000), blurRadius: 14, offset: Offset(0, 2))]
          : null,
    );
  }

  static TextSpan _span(ShareScripture s, CardDesign d, List<ShareVerse> verses, double size) {
    final base = _scriptureStyle(d, size);
    final numbered = _numbered(s, d);
    final quote = _isShort(s);
    final children = <InlineSpan>[];
    if (quote) children.add(TextSpan(text: '“', style: base));
    for (var i = 0; i < verses.length; i++) {
      final v = verses[i];
      if (numbered && v.number > 0) {
        children.add(
          TextSpan(
            text: '${v.number}',
            style: base.copyWith(
              fontFamily: MwbFonts.ui,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.5,
              color: _readableAccent(d),
              fontFeatures: const [ui.FontFeature.superscripts()],
              shadows: const [],
            ),
          ),
        );
        // A thin space at text size separates the number from the verse.
        children.add(TextSpan(text: ' ', style: base));
      }
      for (final sp in v.spans) {
        children.add(
          TextSpan(
            text: sp.text,
            style: sp.isName ? base.copyWith(color: _nameInk(d), fontWeight: FontWeight.w700) : base,
          ),
        );
      }
      if (i < verses.length - 1) children.add(TextSpan(text: ' ', style: base));
    }
    if (quote) children.add(TextSpan(text: '”', style: base));
    return TextSpan(children: children);
  }

  /// The accent if it is readable on the backdrop, otherwise the ink.
  static Color _readableAccent(CardDesign d) {
    final p = d.palette;
    return contrastRatio(p.accent, p.textBackdrop) >= 3.0 ? p.accent : d.effectiveInk;
  }

  static Color _nameInk(CardDesign d) => _readableAccent(d);

  static TextPainter _tp(InlineSpan span, double width, {TextAlign align = TextAlign.left, int? maxLines}) =>
      TextPainter(
        text: span,
        textAlign: align,
        textDirection: TextDirection.ltr,
        maxLines: maxLines,
        ellipsis: maxLines == null ? null : '…',
      )..layout(maxWidth: width);

  // ---------------------------------------------------------------------------
  // Text elements around the Scripture
  // ---------------------------------------------------------------------------

  static TextPainter? _title(ShareScripture s, CardDesign d, TextAlign align) {
    final title = s.title?.trim();
    if (title == null || title.isEmpty) return null;
    final p = d.palette;
    final base = TextStyle(
      fontFamily: d.template == CardTemplate.minimal || d.template == CardTemplate.vibrant ? MwbFonts.ui : MwbFonts.display,
      fontSize: d.format == ShareFormat.story ? 54 : 46,
      height: 1.18,
      fontWeight: d.template == CardTemplate.vibrant ? FontWeight.w700 : FontWeight.w600,
      color: d.effectiveInk,
    );
    final n = s.titleName;
    final i = n == null || n.isEmpty ? -1 : title.indexOf(n);
    final span = i < 0
        ? TextSpan(text: title, style: base)
        : TextSpan(
            children: [
              TextSpan(text: title.substring(0, i), style: base),
              TextSpan(text: n, style: base.copyWith(color: contrastRatio(p.accent, p.textBackdrop) >= 3 ? p.accent : base.color)),
              TextSpan(text: title.substring(i + n!.length), style: base),
            ],
          );
    return _tp(span, _textWidth(d), align: align, maxLines: 3);
  }

  static TextPainter? _message(CardDesign d, TextAlign align) {
    final m = d.trimmedMessage;
    if (m == null) return null;
    return _tp(
      TextSpan(
        text: m,
        style: TextStyle(
          fontFamily: MwbFonts.scripture,
          fontStyle: FontStyle.italic,
          fontSize: d.format == ShareFormat.story ? 34 : 30,
          height: 1.4,
          color: d.effectiveInk.withValues(alpha: 0.86),
        ),
      ),
      _textWidth(d),
      align: align,
      maxLines: 4,
    );
  }

  static TextPainter _reference(ShareScripture s, CardDesign d, TextAlign align) {
    final p = d.palette;
    final accent = _readableAccent(d);
    final style = switch (d.template) {
      CardTemplate.editorial when d.effectivePlacement == ReferencePlacement.above => TextStyle(
        fontFamily: MwbFonts.display,
        fontSize: d.format == ShareFormat.story ? 64 : 56,
        fontWeight: FontWeight.w600,
        height: 1.1,
        color: d.effectiveInk,
      ),
      CardTemplate.minimal => TextStyle(
        fontFamily: MwbFonts.ui,
        fontSize: 30,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: d.effectiveInk,
      ),
      CardTemplate.vibrant => TextStyle(
        fontFamily: MwbFonts.ui,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: _pillInk(p),
      ),
      _ => TextStyle(
        fontFamily: MwbFonts.scripture,
        fontStyle: FontStyle.italic,
        fontSize: 36,
        fontWeight: FontWeight.w600,
        color: accent,
        shadows: d.template == CardTemplate.cinematic
            ? const [Shadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 1))]
            : null,
      ),
    };
    final dash = d.template == CardTemplate.editorial || d.template == CardTemplate.minimal || d.template == CardTemplate.vibrant
        ? ''
        : '— ';
    final width = d.template == CardTemplate.vibrant ? _textWidth(d) - 64 : _textWidth(d);
    return _tp(TextSpan(text: '$dash${s.reference}', style: style), width, align: align, maxLines: 2);
  }

  /// Vibrant's reference "sticker": a light pill with dark text on dark-ink
  /// cards' opposite (white type → white pill, dark type → dark pill).
  static Color _pillInk(CardColorway p) =>
      p.ink.computeLuminance() > 0.5 ? const Color(0xFF16121F) : const Color(0xFFFFFFFF);

  static Color _pillFill(CardColorway p) =>
      p.ink.computeLuminance() > 0.5 ? const Color(0xFFFFFFFF) : const Color(0xFF0D1F14);

  static TextPainter _translation(ShareScripture s, CardDesign d, TextAlign align, {required bool continued}) =>
      _tp(
        TextSpan(
          text: continued ? '${s.translation}  ·  continued' : s.translation,
          style: TextStyle(
            fontFamily: MwbFonts.ui,
            fontSize: 22,
            letterSpacing: 3,
            fontWeight: FontWeight.w600,
            color: d.palette.muted,
            shadows: _smallShadow(d),
          ),
        ),
        _textWidth(d),
        align: align,
      );

  static TextPainter? _sender(CardDesign d, TextAlign align) {
    final s = d.trimmedSender;
    if (s == null) return null;
    return _tp(
      TextSpan(
        text: 'Shared by $s',
        style: TextStyle(
          fontFamily: MwbFonts.ui,
          fontSize: 24,
          fontWeight: FontWeight.w500,
          color: d.palette.muted,
          shadows: _smallShadow(d),
        ),
      ),
      _textWidth(d),
      align: align,
      maxLines: 1,
    );
  }

  /// Small type over photographic or vivid backgrounds gets a soft shadow.
  static List<Shadow>? _smallShadow(CardDesign d) =>
      d.template == CardTemplate.cinematic || d.template == CardTemplate.vibrant
      ? const [Shadow(color: Color(0x80000000), blurRadius: 8, offset: Offset(0, 1))]
      : null;

  /// Space for the approved personal reception (0 without one): a label and
  /// the full wording, never shortened.
  static double _receptionHeight(ShareScripture s, CardDesign d, TextAlign align) {
    if (s.reception == null || s.reception!.trim().isEmpty) return 0;
    final (label, body) = _receptionPainters(s, d, align);
    return 24 + label.height + 6 + body.height;
  }

  static (TextPainter, TextPainter) _receptionPainters(ShareScripture s, CardDesign d, TextAlign align) {
    final label = _tp(
      TextSpan(
        text: 'PERSONAL RECEPTION',
        style: TextStyle(
          fontFamily: MwbFonts.ui,
          fontSize: 17,
          letterSpacing: 3.5,
          fontWeight: FontWeight.w600,
          color: _readableAccent(d),
          shadows: _smallShadow(d),
        ),
      ),
      _textWidth(d),
      align: align,
    );
    final text = s.reception!;
    final base = TextStyle(
      fontFamily: MwbFonts.ui,
      fontSize: d.format == ShareFormat.story ? 28 : 24,
      height: 1.45,
      color: d.effectiveInk.withValues(alpha: 0.82),
      shadows: _smallShadow(d),
    );
    final n = s.receptionName;
    final i = n == null || n.isEmpty ? -1 : text.indexOf(n);
    final body = _tp(
      i < 0
          ? TextSpan(text: text, style: base)
          : TextSpan(
              children: [
                TextSpan(text: text.substring(0, i), style: base),
                TextSpan(
                  text: n,
                  style: base.copyWith(color: _nameInk(d), fontWeight: FontWeight.w700),
                ),
                TextSpan(text: text.substring(i + n!.length), style: base),
              ],
            ),
      _textWidth(d),
      align: align,
    );
    return (label, body);
  }

  static TextPainter? _brand(CardDesign d) {
    if (!d.branding) return null;
    return _tp(
      TextSpan(
        text: 'MY WORD BIBLE',
        style: TextStyle(
          fontFamily: MwbFonts.ui,
          fontSize: 18,
          letterSpacing: 5,
          fontWeight: FontWeight.w600,
          color: d.palette.muted.withValues(alpha: 0.8),
          shadows: _smallShadow(d),
        ),
      ),
      d.format.width.toDouble(),
      align: TextAlign.center,
    );
  }

  /// Footer and header bands for page [index] of [count].
  static ({double headerBottom, double footerTop, double footerHeight}) _bands(
    ShareScripture s,
    CardDesign d,
    TextAlign align, {
    required bool first,
    required bool continued,
  }) {
    final h = d.format.height.toDouble();
    var top = _topPad(d) + _decoTop(d);
    if (first) {
      final t = _title(s, d, align);
      if (t != null) top += t.height + 30;
      final m = _message(d, align);
      if (m != null) top += m.height + 34;
    }
    final ref = _reference(s, d, align);
    final refBox = ref.height + (d.template == CardTemplate.vibrant ? 28 : 0);
    if (d.effectivePlacement == ReferencePlacement.above) top += refBox + 34;

    var foot = _bottomPad(d);
    final brand = _brand(d);
    if (brand != null) foot += brand.height + 22;
    final sender = _sender(d, align);
    if (sender != null) foot += sender.height + 10;
    foot += _translation(s, d, align, continued: continued).height;
    if (d.effectivePlacement == ReferencePlacement.below) foot += refBox + 12;
    foot += _receptionHeight(s, d, align);
    foot += 44; // breathing room above the footer
    return (headerBottom: top, footerTop: h - foot, footerHeight: foot);
  }

  // ---------------------------------------------------------------------------
  // Planning
  // ---------------------------------------------------------------------------

  /// Splits [s] into pages for [d]. Never drops or shortens text.
  static List<CardPagePlan> plan(ShareScripture s, CardDesign d, {ShareStyle? classicStyle}) {
    if (d.template.isClassic) {
      final style = classicStyle ?? _classicFallback(d);
      return [
        for (final p in ScriptureImageComposer.plan(s, d.format, style))
          CardPagePlan(page: p, bodyTop: 0, bodyBottom: d.format.height.toDouble(), bodyHeight: 0),
      ];
    }
    final align = alignFor(s, d);
    final width = _textWidth(d);
    final first = _bands(s, d, align, first: true, continued: true);
    final other = _bands(s, d, align, first: false, continued: true);
    double heightOf(List<ShareVerse> vs, double size) => _tp(_span(s, d, vs, size), width, align: align).height;
    final pages = ScriptureImageComposer.paginate(
      verses: s.verses,
      ladder: _ladder(s, d),
      firstLimit: first.footerTop - first.headerBottom,
      otherLimit: other.footerTop - other.headerBottom,
      heightOf: heightOf,
    );
    return [
      for (var i = 0; i < pages.length; i++)
        CardPagePlan(
          page: pages[i],
          bodyTop: i == 0 ? first.headerBottom : other.headerBottom,
          bodyBottom: i == 0 ? first.footerTop : other.footerTop,
          bodyHeight: heightOf(pages[i].verses, pages[i].fontSize),
        ),
    ];
  }

  static ShareStyle _classicFallback(CardDesign d) {
    final p = d.palette;
    return ShareStyle(
      background: p.background.first,
      panel: p.panel ?? p.background.first,
      ink: p.ink,
      muted: p.muted,
      accent: p.accent,
      accentStrong: p.accent,
      name: p.accent,
    );
  }

  // ---------------------------------------------------------------------------
  // Drawing
  // ---------------------------------------------------------------------------

  Future<List<ShareImagePage>> compose(ShareScripture s, CardDesign d, {required ShareStyle classicStyle}) async {
    if (d.template.isClassic) return const ScriptureImageComposer().compose(s, d.format, classicStyle);
    final plans = plan(s, d);
    final out = <ShareImagePage>[];
    for (var i = 0; i < plans.length; i++) {
      out.add(await _draw(s, d, plans[i], i, plans.length));
    }
    return out;
  }

  Future<ShareImagePage> _draw(ShareScripture s, CardDesign d, CardPagePlan plan, int index, int count) async {
    final f = d.format;
    final w = f.width.toDouble(), h = f.height.toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
    final align = alignFor(s, d);
    final mx = _marginX(d);
    final tw = _textWidth(d);
    final p = d.palette;

    _paintBackground(canvas, Size(w, h), d);

    double xFor(TextPainter tp) => switch (align) {
      TextAlign.center => (w - tp.width) / 2,
      _ => mx,
    };

    // Page indicator.
    if (count > 1) {
      final pi = _tp(
        TextSpan(
          text: '${index + 1} / $count',
          style: TextStyle(fontFamily: MwbFonts.ui, fontSize: 22, fontWeight: FontWeight.w600, color: p.muted),
        ),
        200,
      );
      pi.paint(canvas, Offset(w - mx - pi.width, _topPad(d) - 46));
    }

    // Header.
    var y = _topPad(d);
    _paintTopOrnament(canvas, Size(w, h), d, y, align, mx);
    y += _decoTop(d);
    if (index == 0) {
      final title = _title(s, d, align);
      if (title != null) {
        title.paint(canvas, Offset(xFor(title), y));
        y += title.height + 30;
      }
      final msg = _message(d, align);
      if (msg != null) {
        msg.paint(canvas, Offset(xFor(msg), y));
        y += msg.height + 34;
      }
    }
    final ref = _reference(s, d, align);
    if (d.effectivePlacement == ReferencePlacement.above) {
      y = _paintReference(canvas, ref, d, align, mx, w, y);
      if (d.template == CardTemplate.editorial && d.decorations) {
        canvas.drawRect(Rect.fromLTWH(mx, y + 6, 90, 5), Paint()..color = _readableAccent(d));
      }
      y += 34;
    }

    // Scripture, centred vertically in its band.
    final body = _tp(_span(s, d, plan.page.verses, plan.page.fontSize), tw, align: align);
    final top = plan.bodyTop + math.max(0, (plan.bodyBottom - plan.bodyTop - body.height) / 2);
    if (d.template == CardTemplate.cinematic) _paintScrim(canvas, Size(w, h), top, body.height);
    body.paint(canvas, Offset(mx, top));

    // Footer, top-down from the footer band.
    final continued = count > 1 && index < count - 1;
    var fy = plan.bodyBottom + 44;
    if (d.effectivePlacement == ReferencePlacement.below) {
      fy = _paintReference(canvas, ref, d, align, mx, w, fy) + 12;
    }
    final tr = _translation(s, d, align, continued: continued);
    tr.paint(canvas, Offset(xFor(tr), fy));
    fy += tr.height;
    final sender = _sender(d, align);
    if (sender != null) {
      fy += 10;
      sender.paint(canvas, Offset(xFor(sender), fy));
      fy += sender.height;
    }
    if (index == count - 1 && _receptionHeight(s, d, align) > 0) {
      final (label, body) = _receptionPainters(s, d, align);
      fy += 24;
      label.paint(canvas, Offset(xFor(label), fy));
      fy += label.height + 6;
      body.paint(canvas, Offset(xFor(body), fy));
    }
    final brand = _brand(d);
    if (brand != null) {
      final by = h - _bottomPad(d) - brand.height;
      brand.paint(canvas, Offset(align == TextAlign.center ? (w - brand.width) / 2 : mx, by));
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(f.width, f.height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return ShareImagePage(png: bytes!.buffer.asUint8List(), width: f.width, height: f.height, index: index, count: count);
  }

  /// Draws the reference (as a pill for Vibrant) and returns its bottom.
  static double _paintReference(Canvas canvas, TextPainter ref, CardDesign d, TextAlign align, double mx, double w, double y) {
    if (d.template == CardTemplate.vibrant) {
      final pw = ref.width + 64, ph = ref.height + 28;
      final x = align == TextAlign.center ? (w - pw) / 2 : mx;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, pw, ph), Radius.circular(ph / 2)),
        Paint()..color = _pillFill(d.palette),
      );
      ref.paint(canvas, Offset(x + 32, y + 14));
      return y + ph;
    }
    final x = align == TextAlign.center ? (w - ref.width) / 2 : mx;
    ref.paint(canvas, Offset(x, y));
    return y + ref.height;
  }

  // ---------------------------------------------------------------------------
  // Backgrounds and ornaments (all procedural, deterministic)
  // ---------------------------------------------------------------------------

  static void _paintBackground(Canvas canvas, Size size, CardDesign d) {
    final p = d.palette;
    final rect = Offset.zero & size;
    final stops = p.background.length == 1 ? [p.background.first, p.background.first] : p.background;
    final diagonal = d.template == CardTemplate.vibrant || d.template == CardTemplate.devotional;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          diagonal ? Offset.zero : Offset(size.width / 2, 0),
          diagonal ? Offset(size.width, size.height) : Offset(size.width / 2, size.height),
          stops,
          stops.length == 3 ? const [0.0, 0.55, 1.0] : null,
        ),
    );
    switch (d.template) {
      case CardTemplate.classic:
        break;
      case CardTemplate.ivoryGold:
        _ivory(canvas, size, d);
      case CardTemplate.navy:
        _navy(canvas, size, d);
      case CardTemplate.editorial:
        if (d.decorations) {
          final mx = _marginX(d);
          final line = Paint()
            ..color = p.ink.withValues(alpha: 0.85)
            ..strokeWidth = 2;
          canvas.drawLine(Offset(mx, 64), Offset(size.width - mx, 64), line);
          canvas.drawLine(Offset(mx, 72), Offset(size.width - mx, 72), line..strokeWidth = 1);
          canvas.drawLine(
            Offset(mx, size.height - 52),
            Offset(size.width - mx, size.height - 52),
            Paint()
              ..color = p.ink.withValues(alpha: 0.5)
              ..strokeWidth = 1,
          );
        }
      case CardTemplate.minimal:
        break;
      case CardTemplate.cinematic:
        _cinematic(canvas, size, d);
      case CardTemplate.devotional:
        _devotional(canvas, size, d);
      case CardTemplate.nature:
        _nature(canvas, size, d);
      case CardTemplate.vibrant:
        _vibrant(canvas, size, d);
    }
  }

  static void _paintTopOrnament(Canvas canvas, Size size, CardDesign d, double y, TextAlign align, double mx) {
    if (!d.decorations) return;
    final p = d.palette;
    final cx = align == TextAlign.center ? size.width / 2 : mx + 14;
    final accent = Paint()
      ..color = p.accent
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    switch (d.template) {
      case CardTemplate.ivoryGold || CardTemplate.navy:
        final c = Offset(size.width / 2, y + 14);
        _diamond(canvas, c, 9, Paint()..color = p.accent);
        canvas.drawLine(c.translate(-90, 0), c.translate(-22, 0), accent..strokeWidth = 1.6);
        canvas.drawLine(c.translate(22, 0), c.translate(90, 0), accent);
      case CardTemplate.devotional:
        // A small cross of light.
        final c = Offset(cx, y + 18);
        final light = Paint()
          ..color = p.accent.withValues(alpha: 0.8)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(c.translate(0, -16), c.translate(0, 22), light);
        canvas.drawLine(c.translate(-11, -4), c.translate(11, -4), light);
      case CardTemplate.editorial:
        final label = _tp(
          TextSpan(
            text: 'SCRIPTURE',
            style: TextStyle(fontFamily: MwbFonts.ui, fontSize: 20, letterSpacing: 5, fontWeight: FontWeight.w700, color: _readableAccent(d)),
          ),
          400,
        );
        label.paint(canvas, Offset(align == TextAlign.center ? (size.width - label.width) / 2 : mx, y));
      case CardTemplate.minimal:
        canvas.drawCircle(Offset(cx - 6, y + 10), 7, Paint()..color = p.accent);
      default:
        break;
    }
  }

  static void _diamond(Canvas canvas, Offset c, double r, Paint paint) {
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - r)
        ..lineTo(c.dx + r, c.dy)
        ..lineTo(c.dx, c.dy + r)
        ..lineTo(c.dx - r, c.dy)
        ..close(),
      paint,
    );
  }

  static void _ivory(Canvas canvas, Size size, CardDesign d) {
    final p = d.palette;
    final inset = 40.0;
    final panel = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - 2 * inset, size.height - 2 * inset),
      const Radius.circular(30),
    );
    canvas.drawRRect(panel, Paint()..color = p.panel ?? p.background.first);
    if (!d.decorations) return;
    canvas.drawRRect(
      panel.deflate(18),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = p.accent.withValues(alpha: 0.75),
    );
    canvas.drawRRect(
      panel.deflate(28),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = p.accent.withValues(alpha: 0.55),
    );
    // Corner flourishes.
    final r = panel.deflate(28).outerRect;
    final gold = Paint()..color = p.accent;
    for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
      final dx = c.dx < size.width / 2 ? 1.0 : -1.0;
      final dy = c.dy < size.height / 2 ? 1.0 : -1.0;
      _diamond(canvas, c.translate(dx * 26, dy * 26), 7, gold);
      final stroke = Paint()
        ..color = p.accent.withValues(alpha: 0.7)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke;
      canvas.drawArc(Rect.fromCircle(center: c.translate(dx * 26, dy * 26), radius: 20), 0, math.pi * 2, false, stroke);
    }
  }

  static void _navy(Canvas canvas, Size size, CardDesign d) {
    final p = d.palette;
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.08),
      size.width * 0.95,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width / 2, size.height * 0.08),
          size.width * 0.95,
          [(p.glow ?? p.accent).withValues(alpha: 0.38), (p.glow ?? p.accent).withValues(alpha: 0)],
        ),
    );
    if (!d.decorations) return;
    final rnd = math.Random(7);
    for (var i = 0; i < 70; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height * 0.45),
        rnd.nextDouble() * 1.8 + 0.4,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: rnd.nextDouble() * 0.35 + 0.05),
      );
    }
    final line = Paint()
      ..color = p.accent.withValues(alpha: 0.6)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTWH(34, 34, size.width - 68, size.height - 68), line);
    canvas.drawRect(Rect.fromLTWH(44, 44, size.width - 88, size.height - 88), line..strokeWidth = 0.8);
  }

  static void _cinematic(Canvas canvas, Size size, CardDesign d) {
    final p = d.palette;
    final w = size.width, h = size.height;
    final sun = Offset(w * 0.5, h * 0.74);
    canvas.drawCircle(
      sun,
      w * 0.9,
      Paint()
        ..shader = ui.Gradient.radial(sun, w * 0.9, [
          (p.glow ?? p.accent).withValues(alpha: 0.75),
          (p.glow ?? p.accent).withValues(alpha: 0.0),
        ]),
    );
    if (d.decorations) {
      // Light rays.
      for (var i = 0; i < 9; i++) {
        final a = -math.pi / 2 + (i - 4) * 0.2;
        final path = Path()
          ..moveTo(sun.dx, sun.dy)
          ..lineTo(sun.dx + math.cos(a - 0.04) * h, sun.dy + math.sin(a - 0.04) * h)
          ..lineTo(sun.dx + math.cos(a + 0.04) * h, sun.dy + math.sin(a + 0.04) * h)
          ..close();
        canvas.drawPath(path, Paint()..color = (p.glow ?? p.accent).withValues(alpha: 0.06));
      }
      // Stars in the upper sky.
      final rnd = math.Random(11);
      for (var i = 0; i < 90; i++) {
        canvas.drawCircle(
          Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * 0.4),
          rnd.nextDouble() * 1.6 + 0.3,
          Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: rnd.nextDouble() * 0.4),
        );
      }
    }
    // Hills (three layers).
    final base = p.background.first;
    for (var layer = 0; layer < 3; layer++) {
      final top = h * (0.74 + layer * 0.06);
      final amp = h * (0.035 - layer * 0.007);
      final path = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += 12) {
        path.lineTo(x, top + math.sin(x / w * math.pi * (2.2 + layer) + layer) * amp);
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(path, Paint()..color = Color.lerp(base, const Color(0xFF000000), 0.25 + layer * 0.2)!);
    }
    if (d.decorations) {
      final rnd = math.Random(3);
      final grain = Paint();
      for (var i = 0; i < 2600; i++) {
        grain.color = (rnd.nextBool() ? const Color(0xFFFFFFFF) : const Color(0xFF000000)).withValues(alpha: 0.05);
        canvas.drawRect(Rect.fromLTWH(rnd.nextDouble() * w, rnd.nextDouble() * h, 2, 2), grain);
      }
    }
    // Vignette.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(Offset(w / 2, h / 2), math.max(w, h) * 0.75, [
          const Color(0x00000000),
          const Color(0x73000000),
        ], const [0.55, 1.0]),
    );
  }

  /// Soft darkening behind the text so white type stays readable.
  static void _paintScrim(Canvas canvas, Size size, double top, double height) {
    final r = Rect.fromLTWH(0, top - 120, size.width, height + 240);
    canvas.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, const [
          Color(0x00000000),
          Color(0x59000000),
          Color(0x59000000),
          Color(0x00000000),
        ], const [0.0, 0.25, 0.75, 1.0]),
    );
  }

  static void _devotional(Canvas canvas, Size size, CardDesign d) {
    final p = d.palette;
    final glow = p.glow ?? const Color(0xFFFFFFFF);
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.08),
      size.width * 0.8,
      Paint()
        ..shader = ui.Gradient.radial(Offset(size.width * 0.15, size.height * 0.08), size.width * 0.8, [
          glow.withValues(alpha: 0.75),
          glow.withValues(alpha: 0),
        ]),
    );
    if (!d.decorations) return;
    final rnd = math.Random(5);
    for (var i = 0; i < 9; i++) {
      final c = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      canvas.drawCircle(
        c,
        rnd.nextDouble() * 90 + 40,
        Paint()
          ..color = glow.withValues(alpha: rnd.nextDouble() * 0.22 + 0.1)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
      );
    }
  }

  static void _leaf(Canvas canvas, Offset base, double len, double angle, Paint paint) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(len * 0.5, -len * 0.32, len, 0)
      ..quadraticBezierTo(len * 0.5, len * 0.32, 0, 0)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawLine(
      Offset.zero,
      Offset(len * 0.92, 0),
      Paint()
        ..color = const Color(0x33FFFFFF)
        ..strokeWidth = 1.5,
    );
    canvas.restore();
  }

  static void _nature(Canvas canvas, Size size, CardDesign d) {
    final p = d.palette;
    final w = size.width, h = size.height;
    if (!d.decorations) return;
    // Rolling hills.
    for (var layer = 0; layer < 2; layer++) {
      final top = h * (0.86 + layer * 0.05);
      final path = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += 12) {
        path.lineTo(x, top + math.sin(x / w * math.pi * (1.6 + layer * 0.9) + layer * 1.3) * h * 0.022);
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(path, Paint()..color = p.accent.withValues(alpha: 0.16 + layer * 0.12));
    }
    // Branches with leaves in two corners.
    void branch(Offset start, double dir) {
      final stem = Paint()
        ..color = p.accent.withValues(alpha: 0.55)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      // Kept inside the top band (above the Scripture; see _decoTop).
      final end = start.translate(dir * 220, 70);
      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..quadraticBezierTo(start.dx + dir * 140, start.dy + 6, end.dx, end.dy),
        stem,
      );
      final leaf = Paint()..color = p.accent.withValues(alpha: 0.5);
      for (var i = 1; i <= 5; i++) {
        final t = i / 6;
        final pt = Offset(start.dx + dir * 220 * t, start.dy + 70 * t * t + 6 * (1 - t));
        _leaf(canvas, pt, 50 - i * 3, dir > 0 ? -0.9 + i * 0.05 : math.pi + 0.9 - i * 0.05, leaf);
        _leaf(canvas, pt, 44 - i * 3, dir > 0 ? 0.9 + i * 0.1 : math.pi - 0.9 - i * 0.1, leaf);
      }
    }

    branch(const Offset(-10, 34), 1);
    branch(Offset(w + 10, 34), -1);
  }

  static void _vibrant(Canvas canvas, Size size, CardDesign d) {
    final p = d.palette;
    final w = size.width, h = size.height;
    if (!d.decorations) return;
    final blobs = [
      (Offset(w * 0.9, h * 0.12), w * 0.55, p.glow ?? p.accent),
      (Offset(w * 0.95, h * 0.9), w * 0.5, p.background.first),
      (Offset(w * 0.2, h * 0.25), w * 0.3, p.background.last),
    ];
    for (final (c, r, color) in blobs) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = color.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120),
      );
    }
    final rnd = math.Random(9);
    final grain = Paint();
    for (var i = 0; i < 2200; i++) {
      grain.color = const Color(0xFFFFFFFF).withValues(alpha: 0.06);
      canvas.drawRect(Rect.fromLTWH(rnd.nextDouble() * w, rnd.nextDouble() * h, 2, 2), grain);
    }
  }
}
