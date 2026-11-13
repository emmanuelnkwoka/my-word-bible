import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../core/theme/mwb_palette.dart';
import '../../core/theme/mwb_typography.dart';
import '../../data/models/scripture_reference.dart';

/// One run of shared text. [isName] marks the reader's name inside an
/// approved (or clearly labelled preview) personalised rendering.
@immutable
class ShareSpan {
  const ShareSpan(this.text, {this.isName = false});
  final String text;
  final bool isName;
}

/// A verse to share, exactly as displayed (canonical or approved rendering).
@immutable
class ShareVerse {
  const ShareVerse(this.number, this.spans);
  final int number;
  final List<ShareSpan> spans;

  String get text => spans.map((s) => s.text).join();
}

/// Everything that appears on shared Scripture images.
@immutable
class ShareScripture {
  const ShareScripture({
    required this.verses,
    required this.reference,
    required this.translation,
    this.title,
    this.titleName,
    this.numbered = false,
    this.preview = false,
    this.sources = const [],
    this.sourceVersionId,
    this.personalised = false,
    this.reception,
    this.receptionName,
  });

  /// Canonical references behind [verses] (empty when unknown). Direct
  /// sharing re-reads the canonical text from these, so a personalised
  /// rendering is never sent to another person as Scripture.
  final List<ScriptureReference> sources;

  /// The source translation id (e.g. "KJV"), never an MWB edition.
  final String? sourceVersionId;

  /// Whether [verses] contain the reader's approved personal rendering.
  final bool personalised;

  /// Approved personal reception(s) for the passage: editorial text drawn
  /// below the reference on the last image, labelled, never as Scripture.
  final String? reception;

  /// The reader's name inside [reception] (set in gold).
  final String? receptionName;

  /// Whether this Scripture resolves to canonical text for direct sharing
  /// and links (review previews never do).
  bool get isResolvable => sources.isNotEmpty && sourceVersionId != null && !preview;

  /// The reader's name inside [title], set in gold.
  final String? titleName;

  /// The complete selection. Every verse is drawn; nothing is truncated.
  final List<ShareVerse> verses;

  /// "Romans 15:13", "John 3:16–18" or "Psalm 23".
  final String reference;

  /// "KJV", or "KJV-MWB" when the text itself is personalised.
  final String translation;

  /// Mode A heading or Mode B personalised title (editorial, not Scripture).
  final String? title;

  /// Show verse numbers (ranges and chapters).
  final bool numbered;

  /// Rendered from an unapproved proposal: every page carries a visible
  /// "Review preview — not approved" line.
  final bool preview;

  int get length => verses.fold(0, (n, v) => n + v.text.length);
}

/// Image formats offered without forcing a template choice.
enum ShareFormat {
  portrait('Portrait', 1080, 1350),
  square('Square', 1080, 1080),
  story('Story', 1080, 1920),

  /// Wide format (link previews, presentations, desktop backgrounds).
  landscape('Landscape', 1920, 1080);

  const ShareFormat(this.label, this.width, this.height);
  final String label;
  final int width;
  final int height;

  /// Formats offered in the familiar quick-share sheet (unchanged).
  static const quick = [portrait, square, story];

  double get aspectRatio => width / height;
}

/// The composition chosen automatically from the content.
enum ShareLayout {
  /// Short single passage: large, centred, with quotation marks.
  centred,

  /// Longer single passage: left-aligned editorial text.
  editorial,

  /// Several verses: numbered passage, left-aligned, paginated as needed.
  passage,
}

/// Colours for an image, from the active theme.
@immutable
class ShareStyle {
  const ShareStyle({
    required this.background,
    required this.panel,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.accentStrong,
    required this.name,
  });

  factory ShareStyle.fromPalette(MwbPalette p) => ShareStyle(
    background: p.isDark ? const Color(0xFF110D09) : const Color(0xFFF3E9D8),
    panel: p.isDark ? const Color(0xFF1D1712) : const Color(0xFFFBF6EC),
    ink: p.textPrimary,
    muted: p.textSecondary,
    accent: p.primary,
    accentStrong: p.primaryStrong,
    name: p.nameInk,
  );

  final Color background;
  final Color panel;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color accentStrong;
  final Color name;
}

@immutable
class ShareImagePage {
  const ShareImagePage({
    required this.png,
    required this.width,
    required this.height,
    required this.index,
    required this.count,
  });
  final Uint8List png;
  final int width;
  final int height;
  final int index;
  final int count;
}

