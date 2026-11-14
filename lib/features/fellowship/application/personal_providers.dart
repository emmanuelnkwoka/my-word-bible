import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/app_providers.dart';
import '../../../data/local/personal_database.dart';
import '../../../data/models/daily_word.dart';
import '../../../data/models/personal_rhythm.dart';
import '../../../data/models/scripture_reference.dart';
import '../../../data/repositories/personal_repositories.dart';
import '../../bible/application/bible_providers.dart';
import 'journal_export.dart';

// F1: Personal Word Rhythm and Private Reflection Journal.
// Everything here is local; no provider in this file touches the network.

/// Platform secure storage for the database key (overridden in tests).
final personalKeyStoreProvider = Provider<PersonalKeyStore>((ref) => SecurePersonalKeyStore());

/// App-private support directory (Android: the app's `files` directory).
final personalStoreDirectoryProvider = FutureProvider<String>(
  (ref) async => (await getApplicationSupportDirectory()).path,
);

final personalStoreOpenerProvider = FutureProvider<PersonalStoreOpener>(
  (ref) async => PersonalStoreOpener(
    directory: await ref.watch(personalStoreDirectoryProvider.future),
    keys: ref.watch(personalKeyStoreProvider),
  ),
);

/// The encrypted personal store, opened once. Tests override this with
/// `PersonalDatabase.inMemory()`.
final personalStoreProvider = FutureProvider<PersonalStoreStatus>((ref) async {
  final opener = await ref.watch(personalStoreOpenerProvider.future);
  final status = await opener.open();
  if (status is PersonalStoreReady) ref.onDispose(status.database.close);
  return status;
});

/// Bumped after every write so dependent views re-read the store.
final personalRevisionProvider = NotifierProvider<PersonalRevision, int>(PersonalRevision.new);

class PersonalRevision extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

PersonalDatabase? _ready(Ref ref) => switch (ref.watch(personalStoreProvider).value) {
  PersonalStoreReady(:final database) => database,
  _ => null,
};

/// Null until the store is open (or if it cannot be opened).
final rhythmRepositoryProvider = Provider<RhythmRepository?>((ref) {
  final db = _ready(ref);
  return db == null ? null : SqlRhythmRepository(db, clock: ref.watch(clockProvider));
});

final journalRepositoryProvider = Provider<JournalRepository?>((ref) {
  final db = _ready(ref);
  return db == null ? null : SqlJournalRepository(db, clock: ref.watch(clockProvider));
});

// ── Rhythm views ─────────────────────────────────────────────────────────

final activeSessionProvider = Provider<ReadingSession?>((ref) {
  ref.watch(personalRevisionProvider);
  return ref.watch(rhythmRepositoryProvider)?.activeSession();
});

final currentWeekProvider = Provider<RhythmWeek?>((ref) {
  ref.watch(personalRevisionProvider);
  return ref.watch(rhythmRepositoryProvider)?.week(ref.watch(clockProvider)());
});

final completedReadingsProvider = Provider<List<ActivityRecord>>((ref) {
  ref.watch(personalRevisionProvider);
  return ref.watch(rhythmRepositoryProvider)?.completedReadings() ?? const [];
});

/// Day summaries for the month containing [month].
final rhythmMonthProvider = Provider.family<Map<String, RhythmDay>, DateTime>((ref, month) {
  ref.watch(personalRevisionProvider);
  final first = DateTime(month.year, month.month);
  final last = DateTime(month.year, month.month + 1, 0);
  return ref.watch(rhythmRepositoryProvider)?.daysBetween(dateKeyOf(first), dateKeyOf(last)) ?? const {};
});

final rhythmDayActivityProvider = Provider.family<List<ActivityRecord>, String>((ref, dateKey) {
  ref.watch(personalRevisionProvider);
  return ref.watch(rhythmRepositoryProvider)?.activityBetween(dateKey, dateKey) ?? const [];
});

/// Today's completion of a chapter, if the user completed it.
final chapterCompletionProvider = Provider.family<ActivityRecord?, ScriptureReference>((ref, chapter) {
  ref.watch(personalRevisionProvider);
  final today = dateKeyOf(ref.watch(clockProvider)());
  return ref.watch(rhythmRepositoryProvider)?.completionOn(chapter.chapterOnly, today);
});

// ── Journal views ────────────────────────────────────────────────────────

final journalSearchProvider = Provider.family<List<JournalEntry>, JournalQuery>((ref, query) {
  ref.watch(personalRevisionProvider);
  return ref.watch(journalRepositoryProvider)?.search(query) ?? const [];
});

