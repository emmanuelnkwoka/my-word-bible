import 'package:flutter/material.dart';

import 'mwb_palette.dart';

/// Bundled font families (see pubspec.yaml). No fonts are fetched at runtime.
abstract final class MwbFonts {
  /// Editorial serif for display and headings.
  static const display = 'CormorantGaramond';

  /// Highly readable serif for Scripture.
  static const scripture = 'Lora';

  /// Clean sans-serif for interface text.
  static const ui = 'Inter';
}

/// Typography roles for MWB. Every role resolves its colour from the palette,
/// so text adapts to the active theme automatically.
@immutable
class MwbTypography {
  const MwbTypography._({
    required this.display,
    required this.pageHeading,
    required this.sectionHeading,
    required this.cardTitle,
    required this.body,
    required this.bodyStrong,
    required this.supporting,
    required this.scripture,
    required this.scriptureReference,
    required this.label,
    required this.overline,
    required this.button,
    required this.caption,
  });

  factory MwbTypography.fromPalette(MwbPalette p) {
    return MwbTypography._(
      display: TextStyle(
        fontFamily: MwbFonts.display,
        fontSize: 40,
        height: 1.08,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: p.textPrimary,
      ),
      pageHeading: TextStyle(
        fontFamily: MwbFonts.display,
        fontSize: 32,
        height: 1.12,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: p.textPrimary,
      ),
      sectionHeading: TextStyle(
        fontFamily: MwbFonts.display,
        fontSize: 23,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: p.textPrimary,
      ),
      cardTitle: TextStyle(
        fontFamily: MwbFonts.ui,
        fontSize: 15.5,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: p.textPrimary,
      ),
      body: TextStyle(
        fontFamily: MwbFonts.ui,
        fontSize: 15,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: p.textPrimary,
      ),
      bodyStrong: TextStyle(
        fontFamily: MwbFonts.ui,
        fontSize: 15,
        height: 1.45,
        fontWeight: FontWeight.w600,
        color: p.textPrimary,
      ),
      supporting: TextStyle(
        fontFamily: MwbFonts.ui,
        fontSize: 13.5,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: p.textSecondary,
      ),
      scripture: TextStyle(
        fontFamily: MwbFonts.scripture,
        fontSize: 18,
        height: 1.7,
        fontWeight: FontWeight.w400,
        color: p.textPrimary,
      ),
      scriptureReference: TextStyle(
        fontFamily: MwbFonts.ui,
        fontSize: 12.5,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: p.primary,
      ),
      label: TextStyle(
        fontFamily: MwbFonts.ui,
        fontSize: 13,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: p.textPrimary,
      ),
      overline: TextStyle(
        fontFamily: MwbFonts.ui,
        fontSize: 11.5,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
        color: p.primary,
      ),
      button: const TextStyle(
        fontFamily: MwbFonts.ui,
        fontSize: 15,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      caption: TextStyle(
        fontFamily: MwbFonts.ui,
        fontSize: 12,
        height: 1.35,
        fontWeight: FontWeight.w400,
        color: p.textSecondary,
      ),
    );
  }

  final TextStyle display;
  final TextStyle pageHeading;
  final TextStyle sectionHeading;
  final TextStyle cardTitle;
  final TextStyle body;
  final TextStyle bodyStrong;
  final TextStyle supporting;
  final TextStyle scripture;
  final TextStyle scriptureReference;
  final TextStyle label;
  final TextStyle overline;
  final TextStyle button;
  final TextStyle caption;
}
