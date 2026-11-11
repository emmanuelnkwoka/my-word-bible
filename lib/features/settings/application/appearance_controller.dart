import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/theme/mwb_themes.dart';
import '../../../data/repositories/preferences_repository.dart';

@immutable
class AppearanceSettings {
  const AppearanceSettings({this.themeId = MwbThemeId.classicGold, this.mode = AppearanceMode.system});

  final MwbThemeId themeId;
  final AppearanceMode mode;

  ThemeMode get themeMode => switch (mode) {
    AppearanceMode.system => ThemeMode.system,
    AppearanceMode.light => ThemeMode.light,
    AppearanceMode.dark => ThemeMode.dark,
  };

  AppearanceSettings copyWith({MwbThemeId? themeId, AppearanceMode? mode}) =>
      AppearanceSettings(themeId: themeId ?? this.themeId, mode: mode ?? this.mode);
}

/// Active colour theme and light/dark/system mode. Changes apply immediately
/// and persist across restarts.
final appearanceProvider = NotifierProvider<AppearanceController, AppearanceSettings>(AppearanceController.new);

class AppearanceController extends Notifier<AppearanceSettings> {
  PreferencesRepository get _repo => ref.read(preferencesRepositoryProvider);

  @override
  AppearanceSettings build() {
    final repo = ref.watch(preferencesRepositoryProvider);
    return AppearanceSettings(themeId: repo.loadThemeId(), mode: repo.loadAppearanceMode());
  }

  Future<void> setTheme(MwbThemeId id) async {
    state = state.copyWith(themeId: id);
    await _repo.saveThemeId(id);
  }

  Future<void> setMode(AppearanceMode mode) async {
    state = state.copyWith(mode: mode);
    await _repo.saveAppearanceMode(mode);
  }
}