final journalEntryProvider = Provider.family<JournalEntry?, String>((ref, id) {
  ref.watch(personalRevisionProvider);
  return ref.watch(journalRepositoryProvider)?.byId(id);
});

final reflectionsForReferenceProvider = Provider.family<List<JournalEntry>, ScriptureReference>((ref, reference) {
  ref.watch(personalRevisionProvider);
  return ref.watch(journalRepositoryProvider)?.forReference(reference) ?? const [];
});

final journalCountProvider = Provider<int>((ref) {
  ref.watch(personalRevisionProvider);
  return ref.watch(journalRepositoryProvider)?.count() ?? 0;
});

final journalBooksProvider = Provider<List<String>>((ref) {
  ref.watch(personalRevisionProvider);
  return ref.watch(journalRepositoryProvider)?.books() ?? const [];
});

/// Sharing an exported file through the system share sheet.
final journalExportServiceProvider = Provider<JournalExportService>((ref) => const NativeJournalExportService());

// ── Actions ──────────────────────────────────────────────────────────────

final personalActionsProvider = Provider<PersonalActions>(PersonalActions.new);

/// All writes go through here so views refresh consistently.
class PersonalActions {
  PersonalActions(this._ref);
  final Ref _ref;

  RhythmRepository get _rhythm =>
      _ref.read(rhythmRepositoryProvider) ?? (throw const PersonalDataException('Your private store is not available'));
  JournalRepository get _journal =>
      _ref.read(journalRepositoryProvider) ??
      (throw const PersonalDataException('Your private store is not available'));

  T _write<T>(T Function() action) {
    final result = action();
    _ref.read(personalRevisionProvider.notifier).bump();
    return result;
  }

  /// Canonical translation for a version id (personalised editions map to their source).
  String canonicalVersion(String versionId) => _ref.read(versionCatalogueProvider).sourceOf(versionId)?.id ?? versionId;

  ReadingSession startSession(
    ScriptureReference chapter, {
    required String versionId,
    required PersonalOrigin origin,
  }) => _write(() => _rhythm.startSession(chapter, versionId: canonicalVersion(versionId), origin: origin));

  void endSession(String id) => _write(() => _rhythm.endSession(id));

  CompletionResult completeReading(
    ScriptureReference chapter, {
    required String versionId,
    required PersonalOrigin origin,
    DateTime? openedAt,
  }) => _write(
    () => _rhythm.completeReading(chapter, versionId: canonicalVersion(versionId), origin: origin, openedAt: openedAt),
  );

  void removeCompletion(String activityId) => _write(() => _rhythm.removeCompletion(activityId));

  void clearReadingActivity() => _write(() => _rhythm.clearReadingActivity());

  /// Validates the reference against the canon **and** the installed
  /// translation before saving, so a reflection never points at a verse that
  /// does not exist.
  Future<JournalDraft> _checked(JournalDraft d) async {
    final ref = d.reference;
    if (ref == null) {
      return JournalDraft(title: d.title, body: d.body, source: d.source, dailyWordDate: d.dailyWordDate);
    }
    final canonical = validCanonicalReference(ref);
    final version = canonicalVersion(d.versionId ?? _ref.read(textVersionProvider).id);
    if (canonical.verseStart != null) {
      final verses = await _ref.read(bibleRepositoryProvider).chapter(version, canonical.bookId, canonical.chapter);
      final numbers = {
        for (final v in verses)
          if (!v.isOmitted) v.number,
      };
      final end = canonical.verseEnd ?? canonical.verseStart!;
      for (var n = canonical.verseStart!; n <= end; n++) {
        if (!numbers.contains(n)) throw const PersonalDataException('That verse is not in this translation');
      }
    }
    return JournalDraft(
      title: d.title,
      body: d.body,
      reference: canonical,
      versionId: version,
      source: d.source,
      dailyWordDate: d.dailyWordDate,
    );
  }

  Future<JournalEntry> createReflection(JournalDraft draft) async {
    final checked = await _checked(draft);
    return _write(() => _journal.create(checked));
  }

  Future<JournalEntry> updateReflection(String id, JournalDraft draft) async {
    final checked = await _checked(draft);
    return _write(() => _journal.update(id, checked));
  }

  void deleteReflection(String id) => _write(() => _journal.delete(id));

  void deleteAllReflections() => _write(() => _journal.deleteAll());

  /// After the user confirms: removes an unreadable store and starts afresh.
  Future<void> startNewPersonalStore() async {
    final opener = await _ref.read(personalStoreOpenerProvider.future);
    final current = _ref.read(personalStoreProvider).value;
    if (current is PersonalStoreReady) current.database.close();
    await opener.resetPersonalStore();
    _ref.invalidate(personalStoreProvider);
  }
}
