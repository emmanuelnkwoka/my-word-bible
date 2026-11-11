import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Simple local key-value persistence abstraction.
///
/// Reads are synchronous (values are cached in memory after start-up) and
/// writes are asynchronous. Foundation V1 stores preferences and personal
/// library data here as JSON; the interface lets a database-backed store
/// (e.g. SQLite/Drift) replace it later without touching features.
abstract interface class KeyValueStore {
  String? getString(String key);
  Future<void> setString(String key, String value);
  bool? getBool(String key);
  Future<void> setBool(String key, bool value);
  Future<void> remove(String key);
  Future<void> clearAll();
}

extension KeyValueStoreJson on KeyValueStore {
  Object? readJson(String key) {
    final raw = getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null; // Corrupt value: treat as absent rather than crash.
    }
  }

  Future<void> writeJson(String key, Object? value) => setString(key, jsonEncode(value));

  List<T> readList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final data = readJson(key);
    if (data is! List) return <T>[];
    final out = <T>[];
    for (final item in data) {
      if (item is Map<String, dynamic>) {
        try {
          out.add(fromJson(item));
        } catch (_) {
          // Skip malformed entries instead of losing the whole list.
        }
      }
    }
    return out;
  }

  Future<void> writeList<T>(String key, List<T> items, Map<String, dynamic> Function(T) toJson) =>
      writeJson(key, items.map(toJson).toList());
}

/// [KeyValueStore] backed by SharedPreferences.
class SharedPreferencesStore implements KeyValueStore {
  SharedPreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<SharedPreferencesStore> create() async => SharedPreferencesStore(await SharedPreferences.getInstance());

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) => _prefs.setString(key, value);

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);

  @override
  Future<void> clearAll() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith('mwb.')).toList();
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }
}

/// In-memory store for tests and previews.
class InMemoryKeyValueStore implements KeyValueStore {
  InMemoryKeyValueStore([Map<String, Object>? initial]) : _data = {...?initial};

  final Map<String, Object> _data;

  Map<String, Object> get snapshot => Map.unmodifiable(_data);

  @override
  String? getString(String key) => _data[key] as String?;

  @override
  Future<void> setString(String key, String value) async => _data[key] = value;

  @override
  bool? getBool(String key) => _data[key] as bool?;

  @override
  Future<void> setBool(String key, bool value) async => _data[key] = value;

  @override
  Future<void> remove(String key) async => _data.remove(key);

  @override
  Future<void> clearAll() async => _data.clear();
}