/// A page's content before drawing (used by tests and by [compose]).
@immutable
class SharePagePlan {
  const SharePagePlan(this.verses, this.fontSize);

  /// Verses (or the continuing part of a verse) on this page.
  final List<ShareVerse> verses;
  final double fontSize;
}

/// Lays out and draws premium, branded Scripture images on the device.
///
/// The complete selected text is always represented: the composer first
/// tries a single page down a font-size ladder, then paginates by verse and,
/// for a verse longer than a page, by word. It never drops or shortens text.
class ScriptureImageComposer {
  const ScriptureImageComposer();

  static const _margin = 92.0;

  static ShareLayout layoutFor(ShareScripture s) {
    if (s.verses.length > 1 || s.numbered) return ShareLayout.passage;
    return s.length <= 240 ? ShareLayout.centred : ShareLayout.editorial;
  }

  static List<double> _ladder(ShareFormat f, ShareLayout l) => switch (l) {
    ShareLayout.centred => f == ShareFormat.story ? [72, 66, 60, 56, 52, 48] : [64, 60, 56, 52, 48, 44, 40],
    ShareLayout.editorial => f == ShareFormat.story ? [56, 52, 48, 44, 40, 38] : [48, 46, 44, 42, 40, 38, 36],
    ShareLayout.passage =>
      f == ShareFormat.story
          ? [56, 52, 48, 46, 44, 42]
          : f == ShareFormat.square
          ? [48, 44, 42, 40, 38]
          : [52, 48, 46, 44, 42, 40],
  };

  static double _textWidth(ShareFormat f) => f.width - 2 * _margin;

  // Fixed regions (px).
  static double _headerHeight(ShareFormat f) => f == ShareFormat.story ? 330 : 250;
  static double _footerHeight(ShareFormat f) => f == ShareFormat.story ? 320 : 235;

  static TextStyle _scriptureStyle(double size, Color ink) =>
      TextStyle(fontFamily: MwbFonts.scripture, fontSize: size, height: 1.52, color: ink);

  static TextSpan _span(ShareScripture s, List<ShareVerse> verses, double size, ShareStyle style, ShareLayout layout) {
    final base = _scriptureStyle(size, style.ink);
    final children = <InlineSpan>[];
    final quote = layout == ShareLayout.centred;
    if (quote) children.add(TextSpan(text: '“', style: base));
    for (var i = 0; i < verses.length; i++) {
      final v = verses[i];
      if (s.numbered && v.number > 0) {
        children.add(
          TextSpan(
            text: '${v.number} ',
            style: base.copyWith(
              fontFamily: MwbFonts.ui,
              fontSize: size * 0.52,
              fontWeight: FontWeight.w700,
              color: style.accent,
              fontFeatures: const [ui.FontFeature.superscripts()],
            ),
          ),
        );
      }
      for (final sp in v.spans) {
        children.add(
          TextSpan(
            text: sp.text,
            style: sp.isName ? base.copyWith(color: style.name, fontWeight: FontWeight.w600) : base,
          ),
        );
      }
      if (i < verses.length - 1) children.add(TextSpan(text: ' ', style: base));
    }
    if (quote) children.add(TextSpan(text: '”', style: base));
    return TextSpan(children: children);
  }

  static TextPainter _painter(InlineSpan span, double width, {TextAlign align = TextAlign.left, int? maxLines}) =>
      TextPainter(
        text: span,
        textAlign: align,
        textDirection: TextDirection.ltr,
        maxLines: maxLines,
        ellipsis: maxLines == null ? null : '…',
      )..layout(maxWidth: width);

  static double _titleHeight(ShareScripture s, ShareFormat f, ShareStyle style) {
    if (s.title == null || s.title!.trim().isEmpty) return 0;
    return _titlePainter(s, f, style).height + 34;
  }

