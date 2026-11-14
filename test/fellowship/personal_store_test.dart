import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/core/constants/storage_keys.dart';
import 'package:my_word_bible/data/local/personal_database.dart';
import 'package:my_word_bible/data/models/personal_rhythm.dart';
import 'package:my_word_bible/data/models/scripture_reference.dart';
import 'package:my_word_bible/data/repositories/personal_repositories.dart';
import 'package:sqlite3/sqlite3.dart';

import 'f1_test_support.dart';

Uint8List _key(int seed) => Uint8List.fromList(List.generate(32, (i) => (i * 7 + seed) & 0xff));

void main() {
  group('Database encryption (real SQLCipher)', () {
    test('the bundled SQLite is SQLCipher', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.close);
      final v = db.select('PRAGMA cipher_version');
      expect(v, isNotEmpty);
      expect(v.first.values.first, contains('community'));
    });

    test('the file has no SQLite header and no readable reflection text', () {
      final path = '${tempDir()}/p.db';
      final store = PersonalDatabase.openEncrypted(path, _key(1));
      expect(store.encrypted, isTrue);
      SqlJournalRepository(store).create(const JournalDraft(title: 'Hospital', body: secretSentence));
      store.close();

      final bytes = File(path).readAsBytesSync();
      expect(String.fromCharCodes(bytes.take(15)), isNot('SQLite format 3'));
      expect(containsBytes(bytes, 'hospital results'), isFalse);
      expect(containsBytes(bytes, 'journal_entries'), isFalse, reason: 'even the schema is encrypted');
    });

    test('a wrong key cannot open it; the right key can', () {
      final path = '${tempDir()}/p.db';
      PersonalDatabase.openEncrypted(path, _key(1))
        ..db.execute(
          "INSERT INTO journal_entries(id, created_at, updated_at, body, source) VALUES ('a','t','t','x','independent')",
        )
        ..close();

      expect(
        () => PersonalDatabase.openEncrypted(path, _key(2)),
        throwsA(isA<PersonalStoreException>().having((e) => e.failure, 'failure', PersonalStoreFailure.wrongKey)),
      );
      final again = PersonalDatabase.openEncrypted(path, _key(1));
      expect(again.db.select('SELECT count(*) AS n FROM journal_entries').first['n'], 1);
      again.close();
    });

    test('opening without any key fails (not plain SQLite)', () {
      final path = '${tempDir()}/p.db';
      PersonalDatabase.openEncrypted(path, _key(1)).close();
      final plain = sqlite3.open(path);
      addTearDown(plain.close);
      expect(() => plain.select('SELECT * FROM sqlite_master'), throwsA(isA<SqliteException>()));
    });

    test('deleted rows are securely overwritten', () {
      final store = PersonalDatabase.openEncrypted('${tempDir()}/p.db', _key(3));
      addTearDown(store.close);
      expect(store.db.select('PRAGMA secure_delete').first.values.first, 1);
    });

    test('only 256-bit keys are accepted', () {
      expect(() => PersonalDatabase.openEncrypted('${tempDir()}/p.db', Uint8List(16)), throwsArgumentError);
    });
  });

  group('Encryption key handling', () {
    test('a 256-bit key is generated once, kept in secure storage and reused', () async {
      final dir = tempDir();
      final keys = InMemoryPersonalKeyStore();
      final first = await PersonalStoreOpener(directory: dir, keys: keys).open();
      expect(first, isA<PersonalStoreReady>());
      expect(keys.key, hasLength(32));
      expect(keys.writes, 1);
      (first as PersonalStoreReady).database.close();

      final second = await PersonalStoreOpener(directory: dir, keys: keys).open();
      expect(second, isA<PersonalStoreReady>());
      expect(keys.writes, 1, reason: 'the existing key is reused, never replaced');
      (second as PersonalStoreReady).database.close();
    });

    test('generated keys are random', () {
      final a = generatePersonalKey();
      final b = generatePersonalKey();
      expect(a, hasLength(32));
      expect(a, isNot(equals(b)));
    });

    test('if secure storage cannot be read nothing is created or replaced', () async {
      final dir = tempDir();
      final keys = InMemoryPersonalKeyStore()..failReads = true;
      final s = await PersonalStoreOpener(directory: dir, keys: keys).open();
      expect(s, isA<PersonalStoreUnavailable>());
      expect((s as PersonalStoreUnavailable).failure, PersonalStoreFailure.keyStoreUnavailable);
      expect(keys.writes, 0);
      expect(File('$dir/${PersonalDatabase.relativePath}').existsSync(), isFalse);
    });

    test('a lost key is reported and the encrypted file is left untouched', () async {
      final dir = tempDir();
      final keys = InMemoryPersonalKeyStore();
      final opener = PersonalStoreOpener(directory: dir, keys: keys);
      final s = await opener.open() as PersonalStoreReady;
      SqlJournalRepository(s.database).create(const JournalDraft(body: secretSentence));
      s.database.close();
      final before = File(opener.path).readAsBytesSync();

      keys.key = null; // e.g. Keystore reset or app data restored to another phone
      final lost = await opener.open();
      expect((lost as PersonalStoreUnavailable).failure, PersonalStoreFailure.keyLost);
      expect(lost.isUnrecoverable, isTrue);
      expect(keys.writes, 1, reason: 'no new key is written over a file that still exists');
      expect(File(opener.path).readAsBytesSync(), before);
    });

    test('a different key in storage is reported as unrecoverable, file untouched', () async {
      final dir = tempDir();
      final keys = InMemoryPersonalKeyStore();
      final opener = PersonalStoreOpener(directory: dir, keys: keys);
      (await opener.open() as PersonalStoreReady).database.close();
      final before = File(opener.path).readAsBytesSync();
      keys.key = _key(9);
      final s = await opener.open() as PersonalStoreUnavailable;
      expect(s.failure, PersonalStoreFailure.wrongKey);
      expect(File(opener.path).readAsBytesSync(), before);
    });

    test('starting again deletes the old file and key, then works', () async {
      final dir = tempDir();
      final keys = InMemoryPersonalKeyStore();
      final opener = PersonalStoreOpener(directory: dir, keys: keys);
      (await opener.open() as PersonalStoreReady).database.close();
      keys.key = null;
      expect(await opener.open(), isA<PersonalStoreUnavailable>());

      await opener.resetPersonalStore();
      expect(File(opener.path).existsSync(), isFalse);
      final fresh = await opener.open();
      expect(fresh, isA<PersonalStoreReady>());
      expect(SqlJournalRepository((fresh as PersonalStoreReady).database).count(), 0);
      fresh.database.close();
    });

    test('the key never goes to SharedPreferences', () {
      expect(StorageKeys.securePersonalDbKey, startsWith('mwb.secure.'));
      final source = File('lib/data/local/personal_database.dart').readAsStringSync();
      final imports = source.split('\n').where((l) => l.startsWith('import ')).join('\n');
      expect(imports, isNot(contains('shared_preferences')));
      expect(imports, isNot(contains('key_value_store')));
      expect(imports, contains('flutter_secure_storage'));
    });
  });

  group('Migration and rollback', () {
    test('a new database is created at the current schema', () {
      final s = PersonalDatabase.inMemory();
      addTearDown(s.close);
      expect(s.userVersion, PersonalDatabase.schemaVersion);
      final tables = {for (final r in s.db.select("SELECT name FROM sqlite_master WHERE type='table'")) r['name']};
      expect(tables, containsAll(['reading_sessions', 'activity_records', 'journal_entries']));
    });

    test('reopening does not re-run migrations or lose data', () {
      final path = '${tempDir()}/p.db';
      final a = PersonalDatabase.openEncrypted(path, _key(4));
      final e = SqlJournalRepository(a).create(const JournalDraft(body: 'kept'));
      a.close();
      final b = PersonalDatabase.openEncrypted(path, _key(4));
      expect(b.userVersion, 1);
      expect(SqlJournalRepository(b).byId(e.id)!.body, 'kept');
      b.close();
    });

    test('a future migration upgrades in place and keeps every record', () {
      final path = '${tempDir()}/p.db';
      final v1 = PersonalDatabase.openEncrypted(path, _key(5));
      final e = SqlJournalRepository(v1).create(
        const JournalDraft(
          body: 'before',
          reference: ScriptureReference(bookId: 'PSA', chapter: 23, verseStart: 1),
          versionId: 'KJV',
        ),
      );
      v1.close();
      final v2Steps = [
        ...personalMigrations,
        Migration(2, (db) => db.execute("ALTER TABLE journal_entries ADD COLUMN mood TEXT NOT NULL DEFAULT ''")),
      ];
      final v2 = PersonalDatabase.openEncrypted(path, _key(5), migrations: v2Steps);
      expect(v2.userVersion, 2);
      final row = v2.db.select('SELECT body, book_id, mood FROM journal_entries WHERE id = ?', [e.id]).first;
      expect(row['body'], 'before');
      expect(row['book_id'], 'PSA');
      expect(row['mood'], '');
      v2.close();
    });

    test('a failing migration is rolled back completely', () {
      final path = '${tempDir()}/p.db';
      PersonalDatabase.openEncrypted(path, _key(6)).close();
      final broken = [
        ...personalMigrations,
        Migration(2, (db) {
          db.execute('CREATE TABLE half_done(x)');
          throw StateError('simulated failure');
        }),
      ];
      expect(() => PersonalDatabase.openEncrypted(path, _key(6), migrations: broken), throwsStateError);
      final after = PersonalDatabase.openEncrypted(path, _key(6));
      expect(after.userVersion, 1);
      expect(after.db.select("SELECT name FROM sqlite_master WHERE name = 'half_done'"), isEmpty);
      after.close();
    });

    test('a database from a newer app version is not modified (downgrade safety)', () async {
      final dir = tempDir();
      final keys = InMemoryPersonalKeyStore();
      final opener = PersonalStoreOpener(directory: dir, keys: keys);
      final s = await opener.open() as PersonalStoreReady;
      s.database.db.execute('PRAGMA user_version = 99');
      s.database.close();
      final before = File(opener.path).readAsBytesSync();
      final again = await opener.open();
      expect((again as PersonalStoreUnavailable).failure, PersonalStoreFailure.newerSchema);
      expect(File(opener.path).readAsBytesSync(), before);
    });
  });

  group('Offline persistence', () {
    test('sessions, completions and reflections survive closing the app', () async {
      final dir = tempDir();
      final keys = InMemoryPersonalKeyStore();
      final opener = PersonalStoreOpener(directory: dir, keys: keys);
      var now = DateTime(2026, 11, 10, 7);
      final a = (await opener.open() as PersonalStoreReady).database;
      final rhythm = SqlRhythmRepository(a, clock: () => now);
      rhythm.startSession(
        const ScriptureReference(bookId: 'JHN', chapter: 3),
        versionId: 'KJV',
        origin: PersonalOrigin.rhythm,
      );
      now = now.add(const Duration(minutes: 9));
      rhythm.completeReading(
        const ScriptureReference(bookId: 'JHN', chapter: 3),
        versionId: 'KJV',
        origin: PersonalOrigin.reader,
      );
      rhythm.startSession(
        const ScriptureReference(bookId: 'JHN', chapter: 4),
        versionId: 'KJV',
        origin: PersonalOrigin.reader,
      );
      SqlJournalRepository(a, clock: () => now).create(const JournalDraft(body: 'offline words'));
      a.close();

      final b = (await opener.open() as PersonalStoreReady).database;
      final r2 = SqlRhythmRepository(b, clock: () => now);
      expect(r2.completedReadings().single.reference, const ScriptureReference(bookId: 'JHN', chapter: 3));
      expect(r2.activeSession()!.chapter, const ScriptureReference(bookId: 'JHN', chapter: 4));
      expect(SqlJournalRepository(b).search(const JournalQuery()).single.body, 'offline words');
      b.close();
    });
  });
}
