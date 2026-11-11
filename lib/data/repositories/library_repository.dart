import '../../core/constants/storage_keys.dart';
import '../../core/storage/key_value_store.dart';
import '../models/library_items.dart';

/// A persisted, ordered list of personal items.
abstract interface class ListStore<T> {
  List<T> load();
  Future<void> save(List<T> items);
  Future<void> clear();
}

/// The user's personal library: Scripture annotations, saved content,
/// history, collections and contributions.
abstract interface class LibraryRepository {
  ListStore<Bookmark> get bookmarks;
  ListStore<Highlight> get highlights;
  ListStore<VerseNote> get notes;
  ListStore<SavedScripture> get savedScripture;
  ListStore<SavedContent> get savedContent;
  ListStore<ReadingHistoryEntry> get readingHistory;
  ListStore<RecentlyViewed> get recentlyViewed;
  ListStore<ContentCollection> get collections;
  ListStore<String> get recentSearches;
  ListStore<UploadDraft> get uploadDrafts;
  ListStore<ContentReport> get reports;

  Future<void> clearAll();
}

class _KvListStore<T> implements ListStore<T> {
  _KvListStore(this._store, this._key, this._fromJson, this._toJson);

  final KeyValueStore _store;
  final String _key;
  final T Function(Map<String, dynamic>) _fromJson;
  final Map<String, dynamic> Function(T) _toJson;

  @override
  List<T> load() => _store.readList(_key, _fromJson);

  @override
  Future<void> save(List<T> items) => _store.writeList(_key, items, _toJson);

  @override
  Future<void> clear() => _store.remove(_key);
}

/// On-device implementation over [KeyValueStore]. Keep the data modest;
/// a database-backed implementation can replace this behind the interface.
class LocalLibraryRepository implements LibraryRepository {
  LocalLibraryRepository(KeyValueStore store)
    : bookmarks = _KvListStore(store, StorageKeys.bookmarks, Bookmark.fromJson, (b) => b.toJson()),
      highlights = _KvListStore(store, StorageKeys.highlights, Highlight.fromJson, (h) => h.toJson()),
      notes = _KvListStore(store, StorageKeys.notes, VerseNote.fromJson, (n) => n.toJson()),
      savedScripture = _KvListStore(store, StorageKeys.savedScripture, SavedScripture.fromJson, (s) => s.toJson()),
      savedContent = _KvListStore(store, StorageKeys.savedContent, SavedContent.fromJson, (s) => s.toJson()),
      readingHistory = _KvListStore(store, StorageKeys.readingHistory, ReadingHistoryEntry.fromJson, (h) => h.toJson()),
      recentlyViewed = _KvListStore(store, StorageKeys.recentlyViewed, RecentlyViewed.fromJson, (r) => r.toJson()),
      collections = _KvListStore(store, StorageKeys.collections, ContentCollection.fromJson, (c) => c.toJson()),
      recentSearches = _KvListStore(store, StorageKeys.recentSearches, (j) => j['q'] as String, (q) => {'q': q}),
      uploadDrafts = _KvListStore(store, StorageKeys.uploadDrafts, UploadDraft.fromJson, (d) => d.toJson()),
      reports = _KvListStore(store, StorageKeys.contentReports, ContentReport.fromJson, (r) => r.toJson());

  @override
  final ListStore<Bookmark> bookmarks;
  @override
  final ListStore<Highlight> highlights;
  @override
  final ListStore<VerseNote> notes;
  @override
  final ListStore<SavedScripture> savedScripture;
  @override
  final ListStore<SavedContent> savedContent;
  @override
  final ListStore<ReadingHistoryEntry> readingHistory;
  @override
  final ListStore<RecentlyViewed> recentlyViewed;
  @override
  final ListStore<ContentCollection> collections;
  @override
  final ListStore<String> recentSearches;
  @override
  final ListStore<UploadDraft> uploadDrafts;
  @override
  final ListStore<ContentReport> reports;

  @override
  Future<void> clearAll() async {
    for (final s in <ListStore<Object?>>[
      bookmarks,
      highlights,
      notes,
      savedScripture,
      savedContent,
      readingHistory,
      recentlyViewed,
      collections,
      recentSearches,
      uploadDrafts,
      reports,
    ]) {
      await s.clear();
    }
  }
}