  static TextPainter _titlePainter(ShareScripture s, ShareFormat f, ShareStyle style) {
    final base = TextStyle(
      fontFamily: MwbFonts.display,
      fontSize: f == ShareFormat.story ? 58 : 50,
      height: 1.15,
      fontWeight: FontWeight.w600,
      color: style.ink,
    );
    final title = s.title!;
    final n = s.titleName;
    final i = n == null || n.isEmpty ? -1 : title.indexOf(n);
    return _painter(
      i < 0
          ? TextSpan(text: title, style: base)
          : TextSpan(
              children: [
                TextSpan(text: title.substring(0, i), style: base),
                TextSpan(
                  text: n,
                  style: base.copyWith(color: style.name),
                ),
                TextSpan(text: title.substring(i + n!.length), style: base),
              ],
            ),
      _textWidth(f),
      align: TextAlign.center,
      maxLines: 3,
    );
  }

  /// Height reserved for the personal reception (0 without one). The whole
  /// reception is always drawn; it is never shortened.
  static double receptionHeight(ShareScripture s, ShareFormat f, ShareStyle style) {
    if (s.reception == null || s.reception!.trim().isEmpty) return 0;
    final (label, body) = _receptionPainters(s, f, style);
    // The footer has some free space below the translation line (about 30 px
    // is used, keeping a margin to the frame); the rest comes from the Scripture area.
    return math.max(0, 22 + label.height + 8 + body.height - 30);
  }

  static (TextPainter, TextPainter) _receptionPainters(ShareScripture s, ShareFormat f, ShareStyle style) {
    final label = _painter(
      TextSpan(
        text: 'PERSONAL RECEPTION',
        style: TextStyle(
          fontFamily: MwbFonts.ui,
          fontSize: 18,
          letterSpacing: 4,
          fontWeight: FontWeight.w600,
          color: style.accent,
        ),
      ),
      _textWidth(f),
      align: TextAlign.center,
    );
    final text = s.reception!;
    final base = TextStyle(fontFamily: MwbFonts.ui, fontSize: f == ShareFormat.story ? 28 : 25, height: 1.45, color: style.muted);
    final n = s.receptionName;
    final i = n == null || n.isEmpty ? -1 : text.indexOf(n);
    final body = _painter(
      i < 0
          ? TextSpan(text: text, style: base)
          : TextSpan(
              children: [
                TextSpan(text: text.substring(0, i), style: base),
                TextSpan(text: n, style: base.copyWith(color: style.name, fontWeight: FontWeight.w600)),
                TextSpan(text: text.substring(i + n!.length), style: base),
              ],
            ),
      _textWidth(f),
      align: TextAlign.center,
    );
    return (label, body);
  }

  /// Splits the passage into pages. Public for tests.
  static List<SharePagePlan> plan(ShareScripture s, ShareFormat f, ShareStyle style) {
    final layout = layoutFor(s);
    final width = _textWidth(f);
    final align = layout == ShareLayout.centred ? TextAlign.center : TextAlign.left;
    return paginate(
      verses: s.verses,
      ladder: _ladder(f, layout),
      firstLimit: f.height - _headerHeight(f) - _footerHeight(f) - _titleHeight(s, f, style) - receptionHeight(s, f, style),
      otherLimit: f.height - _headerHeight(f) - _footerHeight(f) - receptionHeight(s, f, style),
      heightOf: (vs, size) => _painter(_span(s, vs, size, style, layout), width, align: align).height,
    );
  }

  /// The completeness algorithm shared by every card design (quick share and
  /// the Card Studio): the whole selection on one page down the font
  /// [ladder] if possible; otherwise paginate at the smallest size, by verse
  /// and, for a verse longer than a page, by word. Text is never dropped,
  /// shortened or ellipsised.
  ///
  /// [heightOf] measures verses at a font size; [firstLimit] / [otherLimit]
  /// are the body heights available on the first and following pages.
  static List<SharePagePlan> paginate({
    required List<ShareVerse> verses,
    required List<double> ladder,
    required double firstLimit,
    required double otherLimit,
    required double Function(List<ShareVerse> verses, double size) heightOf,
  }) {
    // 1. One page, largest size that fits.
    for (final size in ladder) {
      if (heightOf(verses, size) <= firstLimit) return [SharePagePlan(verses, size)];
    }

    // 2. Paginate at the smallest comfortable size, by verse then by word.
    final size = ladder.last;
    final pages = <SharePagePlan>[];
    var current = <ShareVerse>[];
    double limit() => pages.isEmpty ? firstLimit : otherLimit;
    final queue = [...verses];
    while (queue.isNotEmpty) {
      final v = queue.removeAt(0);
      if (heightOf([...current, v], size) <= limit()) {
        current.add(v);
        continue;
      }
      if (current.isNotEmpty) {
        // Try to fit part of this verse on the current page if most of it fits.
        final (head, tail) = _splitToFit(current, v, size, limit(), heightOf);
        pages.add(SharePagePlan(head == null ? current : [...current, head], size));
        current = [];
        if (head == null) {
          queue.insert(0, v);
        } else if (tail != null) {
          queue.insert(0, tail);
        }
        continue;
      }
      // A verse longer than a whole page: split by words.
      final (head, tail) = _splitToFit(const [], v, size, limit(), heightOf);
      if (head == null) {
        // Cannot happen with sane sizes; draw it whole rather than drop text.
        pages.add(SharePagePlan([v], size));
        continue;
      }
      pages.add(SharePagePlan([head], size));
      if (tail != null) queue.insert(0, tail);
    }
    if (current.isNotEmpty) pages.add(SharePagePlan(current, size));
    return pages;
  }

