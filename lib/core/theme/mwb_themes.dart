import 'package:flutter/material.dart';

import 'mwb_palette.dart';

/// Identifiers for the seven MWB colour themes. Persisted by [storageKey].
enum MwbThemeId {
  classicGold('classic_gold', 'Classic Gold', 'Warm ivory, espresso and antique gold'),
  royalNavy('royal_navy', 'Royal Navy', 'Deep navy with a muted gold accent'),
  forestGreen('forest_green', 'Forest Green', 'Quiet evergreen and soft parchment'),
  warmSand('warm_sand', 'Warm Sand', 'Sunlit sand with terracotta warmth'),
  royalPlum('royal_plum', 'Royal Plum', 'Regal plum with a soft gold accent'),
  oceanBlue('ocean_blue', 'Ocean Blue', 'Calm deep-water teal and sand'),
  roseBurgundy('rose_burgundy', 'Rose Burgundy', 'Rich burgundy with rose undertones');

  const MwbThemeId(this.storageKey, this.label, this.description);

  final String storageKey;
  final String label;
  final String description;

  static MwbThemeId fromStorageKey(String? key) =>
      MwbThemeId.values.firstWhere((t) => t.storageKey == key, orElse: () => MwbThemeId.classicGold);
}

/// A theme definition: a hand-tuned light and dark palette.
@immutable
class MwbThemeDefinition {
  const MwbThemeDefinition({required this.id, required this.light, required this.dark});

  final MwbThemeId id;
  final MwbPalette light;
  final MwbPalette dark;

  MwbPalette paletteFor(Brightness b) => b == Brightness.dark ? dark : light;
}

