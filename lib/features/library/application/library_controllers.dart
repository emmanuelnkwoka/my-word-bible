import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../data/models/content.dart';
import '../../../data/models/library_items.dart';
import '../../../data/models/scripture_reference.dart';
import '../../../data/repositories/library_repository.dart';

/// Base for library lists: synchronous load, persist on every change.
abstract class _PersistedList<T> extends Notifier<List<T>> {
  ListStore<T> storeOf(LibraryRepository repo);

  ListStore<T> get _store => storeOf(ref.read(libraryRepositoryProvider));

  @override
  List<T> build() => storeOf(ref.watch(libraryRepositoryProvider)).load();

  Future<void> commit(List<T> next) async {
    state = List.unmodifiable(next);
    await _store.save(next);
  }

  Future<void> clear() => commit(const []);
}

String _newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

// ── Bookmarks ───────────────────────────────────────────────────────────

final bookmarksProvider = NotifierProvider<BookmarksController, List<Bookmark>>(BookmarksController.new);

class BookmarksController extends _PersistedList<Bookmark> {
  @override
  ListStore<Bookmark> storeOf(LibraryRepository repo) => repo.bookmarks;

  bool isBookmarked(ScriptureReference ref) => state.any((b) => b.reference == ref);

  Future<void> add(ScriptureReference ref, {String versionId = 'KJV'}) async {
    if (isBookmarked(ref)) return;
    await commit([Bookmark(reference: ref, versionId: versionId, createdAt: DateTime.now()), ...state]);
  }

  Future<void> remove(ScriptureReference ref) => commit(state.where((b) => b.reference != ref).toList());

  Future<bool> toggle(ScriptureReference ref, {String versionId = 'KJV'}) async {
    if (isBookmarked(ref)) {
      await remove(ref);
      return false;
    }
    await add(ref, versionId: versionId);
    return true;
  }
}

// ── Highlights ──────────────────────────────────────────────────────────

final highlightsProvider = NotifierProvider<HighlightsController, List<Highlight>>(HighlightsController.new);

class HighlightsController extends _PersistedList<Highlight> {
  @override
  ListStore<Highlight> storeOf(LibraryRepository repo) => repo.highlights;

  Future<void> setTone(Iterable<ScriptureReference> verses, HighlightTone tone) {
    final keys = verses.map((v) => v.key).toSet();
    final now = DateTime.now();
    return commit([
      ...verses.map((v) => Highlight(reference: v, tone: tone, createdAt: now)),
      ...state.where((h) => !keys.contains(h.reference.key)),
    ]);
  }

  Future<void> removeAll(Iterable<ScriptureReference> verses) {
    final keys = verses.map((v) => v.key).toSet();
    return commit(state.where((h) => !keys.contains(h.reference.key)).toList());
  }
}

/// Highlight lookup for one chapter: verse number → tone.
final chapterHighlightsProvider = Provider.family<Map<int, HighlightTone>, ScriptureReference>((ref, chapter) {
  final all = ref.watch(highlightsProvider);
  return {
    for (final h in all)
      if (h.reference.bookId == chapter.bookId && h.reference.chapter == chapter.chapter)
        h.reference.verseStart!: h.tone,
  };
});

// ── Notes ───────────────────────────────────────────────────────────────

final notesProvider = NotifierProvider<NotesController, List<VerseNote>>(NotesController.new);

class NotesController extends _PersistedList<VerseNote> {
  @override
  ListStore<VerseNote> storeOf(LibraryRepository repo) => repo.notes;

  Future<VerseNote> addNote(ScriptureReference ref, String text) async {
    final now = DateTime.now();
    final note = VerseNote(id: _newId(), reference: ref, text: text.trim(), createdAt: now, updatedAt: now);
    await commit([note, ...state]);
    return note;
  }

  Future<void> updateNote(String id, String text) =>
      commit([for (final n in state) n.id == id ? n.copyWith(text: text.trim(), updatedAt: DateTime.now()) : n]);

