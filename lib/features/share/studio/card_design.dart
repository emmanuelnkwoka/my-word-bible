import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../core/theme/mwb_typography.dart';
import '../scripture_image_composer.dart';

/// Card Studio designs. Each template has its own composition, typography and
/// decoration, so the designs do not look alike. Every colour is bundled; no
/// photograph, font or image is downloaded.
enum CardTemplate {
  /// The familiar quick-share card, coloured by the app theme (unchanged).
  classic('classic', 'Classic', 'Your app theme, as in quick share'),
  ivoryGold('ivory_gold', 'Ivory & Gold', 'Elegant ivory with a fine gold frame'),
  navy('navy', 'Royal Navy', 'Premium dark navy with gold detailing'),
  editorial('editorial', 'Editorial', 'Clean magazine typography'),
  minimal('minimal', 'Minimal', 'Modern, quiet and spacious'),
  cinematic('cinematic', 'Cinematic', 'Painted light over hills at dusk'),
  devotional('devotional', 'Devotional', 'Warm amber light and soft glow'),
  nature('nature', 'Nature', 'Sage leaves and rolling hills'),
  vibrant('vibrant', 'Vibrant', 'Bold colour for a younger feed');

  const CardTemplate(this.id, this.label, this.description);
  final String id;
  final String label;
  final String description;

  static CardTemplate byId(String? id) => values.firstWhere((t) => t.id == id, orElse: () => CardTemplate.ivoryGold);

  bool get isClassic => this == CardTemplate.classic;

  List<CardColorway> get colorways => cardColorways[this]!;

  CardFont get defaultFont => switch (this) {
    CardTemplate.minimal || CardTemplate.vibrant => CardFont.sans,
    CardTemplate.editorial || CardTemplate.navy => CardFont.display,
    _ => CardFont.serif,
  };

  /// Alignment used for a short single passage when the user picks "Auto".
  TextAlign get shortAlign => switch (this) {
    CardTemplate.editorial || CardTemplate.minimal || CardTemplate.vibrant => TextAlign.left,
    _ => TextAlign.center,
  };

  ReferencePlacement get defaultReferencePlacement =>
      this == CardTemplate.editorial ? ReferencePlacement.above : ReferencePlacement.below;
}

/// Bundled type families (SIL Open Font Licence, see assets/licenses/).
enum CardFont {
  serif('Serif', MwbFonts.scripture, FontWeight.w400),
  display('Garamond', 'CormorantGaramond', FontWeight.w500),
  sans('Sans', MwbFonts.ui, FontWeight.w500),
  bold('Bold sans', MwbFonts.ui, FontWeight.w700);

  const CardFont(this.label, this.family, this.weight);
  final String label;
  final String family;
  final FontWeight weight;

  /// Cormorant runs small; it is set larger to match the others' x-height.
  double get sizeFactor => this == CardFont.display ? 1.14 : 1.0;
  double get lineHeight => switch (this) {
    CardFont.display => 1.32,
    CardFont.sans || CardFont.bold => 1.42,
    CardFont.serif => 1.5,
  };
}

enum CardAlignment {
  auto('Auto'),
  left('Left'),
  centre('Centre');

  const CardAlignment(this.label);
  final String label;
}

enum ReferencePlacement {
  below('Below'),
  above('Above');

  const ReferencePlacement(this.label);
  final String label;
}

/// One colour scheme of a template.
@immutable
class CardColorway {
  const CardColorway({
    required this.name,
    required this.background,
    required this.ink,
    required this.muted,
    required this.accent,
    this.panel,
    this.backdrop,
    this.glow,
  });

  final String name;

  /// Background gradient stops, top to bottom.
  final List<Color> background;

  /// Inset panel behind the text (framed templates).
  final Color? panel;

  /// The colour text is actually read against (panel, scrim or background
  /// average). Used for contrast checks.
  final Color? backdrop;
  final Color? glow;
  final Color ink;
  final Color muted;
  final Color accent;

  Color get textBackdrop =>
      backdrop ?? panel ?? Color.lerp(background.first, background.last, 0.5)!;
}

const _ivoryInk = Color(0xFF2B2118);