/// Registry of all seven themes. Each palette is designed individually rather
/// than derived from a single seed colour.
abstract final class MwbThemes {
  static const classicGold = MwbThemeDefinition(
    id: MwbThemeId.classicGold,
    light: MwbPalette(
      brightness: Brightness.light,
      primary: Color(0xFFB88A35),
      primaryStrong: Color(0xFF98702C),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF6E5A47),
      accent: Color(0xFFC9A45C),
      background: Color(0xFFF8F2E8),
      surface: Color(0xFFFBF7F0),
      surfaceElevated: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF2D1A13),
      textSecondary: Color(0xFF82766D),
      border: Color(0xFFE9E0D4),
      divider: Color(0xFFEFE7DB),
      success: Color(0xFF4F7A4A),
      warning: Color(0xFFA86F1C),
      error: Color(0xFFA4372D),
      selected: Color(0xFFF2E6CD),
      disabled: Color(0xFFC9C0B5),
    ),
    dark: MwbPalette(
      brightness: Brightness.dark,
      primary: Color(0xFFD1A759),
      primaryStrong: Color(0xFFC29844),
      onPrimary: Color(0xFF1A130C),
      secondary: Color(0xFFB8A48C),
      accent: Color(0xFFE0BE7A),
      background: Color(0xFF15110D),
      surface: Color(0xFF1D1813),
      surfaceElevated: Color(0xFF26201A),
      textPrimary: Color(0xFFF3EADC),
      textSecondary: Color(0xFFA89C8E),
      border: Color(0xFF3A3127),
      divider: Color(0xFF2E271F),
      success: Color(0xFF8DB886),
      warning: Color(0xFFDDAA4E),
      error: Color(0xFFE38276),
      selected: Color(0xFF3A2E1B),
      disabled: Color(0xFF5A5047),
    ),
  );

  static const royalNavy = MwbThemeDefinition(
    id: MwbThemeId.royalNavy,
    light: MwbPalette(
      brightness: Brightness.light,
      primary: Color(0xFF2A4A7F),
      primaryStrong: Color(0xFF1F3A68),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF5A6B85),
      accent: Color(0xFFB0924F),
      background: Color(0xFFF4F5F8),
      surface: Color(0xFFFAFAFC),
      surfaceElevated: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF121C2E),
      textSecondary: Color(0xFF69748A),
      border: Color(0xFFDDE2EA),
      divider: Color(0xFFE8EBF1),
      success: Color(0xFF3F7A5A),
      warning: Color(0xFFA36A12),
      error: Color(0xFFA63A3A),
      selected: Color(0xFFE3E9F4),
      disabled: Color(0xFFBCC3CF),
    ),
    dark: MwbPalette(
      brightness: Brightness.dark,
      primary: Color(0xFF9DB4DF),
      primaryStrong: Color(0xFF8AA5D6),
      onPrimary: Color(0xFF0C111C),
      secondary: Color(0xFF9AA8C0),
      accent: Color(0xFFCDB278),
      background: Color(0xFF0C111C),
      surface: Color(0xFF131A28),
      surfaceElevated: Color(0xFF1A2334),
      textPrimary: Color(0xFFE9EDF5),
      textSecondary: Color(0xFF98A3B8),
      border: Color(0xFF2A3448),
      divider: Color(0xFF212A3B),
      success: Color(0xFF7FBF9A),
      warning: Color(0xFFDDAE58),
      error: Color(0xFFE88A8A),
      selected: Color(0xFF1E2B45),
      disabled: Color(0xFF47506A),
    ),
  );

  static const forestGreen = MwbThemeDefinition(
    id: MwbThemeId.forestGreen,
    light: MwbPalette(
      brightness: Brightness.light,
      primary: Color(0xFF3A6B52),
      primaryStrong: Color(0xFF2F5D45),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF6B7A68),
      accent: Color(0xFFA88B4A),
      background: Color(0xFFF3F4EE),
      surface: Color(0xFFF9FAF5),
      surfaceElevated: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF18241C),
      textSecondary: Color(0xFF6C776D),
      border: Color(0xFFDCE1D6),
      divider: Color(0xFFE6EAE1),
      success: Color(0xFF3E7A4C),
      warning: Color(0xFFA06C1A),
      error: Color(0xFFA43D34),
      selected: Color(0xFFE2EBDF),
      disabled: Color(0xFFBEC5BB),
    ),
    dark: MwbPalette(
      brightness: Brightness.dark,
      primary: Color(0xFF8FBEA2),
      primaryStrong: Color(0xFF7DB094),
      onPrimary: Color(0xFF0F1511),
      secondary: Color(0xFFA2B09F),
      accent: Color(0xFFC8AE72),
      background: Color(0xFF0F1511),
      surface: Color(0xFF151D17),
      surfaceElevated: Color(0xFF1C261F),
      textPrimary: Color(0xFFE7EEE8),
      textSecondary: Color(0xFF9AA89D),
      border: Color(0xFF2A372E),
      divider: Color(0xFF212B24),
      success: Color(0xFF8CC79A),
      warning: Color(0xFFD9AB55),
      error: Color(0xFFE58A80),
      selected: Color(0xFF1F3127),
      disabled: Color(0xFF465248),
    ),
  );

  static const warmSand = MwbThemeDefinition(
    id: MwbThemeId.warmSand,
    light: MwbPalette(
      brightness: Brightness.light,
      primary: Color(0xFFA6704A),
      primaryStrong: Color(0xFF8A5634),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF8C7A66),
      accent: Color(0xFFC49A6C),
      background: Color(0xFFF6EFE4),
      surface: Color(0xFFFAF5EC),
      surfaceElevated: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF33241A),
      textSecondary: Color(0xFF857261),
      border: Color(0xFFE6D9C6),
      divider: Color(0xFFEEE4D5),
      success: Color(0xFF557A45),
      warning: Color(0xFFA5681A),
      error: Color(0xFFA53B2E),
      selected: Color(0xFFF0E0CC),
      disabled: Color(0xFFCDBFAE),
    ),
    dark: MwbPalette(
      brightness: Brightness.dark,
      primary: Color(0xFFD9A47C),
      primaryStrong: Color(0xFFCB9268),
      onPrimary: Color(0xFF17120E),
      secondary: Color(0xFFBBA790),
      accent: Color(0xFFD8B48A),
      background: Color(0xFF17120E),
      surface: Color(0xFF1F1914),
      surfaceElevated: Color(0xFF28201A),
      textPrimary: Color(0xFFF2E7DA),
      textSecondary: Color(0xFFADA092),
      border: Color(0xFF3A2F25),
      divider: Color(0xFF2E251D),
      success: Color(0xFF94BE84),
      warning: Color(0xFFDDA955),
      error: Color(0xFFE58777),
      selected: Color(0xFF3A2A1E),
      disabled: Color(0xFF5A4E43),
    ),
  );

  static const royalPlum = MwbThemeDefinition(
    id: MwbThemeId.royalPlum,
    light: MwbPalette(
      brightness: Brightness.light,
      primary: Color(0xFF6E3A69),
      primaryStrong: Color(0xFF5E2E5A),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF7D6A7B),
      accent: Color(0xFFB48A4E),
      background: Color(0xFFF6F2F5),
      surface: Color(0xFFFBF8FA),
      surfaceElevated: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF24151F),
      textSecondary: Color(0xFF7E6D7A),
      border: Color(0xFFE6DCE3),
      divider: Color(0xFFEDE5EB),
      success: Color(0xFF477A55),
      warning: Color(0xFFA2691C),
      error: Color(0xFFA63A45),
      selected: Color(0xFFEFE2EC),
      disabled: Color(0xFFC8BCC5),
    ),
    dark: MwbPalette(
      brightness: Brightness.dark,
      primary: Color(0xFFD0A3CA),
      primaryStrong: Color(0xFFC291BB),
      onPrimary: Color(0xFF140E13),
      secondary: Color(0xFFB5A3B2),
      accent: Color(0xFFD2B07A),
      background: Color(0xFF140E13),
      surface: Color(0xFF1C141B),
      surfaceElevated: Color(0xFF251B23),
      textPrimary: Color(0xFFF1E8EF),
      textSecondary: Color(0xFFA898A5),
      border: Color(0xFF392B36),
      divider: Color(0xFF2C2129),
      success: Color(0xFF8CBF98),
      warning: Color(0xFFDCAA58),
      error: Color(0xFFE88C95),
      selected: Color(0xFF33222F),
      disabled: Color(0xFF54474F),
    ),
  );

  static const oceanBlue = MwbThemeDefinition(
    id: MwbThemeId.oceanBlue,
    light: MwbPalette(
      brightness: Brightness.light,
      primary: Color(0xFF2A7287),
      primaryStrong: Color(0xFF1F5D6F),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF5E7880),
      accent: Color(0xFFB9965E),
      background: Color(0xFFF1F5F6),
      surface: Color(0xFFF8FBFB),
      surfaceElevated: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF102229),
      textSecondary: Color(0xFF627880),
      border: Color(0xFFD8E3E6),
      divider: Color(0xFFE4ECEE),
      success: Color(0xFF3C7A5C),
      warning: Color(0xFFA0691A),
      error: Color(0xFFA53D3A),
      selected: Color(0xFFDEEDF0),
      disabled: Color(0xFFB9C7CB),
    ),
    dark: MwbPalette(
      brightness: Brightness.dark,
      primary: Color(0xFF86C4D3),
      primaryStrong: Color(0xFF72B6C7),
      onPrimary: Color(0xFF0B1417),
      secondary: Color(0xFF9CB3B9),
      accent: Color(0xFFD0B07A),
      background: Color(0xFF0B1417),
      surface: Color(0xFF111D21),
      surfaceElevated: Color(0xFF18272C),
      textPrimary: Color(0xFFE5F0F2),
      textSecondary: Color(0xFF93A9AF),
      border: Color(0xFF24363B),
      divider: Color(0xFF1C2B30),
      success: Color(0xFF85C4A2),
      warning: Color(0xFFDAAB58),
      error: Color(0xFFE88B87),
      selected: Color(0xFF17323A),
      disabled: Color(0xFF41545A),
    ),
  );

  static const roseBurgundy = MwbThemeDefinition(
    id: MwbThemeId.roseBurgundy,
    light: MwbPalette(
      brightness: Brightness.light,
      primary: Color(0xFF8A3443),
      primaryStrong: Color(0xFF732836),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF8A6E6E),
      accent: Color(0xFFB98C5A),
      background: Color(0xFFF8F1F0),
      surface: Color(0xFFFCF8F7),
      surfaceElevated: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF2A1417),
      textSecondary: Color(0xFF846C6E),
      border: Color(0xFFEADBD9),
      divider: Color(0xFFF0E5E3),
      success: Color(0xFF4B7A52),
      warning: Color(0xFFA2691C),
      error: Color(0xFFB0352F),
      selected: Color(0xFFF3E1E1),
      disabled: Color(0xFFCFBFBF),
    ),
    dark: MwbPalette(
      brightness: Brightness.dark,
      primary: Color(0xFFE29CA6),
      primaryStrong: Color(0xFFD88893),
      onPrimary: Color(0xFF160D0E),
      secondary: Color(0xFFBBA2A3),
      accent: Color(0xFFD5B07E),
      background: Color(0xFF160D0E),
      surface: Color(0xFF1F1415),
      surfaceElevated: Color(0xFF291B1C),
      textPrimary: Color(0xFFF4E8E8),
      textSecondary: Color(0xFFAE9799),
      border: Color(0xFF3D2A2C),
      divider: Color(0xFF302123),
      success: Color(0xFF8DC096),
      warning: Color(0xFFDCAA58),
      error: Color(0xFFF08F86),
      selected: Color(0xFF3B2226),
      disabled: Color(0xFF574649),
    ),
  );

  static const all = <MwbThemeDefinition>[
    classicGold,
    royalNavy,
    forestGreen,
    warmSand,
    royalPlum,
    oceanBlue,
    roseBurgundy,
  ];

  static MwbThemeDefinition byId(MwbThemeId id) => all.firstWhere((t) => t.id == id);
}
