import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../data/models/bible.dart';
import '../../../data/models/daily_word.dart';
import '../../../data/models/intelligence.dart';
import '../../../data/models/scripture_reference.dart';
import '../../../data/repositories/daily_word_repository.dart';
import '../../../data/repositories/intelligence_repository.dart';
import '../../bible/application/bible_providers.dart';
import '../../intelligence/application/intelligence_providers.dart';
import '../../library/application/library_controllers.dart';
import '../../personalisation/application/scripture_presentation.dart';
import '../../profile/application/profile_controllers.dart';
import '../domain/adaptive_relevance_scorer.dart';
import '../domain/daily_word_engine.dart';
import 'relevance_signals.dart';

export 'relevance_signals.dart';

final dailyWordPersistenceProvider = Provider<LocalDailyWordPersistence>(
  (ref) => LocalDailyWordPersistence(ref.watch(keyValueStoreProvider)),
);

final dailyWordCatalogueProvider = FutureProvider<DailyWordCatalogue>(
  (ref) => ref.watch(dailyWordRepositoryProvider).catalogue(),
);

final dailyWordEngineProvider = FutureProvider<DailyWordEngine>((ref) async {
  final catalogue = await ref.watch(dailyWordCatalogueProvider.future);
  final corpus = await ref.watch(intelligenceCorpusProvider.future);
  return DailyWordEngine(catalogue: catalogue, facts: CandidateFacts.build(catalogue, corpus));
});

// ── Settings ────────────────────────────────────────────────────────────

final dailyWordSettingsProvider = NotifierProvider<DailyWordSettingsController, DailyWordSettings>(
  DailyWordSettingsController.new,
);

class DailyWordSettingsController extends Notifier<DailyWordSettings> {
  @override
  DailyWordSettings build() => ref.watch(dailyWordPersistenceProvider).loadSettings();

  Future<void> setAdaptive(bool enabled) async {
    state = state.copyWith(adaptiveEnabled: enabled);
    await ref.read(dailyWordPersistenceProvider).saveSettings(state);
  }

  /// Forgets local signals. The library itself (saves, notes, reading
  /// history) is not deleted; it simply stops influencing the Daily Word.
  Future<void> clearSignals() async {
    state = state.copyWith(signalsClearedAt: ref.read(clockProvider)());
    await ref.read(dailyWordPersistenceProvider).saveSettings(state);
    await ref.read(relevanceSignalsProvider.notifier).clear();
  }
}

// ── History ─────────────────────────────────────────────────────────────

final dailyWordHistoryProvider = NotifierProvider<DailyWordHistoryController, List<DailyWordHistoryEntry>>(
  DailyWordHistoryController.new,
);

/// Delivered Daily Words, newest first, at most one per date.
class DailyWordHistoryController extends Notifier<List<DailyWordHistoryEntry>> {
  static const maxEntries = 800;

  @override
  List<DailyWordHistoryEntry> build() {
    final byDate = <String, DailyWordHistoryEntry>{};
    for (final e in ref.watch(dailyWordPersistenceProvider).loadHistory()) {
      byDate.putIfAbsent(e.dateKey, () => e);
    }
    return _sorted(byDate.values);
  }

  static List<DailyWordHistoryEntry> _sorted(Iterable<DailyWordHistoryEntry> e) =>
      List.unmodifiable(e.toList()..sort((a, b) => b.dateKey.compareTo(a.dateKey)));

  DailyWordHistoryEntry? entryFor(String dateKey) => state.where((e) => e.dateKey == dateKey).firstOrNull;

  Future<void> _commit(List<DailyWordHistoryEntry> next) async {
    state = _sorted(next.take(maxEntries));
    await ref.read(dailyWordPersistenceProvider).saveHistory(state);
  }

  /// Records [entry] unless that date already has a Daily Word; returns the
  /// entry that is kept. Earlier deliveries are never overwritten.
  Future<DailyWordHistoryEntry> deliver(DailyWordHistoryEntry entry) async {
    final existing = entryFor(entry.dateKey);
    if (existing != null) return existing;
    await _commit([entry, ...state]);
    return entry;
  }

  Future<void> _update(String dateKey, DailyWordHistoryEntry Function(DailyWordHistoryEntry) f) async {
    if (entryFor(dateKey) == null) return;
    await _commit([for (final e in state) e.dateKey == dateKey ? f(e) : e]);
  }

  Future<bool> toggleFavourite(String dateKey) async {
    final e = entryFor(dateKey);
    if (e == null) return false;
    await _update(dateKey, (x) => x.copyWith(favourite: !x.favourite));
    return !e.favourite;
  }

  Future<void> markOpened(String dateKey, DateTime at) async {
    final e = entryFor(dateKey);
    if (e == null || e.openedAt != null) return;
    await _update(dateKey, (x) => x.copyWith(openedAt: at));
  }

  Future<void> clear() => _commit(const []);
}

// ── Delivery ────────────────────────────────────────────────────────────

