import 'package:flutter/material.dart';

/// A complete semantic colour palette for one theme in one brightness.
///
/// Screens never reference raw colours; they consume these semantic roles via
/// `context.mwb.colors`. Adding a new theme means adding a new pair of palettes.
@immutable
class MwbPalette {
  const MwbPalette({
    required this.brightness,
    required this.primary,
    required this.primaryStrong,
    required this.onPrimary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.divider,
    required this.success,
    required this.warning,
    required this.error,
    required this.selected,
    required this.disabled,
  });

  final Brightness brightness;

  /// Brand colour: icons, active states, fine detailing.
  final Color primary;

  /// Deeper brand colour used for filled buttons (better text contrast).
  final Color primaryStrong;

  /// Text and icons placed on [primaryStrong] / [primary] fills.
  final Color onPrimary;

  /// Supporting tone for secondary emphasis.
  final Color secondary;

  /// Restrained accent used sparingly (badges, highlights, markers).
  final Color accent;

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color divider;
  final Color success;
  final Color warning;
  final Color error;

  /// Fill for selected cards, chips and rows.
  final Color selected;

  /// Disabled controls and text.
  final Color disabled;

  bool get isDark => brightness == Brightness.dark;

  /// The champagne-to-antique brand gradient used for primary actions and
  /// brand marks. Derived from the palette so every theme has its own.
  LinearGradient get brandGradient => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color.lerp(accent, primary, 0.35)!, primaryStrong],
  );

  /// A very soft, warm elevation shadow for cards and the floating navigation.
  List<BoxShadow> get softShadow => [
    BoxShadow(
      color: (isDark ? Colors.black : const Color(0xFF6B4A1E)).withValues(alpha: isDark ? 0.35 : 0.07),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  /// Personalised name colour inside Scripture (gold, readable on surfaces).
  Color get nameInk => isDark ? accent : Color.lerp(primary, primaryStrong, 0.4)!;

  static const lightHighlightTones = [Color(0xFFF3E2B3), Color(0xFFDCEBD5), Color(0xFFD9E4F2), Color(0xFFF1D9DC)];

  static const darkHighlightTones = [Color(0xFF5C4A1F), Color(0xFF2F4A39), Color(0xFF2E3F5C), Color(0xFF55303A)];

  /// Scripture highlight tones (gold, sage, sky, rose) for this brightness.
  List<Color> get highlightTones => isDark ? darkHighlightTones : lightHighlightTones;
}