/// Colourways per template. Designers can add more without code changes.
const cardColorways = <CardTemplate, List<CardColorway>>{
  CardTemplate.classic: [
    // Placeholder: classic takes its colours from the app theme.
    CardColorway(name: 'Theme', background: [Color(0xFFF3E9D8)], ink: _ivoryInk, muted: Color(0xFF6E6152), accent: Color(0xFFA8823A)),
  ],
  CardTemplate.ivoryGold: [
    CardColorway(
      name: 'Ivory',
      background: [Color(0xFFF6EEDC), Color(0xFFEADBBB)],
      panel: Color(0xFFFCF8EF),
      ink: _ivoryInk,
      muted: Color(0xFF6E6152),
      accent: Color(0xFFA67C2E),
    ),
    CardColorway(
      name: 'Pearl',
      background: [Color(0xFFF3F1EC), Color(0xFFE2DED4)],
      panel: Color(0xFFFBFAF7),
      ink: Color(0xFF26231F),
      muted: Color(0xFF66625A),
      accent: Color(0xFF9C7B3C),
    ),
    CardColorway(
      name: 'Blush',
      background: [Color(0xFFF6E7E1), Color(0xFFE9CFC5)],
      panel: Color(0xFFFCF5F2),
      ink: Color(0xFF3A2420),
      muted: Color(0xFF755851),
      accent: Color(0xFFA0683F),
    ),
  ],
  CardTemplate.navy: [
    CardColorway(
      name: 'Navy',
      background: [Color(0xFF0D1830), Color(0xFF1B2C4F)],
      glow: Color(0xFF3A5A92),
      ink: Color(0xFFF5EEDD),
      muted: Color(0xFFB9C0CF),
      accent: Color(0xFFD6B26A),
    ),
    CardColorway(
      name: 'Midnight',
      background: [Color(0xFF07090F), Color(0xFF181C2C)],
      glow: Color(0xFF2E3550),
      ink: Color(0xFFF2EFE8),
      muted: Color(0xFFB0B3BD),
      accent: Color(0xFFC9A55C),
    ),
    CardColorway(
      name: 'Emerald',
      background: [Color(0xFF0B241D), Color(0xFF15433A)],
      glow: Color(0xFF2C6B5B),
      ink: Color(0xFFF4EFE2),
      muted: Color(0xFFB5C7BF),
      accent: Color(0xFFD9B66E),
    ),
  ],
  CardTemplate.editorial: [
    CardColorway(
      name: 'Paper',
      background: [Color(0xFFF4F1EA), Color(0xFFF4F1EA)],
      ink: Color(0xFF151515),
      muted: Color(0xFF5E5A54),
      accent: Color(0xFFB0372A),
    ),
    CardColorway(
      name: 'Newsprint',
      background: [Color(0xFFE8E4DA), Color(0xFFE8E4DA)],
      ink: Color(0xFF1B1A18),
      muted: Color(0xFF5A564E),
      accent: Color(0xFF1F4E79),
    ),
    CardColorway(
      name: 'Ink',
      background: [Color(0xFF151515), Color(0xFF151515)],
      ink: Color(0xFFF0EBE1),
      muted: Color(0xFFA8A398),
      accent: Color(0xFFE0735F),
    ),
  ],
  CardTemplate.minimal: [
    CardColorway(
      name: 'White',
      background: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
      ink: Color(0xFF111111),
      muted: Color(0xFF6B6B6B),
      accent: Color(0xFF111111),
    ),
    CardColorway(
      name: 'Stone',
      background: [Color(0xFFECEAE6), Color(0xFFECEAE6)],
      ink: Color(0xFF1C1B19),
      muted: Color(0xFF66635D),
      accent: Color(0xFF8A6D3B),
    ),
    CardColorway(
      name: 'Black',
      background: [Color(0xFF0E0E0F), Color(0xFF0E0E0F)],
      ink: Color(0xFFF7F7F5),
      muted: Color(0xFF9E9E9A),
      accent: Color(0xFFF7F7F5),
    ),
  ],
  CardTemplate.cinematic: [
    CardColorway(
      name: 'Dusk',
      background: [Color(0xFF151A36), Color(0xFF5A3F6B), Color(0xFFE59A6E)],
      glow: Color(0xFFFFC98A),
      backdrop: Color(0xFF241D33),
      ink: Color(0xFFFFFFFF),
      muted: Color(0xFFE6DCE8),
      accent: Color(0xFFFFD39A),
    ),
    CardColorway(
      name: 'Dawn',
      background: [Color(0xFF1C3554), Color(0xFF527FA3), Color(0xFFF2C27B)],
      glow: Color(0xFFFFE3A6),
      backdrop: Color(0xFF1F3048),
      ink: Color(0xFFFFFFFF),
      muted: Color(0xFFE3EAF2),
      accent: Color(0xFFFFE0A3),
    ),
    CardColorway(
      name: 'Night',
      background: [Color(0xFF03050C), Color(0xFF0E1A33), Color(0xFF243B63)],
      glow: Color(0xFF9DB7E6),
      backdrop: Color(0xFF0A1122),
      ink: Color(0xFFFFFFFF),
      muted: Color(0xFFCAD4E6),
      accent: Color(0xFFE9D7A4),
    ),
  ],
  CardTemplate.devotional: [
    CardColorway(
      name: 'Amber',
      background: [Color(0xFFFBE7CF), Color(0xFFEDB98B)],
      glow: Color(0xFFFFF4DF),
      backdrop: Color(0xFFF7D9B6),
      ink: Color(0xFF3A2112),
      muted: Color(0xFF6E4630),
      accent: Color(0xFF94431A),
    ),
    CardColorway(
      name: 'Rose',
      background: [Color(0xFFF9E3E1), Color(0xFFE4AAA7)],
      glow: Color(0xFFFFF3F1),
      backdrop: Color(0xFFF1CBC8),
      ink: Color(0xFF3C1D1E),
      muted: Color(0xFF6D4243),
      accent: Color(0xFF8E3440),
    ),
    CardColorway(
      name: 'Honey',
      background: [Color(0xFFFFF1C9), Color(0xFFF0C46B)],
      glow: Color(0xFFFFFAE6),
      backdrop: Color(0xFFF9DE9B),
      ink: Color(0xFF3A2A0C),
      muted: Color(0xFF6A5222),
      accent: Color(0xFF8A5A00),
    ),
  ],
  CardTemplate.nature: [
    CardColorway(
      name: 'Sage',
      background: [Color(0xFFEAF0E3), Color(0xFFC8D8BC)],
      backdrop: Color(0xFFDDE7D4),
      ink: Color(0xFF1F2E1C),
      muted: Color(0xFF4C5E47),
      accent: Color(0xFF4A6C35),
    ),
    CardColorway(
      name: 'Sea',
      background: [Color(0xFFE5F0EF), Color(0xFFB4D2CF)],
      backdrop: Color(0xFFD3E5E3),
      ink: Color(0xFF15302E),
      muted: Color(0xFF45605D),
      accent: Color(0xFF2D6E69),
    ),
    CardColorway(
      name: 'Forest',
      background: [Color(0xFF15261B), Color(0xFF2B4632)],
      backdrop: Color(0xFF1C3123),
      ink: Color(0xFFF1F3EA),
      muted: Color(0xFFBCCAB8),
      accent: Color(0xFFB9D58F),
    ),
  ],
  CardTemplate.vibrant: [
    CardColorway(
      name: 'Electric',
      background: [Color(0xFF4B23E8), Color(0xFFE03C96)],
      glow: Color(0xFF2FE3D0),
      backdrop: Color(0xFF7A2FC2),
      ink: Color(0xFFFFFFFF),
      muted: Color(0xFFF3E8FF),
      accent: Color(0xFFFFE45C),
    ),
    CardColorway(
      name: 'Sunset',
      background: [Color(0xFFE8452C), Color(0xFFB8327A)],
      glow: Color(0xFFFFC23C),
      backdrop: Color(0xFFC83A55),
      ink: Color(0xFFFFFFFF),
      muted: Color(0xFFFFE9E2),
      accent: Color(0xFFFFE07A),
    ),
    CardColorway(
      name: 'Lime',
      background: [Color(0xFFC6FF4D), Color(0xFF2FE0A8)],
      glow: Color(0xFFFFFFFF),
      backdrop: Color(0xFF86F07B),
      ink: Color(0xFF0D1F14),
      muted: Color(0xFF234A31),
      accent: Color(0xFF0D1F14),
    ),
  ],
};

