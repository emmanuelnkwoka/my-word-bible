import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../core/theme/mwb_palette.dart';
import '../../core/theme/mwb_typography.dart';

/// What appears on a Scripture card. [scripture] is printed exactly as given.
@immutable
class ScriptureCardContent {
  const ScriptureCardContent({
    required this.scripture,
    required this.reference,
    required this.translation,
    this.overline,
    this.heading,
    this.attribution,
  });

  /// Canonical text, exactly as read from the installed translation.
  final String scripture;

  /// e.g. "John 14:27".
  final String reference;

  /// Translation abbreviation, e.g. "KJV".
  final String translation;

  /// e.g. "DAILY WORD · PEACE".
  final String? overline;

  /// Editorial heading, shown above the Scripture.
  final String? heading;

  /// Small print, e.g. "King James Version · Public domain".
  final String? attribution;
}

/// Colours for a card, taken from the active app theme.
@immutable
class ScriptureCardStyle {
  const ScriptureCardStyle({
    required this.background,
    required this.panel,
    required this.ink,
    required this.muted,
    required this.accent,
  });

  factory ScriptureCardStyle.fromPalette(MwbPalette p) => ScriptureCardStyle(
    background: p.background,
    panel: p.surface,
    ink: p.textPrimary,
    muted: p.textSecondary,
    accent: p.primary,
  );

  final Color background;
  final Color panel;
  final Color ink;
  final Color muted;
  final Color accent;
}

@immutable
class ScriptureCardImage {
  const ScriptureCardImage({
    required this.png,
    required this.width,
    required this.height,
    required this.scriptureFontSize,
  });
  final Uint8List png;
  final int width;
  final int height;

  /// The size the text-fitting ladder settled on.
  final double scriptureFontSize;
}

/// Renders a portrait (4:5) Scripture card to PNG without needing the card
/// to be on screen. Long passages step down a font-size ladder until they fit.
class ScriptureCardRenderer {
  const ScriptureCardRenderer();

  static const width = 1080.0;
  static const height = 1350.0;
  static const _margin = 96.0;
  static const _textWidth = width - 2 * _margin - 40;
  static const _ladder = [60.0, 56.0, 52.0, 48.0, 44.0, 40.0, 37.0, 34.0, 31.0, 28.0, 26.0];

  /// Font size chosen for [scripture] (public for tests and previews).
  static ({double size, TextPainter painter}) fitScripture(String scripture, Color ink, double maxHeight) {
    late TextPainter painter;
    for (final size in _ladder) {
      painter = _painter(
        '“$scripture”',
        TextStyle(fontFamily: MwbFonts.scripture, fontSize: size, height: 1.42, color: ink),
        _textWidth,
      );
      if (painter.height <= maxHeight) return (size: size, painter: painter);
    }
    return (size: _ladder.last, painter: painter);
  }

  static TextPainter _painter(
    String text,
    TextStyle style,
    double maxWidth, {
    TextAlign align = TextAlign.center,
    int? maxLines,
  }) => TextPainter(
    text: TextSpan(text: text, style: style),
    textAlign: align,
    textDirection: TextDirection.ltr,
    maxLines: maxLines,
    ellipsis: maxLines == null ? null : '…',
  )..layout(maxWidth: maxWidth);

  Future<ScriptureCardImage> render(ScriptureCardContent content, ScriptureCardStyle style) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

    // Background, panel and frame.
    canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), Paint()..color = style.background);
    final panel = RRect.fromRectAndRadius(
      const Rect.fromLTWH(48, 48, width - 96, height - 96),
      const Radius.circular(40),
    );
    canvas.drawRRect(panel, Paint()..color = style.panel);
    canvas.drawRRect(
      panel.deflate(14),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = style.accent.withValues(alpha: 0.45),
    );

    var y = 150.0;
    void centred(TextPainter p) {
      p.paint(canvas, Offset((width - p.width) / 2, y));
      y += p.height;
    }

    if (content.overline case final o?) {
      centred(
        _painter(
          o.toUpperCase(),
          TextStyle(
            fontFamily: MwbFonts.ui,
            fontSize: 26,
            letterSpacing: 4,
            fontWeight: FontWeight.w600,
            color: style.accent,
          ),
          _textWidth,
          maxLines: 1,
        ),
      );
      y += 22;
    }
    if (content.heading case final h?) {
      centred(
        _painter(
          h,
          TextStyle(
            fontFamily: MwbFonts.display,
            fontSize: 54,
            fontWeight: FontWeight.w600,
            color: style.ink,
            height: 1.1,
          ),
          _textWidth,
          maxLines: 2,
        ),
      );
    }
    final headerBottom = y + 40;

    // Footer (bottom-up) so Scripture can use the space in between.
    final brand = _painter(
      'My Word Bible',
      TextStyle(fontFamily: MwbFonts.display, fontSize: 38, fontWeight: FontWeight.w600, color: style.ink),
      _textWidth,
      maxLines: 1,
    );
    final fine = content.attribution == null
        ? null
        : _painter(
            content.attribution!,
            TextStyle(fontFamily: MwbFonts.ui, fontSize: 22, color: style.muted),
            _textWidth,
            maxLines: 2,
          );
    final footerTop = height - 118 - brand.height - (fine == null ? 0 : fine.height + 8);
    final reference = _painter(
      '— ${content.reference} · ${content.translation}',
      TextStyle(
        fontFamily: MwbFonts.ui,
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
        color: style.accent,
      ),
      _textWidth,
      maxLines: 2,
    );
    final scriptureBottomLimit = footerTop - 70 - reference.height - 36;

    final fit = fitScripture(content.scripture, style.ink, scriptureBottomLimit - headerBottom);
    final block = fit.painter.height + 36 + reference.height;
    y = headerBottom + ((footerTop - 70 - headerBottom - block) / 2).clamp(0, double.infinity);
    centred(fit.painter);
    y += 36;
    centred(reference);

    y = footerTop;
    canvas.drawLine(
      Offset(width / 2 - 60, y - 34),
      Offset(width / 2 + 60, y - 34),
      Paint()
        ..color = style.accent.withValues(alpha: 0.6)
        ..strokeWidth = 2,
    );
    centred(brand);
    if (fine != null) {
      y += 8;
      centred(fine);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return ScriptureCardImage(
      png: bytes!.buffer.asUint8List(),
      width: width.toInt(),
      height: height.toInt(),
      scriptureFontSize: fit.size,
    );
  }
}
