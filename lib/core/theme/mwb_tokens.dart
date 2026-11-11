import 'package:flutter/widgets.dart';

/// Spacing scale (4pt base).
abstract final class MwbSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal page gutter. Wider on tablets via [MwbLayout.gutter].
  static const double gutter = 20;
}

/// Corner radii. MWB uses restrained rounding.
abstract final class MwbRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
}

/// Motion durations: short and purposeful.
abstract final class MwbMotion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 360);
  static const Curve curve = Curves.easeOutCubic;
}

/// Minimum touch target (Material and Apple HIG guidance).
const double kMwbMinTouchTarget = 48;