  Future<void> deleteNote(String id) => commit(state.where((n) => n.id != id).toList());
}

/// Verses in a chapter that carry at least one note.
final chapterNotesProvider = Provider.family<Set<int>, ScriptureReference>((ref, chapter) {
  final notes = ref.watch(notesProvider);
  return {
    for (final n in notes)
      if (n.reference.bookId == chapter.bookId &&
          n.reference.chapter == chapter.chapter &&
          n.reference.verseStart != null)
        n.reference.verseStart!,
  };
});

// ── Saved Scripture ─────────────────────────────────────────────────────

final savedScriptureProvider = NotifierProvider<SavedScriptureController, List<SavedScripture>>(
  SavedScriptureController.new,
);

class SavedScriptureController extends _PersistedList<SavedScripture> {
  @override
  ListStore<SavedScripture> storeOf(LibraryRepository repo) => repo.savedScripture;

  bool isSaved(ScriptureReference ref) => state.any((s) => s.reference == ref);

  Future<bool> toggle(ScriptureReference ref, {String versionId = 'KJV'}) async {
    if (isSaved(ref)) {
      await commit(state.where((s) => s.reference != ref).toList());
      return false;
    }
    await commit([SavedScripture(reference: ref, versionId: versionId, savedAt: DateTime.now()), ...state]);
    return true;
  }

  Future<void> remove(ScriptureReference ref) => commit(state.where((s) => s.reference != ref).toList());
}

// ── Saved content ───────────────────────────────────────────────────────

final savedContentProvider = NotifierProvider<SavedContentController, List<SavedContent>>(SavedContentController.new);

class SavedContentController extends _PersistedList<SavedContent> {
  @override
  ListStore<SavedContent> storeOf(LibraryRepository repo) => repo.savedContent;

  bool isSaved(String id) => state.any((s) => s.contentId == id);

  Future<bool> toggle(ContentItem item) async {
    if (isSaved(item.id)) {
      await remove(item.id);
      return false;
    }
    await commit([SavedContent(contentId: item.id, type: item.type, savedAt: DateTime.now()), ...state]);
    return true;
  }

  Future<void> remove(String id) => commit(state.where((s) => s.contentId != id).toList());
}

final savedContentIdsProvider = Provider<Set<String>>(
  (ref) => ref.watch(savedContentProvider).map((s) => s.contentId).toSet(),
);

final isContentSavedProvider = Provider.family<bool, String>(
  (ref, id) => ref.watch(savedContentIdsProvider).contains(id),
);

// ── Reading history ─────────────────────────────────────────────────────

final readingHistoryProvider = NotifierProvider<ReadingHistoryController, List<ReadingHistoryEntry>>(
  ReadingHistoryController.new,
);

class ReadingHistoryController extends _PersistedList<ReadingHistoryEntry> {
  static const maxEntries = 50;

  @override
  ListStore<ReadingHistoryEntry> storeOf(LibraryRepository repo) => repo.readingHistory;

  /// Records a chapter visit, moving it to the top without duplicates.
  Future<void> record(ScriptureReference chapter, {String versionId = 'KJV'}) {
    final c = chapter.chapterOnly;
    if (state.isNotEmpty && state.first.reference == c) return Future.value();
    final next = [
      ReadingHistoryEntry(reference: c, versionId: versionId, readAt: DateTime.now()),
      ...state.where((e) => e.reference != c),
    ];
    return commit(next.take(maxEntries).toList());
  }
}

// ── Recently viewed content ─────────────────────────────────────────────

final recentlyViewedProvider = NotifierProvider<RecentlyViewedController, List<RecentlyViewed>>(
  RecentlyViewedController.new,
);

class RecentlyViewedController extends _PersistedList<RecentlyViewed> {
  static const maxEntries = 30;

  @override
  ListStore<RecentlyViewed> storeOf(LibraryRepository repo) => repo.recentlyViewed;