/// WCAG contrast ratio between two colours.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Minimum contrast for card text (WCAG AA for normal text).
const minCardContrast = 4.5;

/// Everything the user can change in the Card Studio.
@immutable
class CardDesign {
  const CardDesign({
    this.template = CardTemplate.ivoryGold,
    this.colorway = 0,
    this.format = ShareFormat.portrait,
    this.font,
    this.alignment = CardAlignment.auto,
    this.textScale = 1.0,
    this.ink,
    this.referencePlacement,
    this.decorations = true,
    this.showVerseNumbers = true,
    this.senderName,
    this.message,
    this.branding = true,
  });

  final CardTemplate template;
  final int colorway;
  final ShareFormat format;

  /// Null: the template's own typeface.
  final CardFont? font;
  final CardAlignment alignment;

  /// 0.85 (smaller) – 1.2 (larger). The fitting ladder still guarantees the
  /// whole passage is shown.
  final double textScale;

  /// Null: the colourway's ink. Ignored if it would not be readable.
  final Color? ink;

  /// Null: the template's default.
  final ReferencePlacement? referencePlacement;
  final bool decorations;
  final bool showVerseNumbers;

  /// "Shared by …" line; null hides it. Never the recipient.
  final String? senderName;

  /// Optional personal note shown on the first card.
  final String? message;

