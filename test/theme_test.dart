import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/core/constants/storage_keys.dart';
import 'package:my_word_bible/core/storage/key_value_store.dart';
import 'package:my_word_bible/core/theme/app_theme.dart';
import 'package:my_word_bible/core/theme/mwb_palette.dart';
import 'package:my_word_bible/core/theme/mwb_themes.dart';
import 'package:my_word_bible/data/repositories/preferences_repository.dart';
import 'package:my_word_bible/features/settings/application/appearance_controller.dart';

import 'helpers/test_app.dart';

double _luminance(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('Theme definitions', () {
    test('there are exactly seven themes and Classic Gold is the default', () {
      expect(MwbThemes.all, hasLength(7));
      expect(MwbThemeId.fromStorageKey(null), MwbThemeId.classicGold);
      expect(MwbThemeId.fromStorageKey('unknown'), MwbThemeId.classicGold);
    });

    test('Classic Gold uses the brand tokens', () {
      final p = MwbThemes.classicGold.light;
      expect(p.background, const Color(0xFFF9F2E7));
      expect(p.surface, const Color(0xFFFCF7EF));
      expect(p.primary, const Color(0xFFB98330));
      expect(p.primaryStrong, const Color(0xFFA3681F));
      expect(p.textPrimary, const Color(0xFF28170D));
      expect(p.textSecondary, const Color(0xFF7E7065));
      expect(p.border, const Color(0xFFEDE2CF));
    });

    for (final def in MwbThemes.all) {
      for (final b in Brightness.values) {
        test('${def.id.label} ${b.name}: complete, distinct and readable', () {
          final p = def.paletteFor(b);
          expect(p.brightness, b);
          // Body text must comfortably exceed WCAG AA on backgrounds and surfaces.
          expect(contrast(p.textPrimary, p.background), greaterThan(7));
          expect(contrast(p.textPrimary, p.surfaceElevated), greaterThan(7));
          expect(contrast(p.textSecondary, p.background), greaterThan(3.0));
          // Filled button label vs fill.
          expect(contrast(p.onPrimary, p.primaryStrong), greaterThan(4.0));

          final theme = AppThemeBuilder.build(def.id, b);
          final ext = theme.extension<MwbTheme>()!;
          expect(ext.themeId, def.id);
          expect(ext.colors, same(p));
          expect(theme.scaffoldBackgroundColor, p.background);
          expect(theme.brightness, b);
        });
      }
    }

    test('themes are not just a primary-colour swap', () {
      final backgrounds = MwbThemes.all.map((t) => t.light.background).toSet();
      final darkSurfaces = MwbThemes.all.map((t) => t.dark.surface).toSet();
      final primaries = MwbThemes.all.map((t) => t.light.primary).toSet();
      expect(backgrounds.length, 7);
      expect(darkSurfaces.length, 7);
      expect(primaries.length, 7);
    });

    test('highlight tones exist for both brightnesses', () {
      expect(MwbPalette.lightHighlightTones, hasLength(4));
      expect(MwbThemes.royalNavy.dark.highlightTones, MwbPalette.darkHighlightTones);
    });
  });

  group('Appearance persistence', () {
    test('theme and mode changes persist across app restarts', () async {
      final store = InMemoryKeyValueStore();
      final first = testContainer(store);
      expect(first.read(appearanceProvider).themeId, MwbThemeId.classicGold);
      expect(first.read(appearanceProvider).mode, AppearanceMode.system);

      await first.read(appearanceProvider.notifier).setTheme(MwbThemeId.royalPlum);
      await first.read(appearanceProvider.notifier).setMode(AppearanceMode.dark);
      expect(store.getString(StorageKeys.themeId), 'royal_plum');

      // Simulate a restart with a fresh container over the same storage.
      final second = testContainer(store);
      final restored = second.read(appearanceProvider);
      expect(restored.themeId, MwbThemeId.royalPlum);
      expect(restored.mode, AppearanceMode.dark);
      expect(restored.themeMode, ThemeMode.dark);
    });
  });
}
