import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../core/constants/storage_keys.dart';

/// The encrypted on-device store for F1 personal data (reading rhythm and
/// private reflections).
///
/// * The file is a SQLCipher database (AES-256, the SQLCipher build bundled by
///   `package:sqlite3`, selected in `pubspec.yaml` under `hooks`).
/// * The 256-bit key is generated with [Random.secure] and kept only in
///   platform secure storage (Android Keystore / iOS Keychain). It is never
///   written to SharedPreferences, logs or the database itself.
/// * Nothing in this store is synchronised to any server.
class PersonalDatabase {
  PersonalDatabase._(this.db, {required this.encrypted, this.path});

  /// Current schema version (`PRAGMA user_version`).
  static const schemaVersion = 1;

  /// Relative location under the application support directory. Excluded
  /// from Android cloud backup (`res/xml/mwb_backup_rules.xml`,
  /// `res/xml/mwb_data_extraction_rules.xml`) because the key cannot travel
  /// with it.
  static const relativePath = 'mwb_personal/personal.db';

  final Database db;

  /// True when the file is SQLCipher-encrypted. In-memory test databases are not.
  final bool encrypted;
  final String? path;

  bool _closed = false;
  bool get isClosed => _closed;

  /// Opens (or creates) an encrypted database at [path] with a raw 32-byte key.
  ///
  /// Throws [PersonalStoreException] with [PersonalStoreFailure.wrongKey] when
  /// the key does not decrypt the file, [PersonalStoreFailure.encryptionUnavailable]
  /// when the SQLite library has no cipher support (the database would
  /// otherwise silently be written in plain text), and
  /// [PersonalStoreFailure.newerSchema] when the file was written by a newer
  /// app version (it is left untouched).
  static PersonalDatabase openEncrypted(String path, Uint8List key, {List<Migration>? migrations}) {
    if (key.length != 32) throw ArgumentError('A 256-bit key is required');
    final db = sqlite3.open(path);
    try {
      // SQLCipher reports decryption failures (never contents) on stderr; keep it quiet.
      try {
        db.execute('PRAGMA cipher_log_level = NONE');
      } on SqliteException {
        // Older builds: ignore.
      }
      final cipher = db.select('PRAGMA cipher_version');
      if (cipher.isEmpty || (cipher.first.values.first as String?)?.isEmpty != false) {
        throw const PersonalStoreException(PersonalStoreFailure.encryptionUnavailable);
      }
      db.execute('PRAGMA key = "x\'${_hex(key)}\'"');
      try {
        db.select('SELECT count(*) FROM sqlite_master');
      } on SqliteException catch (e) {
        // SQLITE_NOTADB (26): wrong key, or not a database at all.
        if (e.resultCode == 26 || e.extendedResultCode == 26) {
          throw const PersonalStoreException(PersonalStoreFailure.wrongKey);
        }
        rethrow;
      }
      final out = PersonalDatabase._(db, encrypted: true, path: path);
      out._configure();
      out.migrate(migrations ?? personalMigrations);
      return out;
    } catch (_) {
      db.close();
      rethrow;
    }
  }

  /// Unencrypted in-memory database for tests and previews.
  static PersonalDatabase inMemory({List<Migration>? migrations}) {
    final out = PersonalDatabase._(sqlite3.openInMemory(), encrypted: false);
    out._configure();
    out.migrate(migrations ?? personalMigrations);
    return out;
  }

  void _configure() {
    db.execute('PRAGMA foreign_keys = ON');
    // Deleted rows are overwritten with zeros, not just unlinked.
    db.execute('PRAGMA secure_delete = ON');
  }

  int get userVersion => db.select('PRAGMA user_version').first.values.first as int;

  /// Applies pending migrations, each in its own transaction. A failing step
  /// is rolled back completely and the version is left unchanged.
  void migrate(List<Migration> migrations) {
    final current = userVersion;
    final target = migrations.isEmpty ? 0 : migrations.map((m) => m.toVersion).reduce(max);
    if (current > target) {
      throw PersonalStoreException(PersonalStoreFailure.newerSchema, 'Schema $current is newer than $target');
    }
    for (final m
        in migrations.where((m) => m.toVersion > current).toList()
          ..sort((a, b) => a.toVersion.compareTo(b.toVersion))) {
      transaction(() {
        m.apply(db);
        db.execute('PRAGMA user_version = ${m.toVersion}');
      });
    }
  }

