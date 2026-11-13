import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/constants/storage_keys.dart';
import '../../core/errors/app_failure.dart';
import '../../core/storage/key_value_store.dart';
import '../models/daily_word.dart';
import '../models/intelligence.dart' show IntelFormatException;
import 'bible_repository.dart' show AssetLoader;

/// The bundled Daily Word candidates and annual schedule.
abstract interface class DailyWordRepository {
  Future<DailyWordCatalogue> catalogue();
}

class AssetDailyWordRepository implements DailyWordRepository {
  AssetDailyWordRepository({AssetLoader? loader}) : _loader = loader ?? rootBundle.loadString;

  static const candidatesPath = 'assets/daily/candidates.json';
  static const schedulePath = 'assets/daily/schedule.json';

  final AssetLoader _loader;
  Future<DailyWordCatalogue>? _catalogue;

  @override
  Future<DailyWordCatalogue> catalogue() => _catalogue ??= _load();

  Future<DailyWordCatalogue> _load() async {
    try {
      final candidates = jsonDecode(await _loader(candidatesPath)) as Map<String, dynamic>;
      final schedule = jsonDecode(await _loader(schedulePath)) as Map<String, dynamic>;
      return decodeDailyWordCatalogue(candidates, schedule);
    } on IntelFormatException catch (e) {
      _catalogue = null;
      throw UnknownFailure('The Daily Word schedule is invalid: ${e.message}');
    } catch (_) {
      _catalogue = null;
      throw const UnknownFailure('The Daily Word schedule could not be opened.');
    }
  }
}

/// Daily Word history and settings, stored on the device only. Relevance
/// signals are kept by [RelevanceSignalsController].
class LocalDailyWordPersistence {
  LocalDailyWordPersistence(this._store);

  final KeyValueStore _store;

  List<DailyWordHistoryEntry> loadHistory() =>
      _store.readList(StorageKeys.dailyWordHistory, (j) => DailyWordHistoryEntry.fromJson(j));

  Future<void> saveHistory(List<DailyWordHistoryEntry> entries) =>
      _store.writeList(StorageKeys.dailyWordHistory, entries, (e) => e.toJson());

  DailyWordSettings loadSettings() {
    final j = _store.readJson(StorageKeys.dailyWordSettings);
    return j is Map<String, dynamic> ? DailyWordSettings.fromJson(j) : const DailyWordSettings();
  }

  Future<void> saveSettings(DailyWordSettings s) => _store.writeJson(StorageKeys.dailyWordSettings, s.toJson());
}