  /// Subtle "MY WORD BIBLE" attribution at the foot of the card.
  final bool branding;

  static const textScales = [0.85, 1.0, 1.15];

  CardColorway get palette {
    final list = template.colorways;
    return list[colorway.clamp(0, list.length - 1)];
  }

  CardFont get effectiveFont => font ?? template.defaultFont;
  ReferencePlacement get effectivePlacement => referencePlacement ?? template.defaultReferencePlacement;

  /// Ink colours offered for this colourway: only readable ones.
  List<Color> get inkOptions {
    final p = palette;
    final candidates = <Color>[p.ink, p.accent, const Color(0xFFFFFFFF), const Color(0xFF141414)];
    final out = <Color>[];
    for (final c in candidates) {
      if (contrastRatio(c, p.textBackdrop) >= minCardContrast && !out.contains(c)) out.add(c);
    }
    return out;
  }

  /// The ink actually drawn: the chosen ink if readable, otherwise the
  /// colourway's ink.
  Color get effectiveInk {
    final chosen = ink;
    if (chosen != null && contrastRatio(chosen, palette.textBackdrop) >= minCardContrast) return chosen;
    return palette.ink;
  }

  String? get trimmedMessage {
    final m = message?.trim();
    return m == null || m.isEmpty ? null : m;
  }

  String? get trimmedSender {
    final s = senderName?.trim();
    return s == null || s.isEmpty ? null : s;
  }

  CardDesign copyWith({
    CardTemplate? template,
    int? colorway,
    ShareFormat? format,
    CardFont? font,
    bool clearFont = false,
    CardAlignment? alignment,
    double? textScale,
    Color? ink,
    bool clearInk = false,
    ReferencePlacement? referencePlacement,
    bool? decorations,
    bool? showVerseNumbers,
    String? senderName,
    bool clearSender = false,
    String? message,
    bool clearMessage = false,
    bool? branding,
  }) => CardDesign(
    template: template ?? this.template,
    colorway: colorway ?? (template != null && template != this.template ? 0 : this.colorway),
    format: format ?? this.format,
    font: clearFont ? null : (font ?? this.font),
    alignment: alignment ?? this.alignment,
    textScale: textScale ?? this.textScale,
    ink: clearInk || (template != null && template != this.template) ? null : (ink ?? this.ink),
    referencePlacement: referencePlacement ?? this.referencePlacement,
    decorations: decorations ?? this.decorations,
    showVerseNumbers: showVerseNumbers ?? this.showVerseNumbers,
    senderName: clearSender ? null : (senderName ?? this.senderName),
    message: clearMessage ? null : (message ?? this.message),
    branding: branding ?? this.branding,
  );

  /// The look (not the personal text) remembered for next time.
  Map<String, dynamic> toJson() => {
    'tpl': template.id,
    'cw': colorway,
    'fmt': format.name,
    if (font != null) 'font': font!.name,
    'align': alignment.name,
    'scale': textScale,
    'deco': decorations,
    'nums': showVerseNumbers,
    'brand': branding,
    if (referencePlacement != null) 'ref': referencePlacement!.name,
  };

  factory CardDesign.fromJson(Map<String, dynamic> j) => CardDesign(
    template: CardTemplate.byId(j['tpl'] as String?),
    colorway: j['cw'] as int? ?? 0,
    format: ShareFormat.values.asNameMap()[j['fmt']] ?? ShareFormat.portrait,
    font: CardFont.values.asNameMap()[j['font']],
    alignment: CardAlignment.values.asNameMap()[j['align']] ?? CardAlignment.auto,
    textScale: (j['scale'] as num?)?.toDouble() ?? 1.0,
    decorations: j['deco'] as bool? ?? true,
    showVerseNumbers: j['nums'] as bool? ?? true,
    branding: j['brand'] as bool? ?? true,
    referencePlacement: ReferencePlacement.values.asNameMap()[j['ref']],
  );
}