  Future<void> record(String contentId) {
    if (state.isNotEmpty && state.first.contentId == contentId) return Future.value();
    final next = [
      RecentlyViewed(contentId: contentId, viewedAt: DateTime.now()),
      ...state.where((e) => e.contentId != contentId),
    ];
    return commit(next.take(maxEntries).toList());
  }
}

// ── Collections ─────────────────────────────────────────────────────────

final collectionsProvider = NotifierProvider<CollectionsController, List<ContentCollection>>(CollectionsController.new);

class CollectionsController extends _PersistedList<ContentCollection> {
  @override
  ListStore<ContentCollection> storeOf(LibraryRepository repo) => repo.collections;

  Future<ContentCollection> create(String name, {List<String> contentIds = const []}) async {
    final c = ContentCollection(id: _newId(), name: name.trim(), contentIds: contentIds, createdAt: DateTime.now());
    await commit([...state, c]);
    return c;
  }

  Future<void> rename(String id, String name) =>
      commit([for (final c in state) c.id == id ? c.copyWith(name: name.trim()) : c]);

  Future<void> delete(String id) => commit(state.where((c) => c.id != id).toList());

  Future<void> toggleItem(String collectionId, String contentId) => commit([
    for (final c in state)
      if (c.id != collectionId)
        c
      else
        c.copyWith(
          contentIds: c.contentIds.contains(contentId)
              ? c.contentIds.where((i) => i != contentId).toList()
              : [...c.contentIds, contentId],
        ),
  ]);
}

// ── Recent searches ─────────────────────────────────────────────────────

final recentSearchesProvider = NotifierProvider<RecentSearchesController, List<String>>(RecentSearchesController.new);

class RecentSearchesController extends _PersistedList<String> {
  static const maxEntries = 10;

  @override
  ListStore<String> storeOf(LibraryRepository repo) => repo.recentSearches;

  Future<void> add(String query) {
    final q = query.trim();
    if (q.length < 2) return Future.value();
    if (state.isNotEmpty && state.first == q) return Future.value();
    final next = [q, ...state.where((s) => s.toLowerCase() != q.toLowerCase())];
    return commit(next.take(maxEntries).toList());
  }

  Future<void> remove(String query) => commit(state.where((s) => s != query).toList());
}

// ── Upload drafts & reports ─────────────────────────────────────────────

final uploadDraftsProvider = NotifierProvider<UploadDraftsController, List<UploadDraft>>(UploadDraftsController.new);

class UploadDraftsController extends _PersistedList<UploadDraft> {
  @override
  ListStore<UploadDraft> storeOf(LibraryRepository repo) => repo.uploadDrafts;

  Future<void> add(UploadDraft draft) => commit([draft, ...state]);

  Future<void> delete(String id) => commit(state.where((d) => d.id != id).toList());
}

final contentReportsProvider = NotifierProvider<ContentReportsController, List<ContentReport>>(
  ContentReportsController.new,
);

class ContentReportsController extends _PersistedList<ContentReport> {
  @override
  ListStore<ContentReport> storeOf(LibraryRepository repo) => repo.reports;

  Future<void> submit(ContentReport report) => commit([report, ...state]);
}

/// Clears every personal library list on this device.
final libraryActionsProvider = Provider<LibraryActions>(LibraryActions.new);

class LibraryActions {
  LibraryActions(this._ref);
  final Ref _ref;

  Future<void> clearLibrary() async {
    await _ref.read(libraryRepositoryProvider).clearAll();
    for (final p in [
      bookmarksProvider,
      highlightsProvider,
      notesProvider,
      savedScriptureProvider,
      savedContentProvider,
      readingHistoryProvider,
      recentlyViewedProvider,
      collectionsProvider,
      recentSearchesProvider,
      uploadDraftsProvider,
      contentReportsProvider,
    ]) {
      _ref.invalidate(p);
    }
  }
}