  /// Runs [action] atomically.
  T transaction<T>(T Function() action) {
    db.execute('BEGIN IMMEDIATE');
    try {
      final result = action();
      db.execute('COMMIT');
      return result;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Reclaims free pages so deleted content does not linger in the file.
  void vacuum() => db.execute('VACUUM');

  void close() {
    if (_closed) return;
    _closed = true;
    db.close();
  }

  static String _hex(Uint8List bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// One schema step.
class Migration {
  const Migration(this.toVersion, this.apply);
  final int toVersion;
  final void Function(Database db) apply;
}

/// The F1 schema. Steps are append-only: never edit a released step.
final personalMigrations = <Migration>[
  Migration(1, (db) {
    db.execute('''
      CREATE TABLE reading_sessions(
        id TEXT PRIMARY KEY NOT NULL,
        book_id TEXT NOT NULL,
        chapter INTEGER NOT NULL CHECK (chapter > 0),
        version_id TEXT NOT NULL,
        origin TEXT NOT NULL,
        status TEXT NOT NULL CHECK (status IN ('active', 'completed', 'ended')),
        started_at TEXT NOT NULL,
        finished_at TEXT
      )''');
    db.execute('''
      CREATE TABLE activity_records(
        id TEXT PRIMARY KEY NOT NULL,
        kind TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        local_date TEXT NOT NULL,
        tz_offset_min INTEGER NOT NULL,
        book_id TEXT,
        chapter INTEGER,
        verse_start INTEGER,
        verse_end INTEGER,
        version_id TEXT,
        session_id TEXT,
        journal_id TEXT,
        dedupe_key TEXT NOT NULL UNIQUE
      )''');
    db.execute('CREATE INDEX activity_by_date ON activity_records(local_date)');
    db.execute('''
      CREATE TABLE journal_entries(
        id TEXT PRIMARY KEY NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        body TEXT NOT NULL,
        book_id TEXT,
        chapter INTEGER,
        verse_start INTEGER,
        verse_end INTEGER,
        version_id TEXT,
        source TEXT NOT NULL,
        daily_word_date TEXT,
        CHECK ((book_id IS NULL) = (chapter IS NULL))
      )''');
    db.execute('CREATE INDEX journal_by_created ON journal_entries(created_at)');
  }),
];

enum PersonalStoreFailure {
  /// The key in secure storage does not open the file.
  wrongKey,

  /// The database file exists but its key is gone (e.g. app data restored
  /// onto a new phone, or the Keystore was reset). The contents cannot be
  /// recovered by anyone.
  keyLost,

  /// Secure storage could not be read right now. Nothing is changed; try later.
  keyStoreUnavailable,

  /// The SQLite library has no encryption support. The app refuses to store
  /// reflections unencrypted.
  encryptionUnavailable,

  /// Written by a newer app version; left untouched.
  newerSchema,

  /// Any other I/O or database error.
  other,
}

class PersonalStoreException implements Exception {
  const PersonalStoreException(this.failure, [this.detail]);
  final PersonalStoreFailure failure;

  /// Technical detail for diagnostics. Never contains user content.
  final String? detail;

  @override
  String toString() => 'PersonalStoreException(${failure.name})';
}

// ---------------------------------------------------------------------------
// Key storage
// ---------------------------------------------------------------------------

/// Holds the database key in platform secure storage.
abstract interface class PersonalKeyStore {
  /// The stored key, or null if none exists. Throws [PersonalStoreException]
  /// ([PersonalStoreFailure.keyStoreUnavailable]) if secure storage cannot be
  /// read, so a temporary failure is never mistaken for "no key".
  Future<Uint8List?> read();
  Future<void> write(Uint8List key);
  Future<void> delete();
}

class SecurePersonalKeyStore implements PersonalKeyStore {
  SecurePersonalKeyStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<Uint8List?> read() async {
    final String? value;
    try {
      value = await _storage.read(key: StorageKeys.securePersonalDbKey);
    } catch (e) {
      throw PersonalStoreException(PersonalStoreFailure.keyStoreUnavailable, e.runtimeType.toString());
    }
    if (value == null || value.isEmpty) return null;
    try {
      final bytes = base64Decode(value);
      return bytes.length == 32 ? bytes : null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(Uint8List key) => _storage.write(key: StorageKeys.securePersonalDbKey, value: base64Encode(key));

  @override
  Future<void> delete() => _storage.delete(key: StorageKeys.securePersonalDbKey);
}

class InMemoryPersonalKeyStore implements PersonalKeyStore {
  InMemoryPersonalKeyStore([this.key]);
  Uint8List? key;
  bool failReads = false;
  int writes = 0;

  @override
  Future<Uint8List?> read() async {
    if (failReads) throw const PersonalStoreException(PersonalStoreFailure.keyStoreUnavailable);
    return key;
  }

  @override
  Future<void> write(Uint8List key) async {
    writes++;
    this.key = Uint8List.fromList(key);
  }

  @override
  Future<void> delete() async => key = null;
}

/// 32 bytes from the platform CSPRNG.
Uint8List generatePersonalKey([Random? random]) {
  final r = random ?? Random.secure();
  return Uint8List.fromList(List<int>.generate(32, (_) => r.nextInt(256)));
}

// ---------------------------------------------------------------------------
// Opening
// ---------------------------------------------------------------------------

/// Result of trying to open the personal store.
sealed class PersonalStoreStatus {
  const PersonalStoreStatus();
}

class PersonalStoreReady extends PersonalStoreStatus {
  const PersonalStoreReady(this.database);
  final PersonalDatabase database;
}

class PersonalStoreUnavailable extends PersonalStoreStatus {
  const PersonalStoreUnavailable(this.failure);
  final PersonalStoreFailure failure;

  /// The file exists but can never be decrypted again.
  bool get isUnrecoverable => failure == PersonalStoreFailure.keyLost || failure == PersonalStoreFailure.wrongKey;
}

/// Opens the encrypted store in [directory], creating the key on first use.
///
/// Safety rules:
/// * A key is only generated when **no database file exists**. If a file
///   exists without a usable key, the file is left untouched and the status
///   says so ([PersonalStoreFailure.keyLost]); the user decides whether to
///   start again ([resetPersonalStore]).
/// * If secure storage cannot be read, nothing is created or deleted.
class PersonalStoreOpener {
  PersonalStoreOpener({required this.directory, required this.keys});

  final String directory;
  final PersonalKeyStore keys;

  String get path => '$directory/${PersonalDatabase.relativePath}';

  Future<PersonalStoreStatus> open() async {
    try {
      final file = File(path);
      final Uint8List? existing;
      try {
        existing = await keys.read();
      } on PersonalStoreException catch (e) {
        return PersonalStoreUnavailable(e.failure);
      }
      var key = existing;
      if (key == null) {
        if (file.existsSync() && file.lengthSync() > 0) {
          return const PersonalStoreUnavailable(PersonalStoreFailure.keyLost);
        }
        key = generatePersonalKey();
        await keys.write(key);
        // Read back: proceed only if the key really persisted.
        final check = await keys.read();
        if (check == null || !_equal(check, key)) {
          return const PersonalStoreUnavailable(PersonalStoreFailure.keyStoreUnavailable);
        }
      }
      file.parent.createSync(recursive: true);
      return PersonalStoreReady(PersonalDatabase.openEncrypted(path, key));
    } on PersonalStoreException catch (e) {
      return PersonalStoreUnavailable(e.failure);
    } catch (_) {
      return const PersonalStoreUnavailable(PersonalStoreFailure.other);
    }
  }

  /// Permanently removes the database (and SQLite side files) and its key.
  /// Used only after the user confirms starting a new journal.
  Future<void> resetPersonalStore() async {
    for (final suffix in const ['', '-journal', '-wal', '-shm']) {
      final f = File('$path$suffix');
      if (f.existsSync()) f.deleteSync();
    }
    await keys.delete();
  }

  static bool _equal(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