  /// The largest word-boundary head of [v] that fits after [before].
  static (ShareVerse?, ShareVerse?) _splitToFit(
    List<ShareVerse> before,
    ShareVerse v,
    double size,
    double limit,
    double Function(List<ShareVerse> verses, double size) heightOf,
  ) {
    // Words with their span flags.
    final tokens = <ShareSpan>[];
    for (final sp in v.spans) {
      for (final m in RegExp(r'\S+\s*|\s+').allMatches(sp.text)) {
        tokens.add(ShareSpan(m.group(0)!, isName: sp.isName));
      }
    }
    if (tokens.length < 2) return (null, null);
    ShareVerse build(List<ShareSpan> ts, int number) {
      final merged = <ShareSpan>[];
      for (final t in ts) {
        if (merged.isNotEmpty && merged.last.isName == t.isName) {
          merged[merged.length - 1] = ShareSpan(merged.last.text + t.text, isName: t.isName);
        } else {
          merged.add(t);
        }
      }
      return ShareVerse(number, merged);
    }

    var lo = 0, hi = tokens.length - 1, best = 0;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      final head = build(tokens.sublist(0, mid), v.number);
      final h = heightOf([...before, head], size);
      if (h <= limit) {
        best = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    // Do not leave a tiny fragment on a page that already has verses.
    if (best == 0 || (before.isNotEmpty && best < math.min(6, tokens.length ~/ 2))) return (null, null);
    final head = build(tokens.sublist(0, best), v.number);
    final rest = tokens.sublist(best);
    // The continuation is unnumbered.
    return (head, rest.isEmpty ? null : build(rest, 0));
  }

  Future<List<ShareImagePage>> compose(ShareScripture s, ShareFormat f, ShareStyle style) async {
    final plans = plan(s, f, style);
    final out = <ShareImagePage>[];
    for (var i = 0; i < plans.length; i++) {
      out.add(await _draw(s, f, style, plans[i], i, plans.length));
    }
    return out;
  }

  Future<ShareImagePage> _draw(
    ShareScripture s,
    ShareFormat f,
    ShareStyle style,
    SharePagePlan plan,
    int index,
    int count,
  ) async {
    final w = f.width.toDouble(), h = f.height.toDouble();
    final layout = layoutFor(s);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

    // Background: warm field with a subtle vertical light, and an inset
    // panel with a fine gold frame.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [
          Color.lerp(style.background, style.panel, 0.5)!,
          style.background,
        ]),
    );
    final panel = RRect.fromRectAndRadius(Rect.fromLTWH(36, 36, w - 72, h - 72), const Radius.circular(44));
    canvas.drawRRect(panel, Paint()..color = style.panel);
    canvas.drawRRect(
      panel.deflate(16),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = style.accent.withValues(alpha: 0.38),
    );

    // Header: brand mark and wordmark, page indicator.
    final headerTop = f == ShareFormat.story ? 120.0 : 92.0;
    drawBrandMark(canvas, Offset(w / 2, headerTop + 26), 26, style);
    final word = _painter(
      TextSpan(
        text: 'MY WORD BIBLE',
        style: TextStyle(
          fontFamily: MwbFonts.ui,
          fontSize: 21,
          letterSpacing: 6,
          fontWeight: FontWeight.w600,
          color: style.accentStrong,
        ),
      ),
      w,
      align: TextAlign.center,
    );
    word.paint(canvas, Offset((w - word.width) / 2, headerTop + 64));
    if (count > 1) {
      final pi = _painter(
        TextSpan(
          text: '${index + 1} / $count',
          style: TextStyle(fontFamily: MwbFonts.ui, fontSize: 22, fontWeight: FontWeight.w600, color: style.muted),
        ),
        200,
      );
      pi.paint(canvas, Offset(w - _margin - pi.width, headerTop + 14));
    }

    // Title (first page only).
    var y = _headerHeight(f);
    if (index == 0 && s.title != null && s.title!.trim().isNotEmpty) {
      final tp = _titlePainter(s, f, style);
      tp.paint(canvas, Offset((w - tp.width) / 2, y));
      y += tp.height + 14;
      canvas.drawLine(
        Offset(w / 2 - 34, y),
        Offset(w / 2 + 34, y),
        Paint()
          ..color = style.accent.withValues(alpha: 0.7)
          ..strokeWidth = 2,
      );
      y += 20;
    }

    // Scripture, vertically centred in the body.
    final align = layout == ShareLayout.centred ? TextAlign.center : TextAlign.left;
    final body = _painter(_span(s, plan.verses, plan.fontSize, style, layout), _textWidth(f), align: align);
    final recH = receptionHeight(s, f, style);
    final bodyBottom = h - _footerHeight(f) - recH;
    final top = y + math.max(0, (bodyBottom - y - body.height) / 2);
    body.paint(canvas, Offset(_margin, top));

    // Footer: reference and translation on every page.
    final footerTop = h - _footerHeight(f) - recH + 40;
    final ref = _painter(
      TextSpan(
        children: [
          TextSpan(
            text: '— ${s.reference}',
            style: TextStyle(
              fontFamily: MwbFonts.scripture,
              fontStyle: FontStyle.italic,
              fontSize: 36,
              fontWeight: FontWeight.w600,
              color: style.accentStrong,
            ),
          ),
        ],
      ),
      _textWidth(f),
      align: TextAlign.center,
      maxLines: 2,
    );
    ref.paint(canvas, Offset((w - ref.width) / 2, footerTop));
    final tr = _painter(
      TextSpan(
        text: count > 1 && index < count - 1 ? '${s.translation}  ·  continued' : s.translation,
        style: TextStyle(
          fontFamily: MwbFonts.ui,
          fontSize: 22,
          letterSpacing: 3,
          fontWeight: FontWeight.w600,
          color: style.muted,
        ),
      ),
      _textWidth(f),
      align: TextAlign.center,
    );
    tr.paint(canvas, Offset((w - tr.width) / 2, footerTop + ref.height + 10));
    if (s.preview) {
      final pv = _painter(
        TextSpan(
          text: 'Review preview — not an approved rendering',
          style: TextStyle(
            fontFamily: MwbFonts.ui,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: style.background.computeLuminance() < 0.2 ? const Color(0xFFE8857A) : const Color(0xFF9B2C22),
          ),
        ),
        _textWidth(f),
        align: TextAlign.center,
      );
      pv.paint(canvas, Offset((w - pv.width) / 2, footerTop + ref.height + 48));
    }
    if (s.reception != null && s.reception!.trim().isNotEmpty && index == count - 1) {
      final (label, body) = _receptionPainters(s, f, style);
      var ry = footerTop + ref.height + 10 + tr.height + 22;
      label.paint(canvas, Offset((w - label.width) / 2, ry));
      ry += label.height + 8;
      body.paint(canvas, Offset((w - body.width) / 2, ry));
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(f.width, f.height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return ShareImagePage(
      png: bytes!.buffer.asUint8List(),
      width: f.width,
      height: f.height,
      index: index,
      count: count,
    );
  }

  /// A small gold medallion with an open-book cross mark.
  static void drawBrandMark(Canvas canvas, Offset c, double r, ShareStyle style) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.linear(c.translate(-r, -r), c.translate(r, r), [
          Color.lerp(style.accent, const Color(0xFFFFFFFF), 0.15)!,
          style.accentStrong,
        ]),
    );
    final p = Paint()
      ..color = const Color(0xFFFFFBF2)
      ..strokeWidth = r * 0.14
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c.translate(0, -r * 0.5), c.translate(0, r * 0.5), p);
    canvas.drawLine(c.translate(-r * 0.3, -r * 0.18), c.translate(r * 0.3, -r * 0.18), p);
  }
}