/// The Daily Word for a calendar date (`yyyy-mm-dd`). The first request for
/// a date chooses and stores it; every later request returns the stored
/// entry, so reopening the app or recording new signals never changes it.
final dailyWordForDateProvider = FutureProvider.family<DailyWordHistoryEntry, String>((ref, dateKey) async {
  final stored = ref.read(dailyWordHistoryProvider.notifier).entryFor(dateKey);
  if (stored != null) return stored;

  final engine = await ref.watch(dailyWordEngineProvider.future);
  final settings = ref.read(dailyWordSettingsProvider);
  final history = ref.read(dailyWordHistoryProvider);
  final now = ref.read(clockProvider)();
  final profile = settings.adaptiveEnabled
      ? buildRelevanceProfile(
          now: now,
          interestIds: ref.read(interestsProvider),
          signals: ref.read(relevanceSignalsProvider),
          reading: ref.read(readingHistoryProvider),
          saved: ref.read(savedScriptureProvider),
          highlights: ref.read(highlightsProvider),
          notes: ref.read(notesProvider),
          history: history,
          clearedAt: settings.signalsClearedAt,
        )
      : null;
  final decision = engine.select(date: dateFromKey(dateKey), history: history, profile: profile);
  final c = decision.candidate;
  return ref
      .read(dailyWordHistoryProvider.notifier)
      .deliver(
        DailyWordHistoryEntry(
          dateKey: dateKey,
          candidateId: c.id,
          reference: c.reference,
          versionId: ref.read(textVersionProvider).id,
          category: c.category,
          heading: c.heading,
          summary: decision.summary,
          reasons: decision.reasons,
          adaptive: decision.adaptive,
          scheduleVersion: engine.catalogue.scheduleVersion,
          scheduledCandidateId: decision.scheduled.id,
          deliveredAt: now,
        ),
      );
});

/// Today's date key, from the app clock.
final todayKeyProvider = Provider<String>((ref) => dateKeyOf(ref.watch(clockProvider)()));

// ── Detail ──────────────────────────────────────────────────────────────

@immutable
class RelatedScripture {
  const RelatedScripture({required this.reference, required this.label, this.text, this.explanation = ''});
  final ScriptureReference reference;

  /// Relationship type or source, e.g. "Similar theme".
  final String label;
  final String? text;
  final String explanation;
}

/// Everything the Daily Word screen shows for one delivered word.
@immutable
class DailyWordDetail {
  const DailyWordDetail({
    required this.entry,
    required this.candidate,
    required this.version,
    required this.verses,
    required this.passageText,
    required this.isPersonalised,
    required this.presentation,
    required this.surrounding,
    this.context,
    this.promises = const [],
    this.identityThemes = const [],
    this.commands = const [],
    this.worshipThemes = const [],
    this.situations = const [],
    this.related = const [],
  });

  final DailyWordHistoryEntry entry;
  final DailyWordCandidate? candidate;
  final BibleVersionInfo version;
  final List<Verse> verses;

  /// The passage as shown (an approved MWB rendering when one exists).
  final String passageText;
  final bool isPersonalised;

  /// Mode A / B / C presentation (title, rendered text, preview flag).
  final ScripturePresentation presentation;

  /// The chapter around the passage (a few verses either side).
  final List<Verse> surrounding;
  final IntelContext? context;
  final List<IntelPromise> promises;
  final List<IdentityTheme> identityThemes;
  final List<IntelCommand> commands;
  final List<WorshipTheme> worshipThemes;
  final List<LifeSituation> situations;
  final List<RelatedScripture> related;
}

final dailyWordDetailProvider = FutureProvider.family<DailyWordDetail, String>((ref, dateKey) async {
  final DailyWordHistoryEntry entry =
      ref.watch(dailyWordHistoryProvider.select((h) => h.where((e) => e.dateKey == dateKey).firstOrNull)) ??
      await ref.watch(dailyWordForDateProvider(dateKey).future);
  final catalogue = await ref.watch(dailyWordCatalogueProvider.future);
  final corpus = await ref.watch(intelligenceCorpusProvider.future);
  final bible = ref.watch(bibleRepositoryProvider);
  final source = ref.watch(textVersionProvider);
  final r = entry.reference;

  final passage = await bible.passage(source.id, r);
  final presentation = await ref.watch(
    scripturePresentationProvider(
      PresentationRequest(r, heading: entry.heading, fallbackTitle: dailyWordFallbackTitle),
    ).future,
  );
  final chapter = await bible.chapter(source.id, r.bookId, r.chapter);
  final first = (r.verseStart ?? 1) - 3;
  final last = (r.verseEnd ?? r.verseStart ?? 1) + 3;
  final surrounding = chapter.where((v) => v.number >= first && v.number <= last && !v.isOmitted).toList();

  bool cites(IntelRecord x) => x.references.any((y) => referencesOverlap(y, r));
  Future<String?> textOf(ScriptureReference x) async {
    try {
      return (await bible.passage(source.id, x)).text;
    } catch (_) {
      return null;
    }
  }

  final related = <RelatedScripture>[];
  final seen = <String>{r.key};
  for (final v in corpus.relationshipsFor(r)) {
    if (!seen.add(v.other.key)) continue;
    related.add(
      RelatedScripture(
        reference: v.other,
        label: v.relationship.type.label,
        text: await textOf(v.other),
        explanation: v.relationship.explanation,
      ),
    );
  }
  final promises = corpus.promises.where(cites).toList();
  final situations = corpus.situations.where(cites).toList();
  for (final s in situations) {
    for (final x in s.references) {
      if (related.length >= 8 || !seen.add(x.key)) continue;
      related.add(RelatedScripture(reference: x, label: 'Also for “${s.name}”', text: await textOf(x)));
    }
  }

  return DailyWordDetail(
    entry: entry,
    candidate: catalogue.candidate(entry.candidateId),
    version: source,
    verses: passage.verses,
    passageText: presentation.text,
    isPersonalised: presentation.mode == ScriptureMode.nameInText,
    presentation: presentation,
    surrounding: surrounding,
    context: corpus.contextsFor(r).firstOrNull,
    promises: promises,
    identityThemes: corpus.identityThemes.where(cites).toList(),
    commands: corpus.commands.where(cites).toList(),
    worshipThemes: corpus.worshipThemes.where(cites).toList(),
    situations: situations,
    related: related,
  );
});
