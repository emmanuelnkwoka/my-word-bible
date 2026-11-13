import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/errors/app_failure.dart';
import '../catalogue/version_catalogue.dart';
import '../models/bible.dart';
import '../models/scripture_reference.dart';

export '../catalogue/version_catalogue.dart' show VersionCatalogue, VersionFamily, bibleVersionCatalogue;

/// Access to Bible translations. Implementations may read bundled assets
/// (Foundation V1) or a future licensed Scripture API.
abstract interface class BibleRepository {
  List<BibleVersionInfo> get versions;

  Future<List<BibleBookInfo>> books(String versionId);

  Future<List<Verse>> chapter(String versionId, String bookId, int chapter);

  /// Resolves a reference to canonical verses. Throws [NotFoundFailure] if
  /// the reference does not exist in the translation.
  Future<Passage> passage(String versionId, ScriptureReference reference);

  /// Word search across the translation (all words must match).
  Future<List<VerseSearchHit>> search(String versionId, String query, {int limit = 40});
}

typedef AssetLoader = Future<String> Function(String path);

class _LoadedBible {
  _LoadedBible(this.books, this.chapters);

  final List<BibleBookInfo> books;

  /// bookId -> chapters -> verses.
  final Map<String, List<List<String>>> chapters;
  List<({String bookId, int chapter, int verse, String lower})>? _index;

  List<({String bookId, int chapter, int verse, String lower})> get index => _index ??= [
    for (final b in books)
      for (var c = 0; c < chapters[b.id]!.length; c++)
        for (var v = 0; v < chapters[b.id]![c].length; v++)
          (bookId: b.id, chapter: c + 1, verse: v + 1, lower: chapters[b.id]![c][v].toLowerCase()),
  ];
}

_LoadedBible _parseBible(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final books = <BibleBookInfo>[];
  final chapters = <String, List<List<String>>>{};
  for (final b in (json['books'] as List).cast<Map<String, dynamic>>()) {
    final id = b['id'] as String;
    final ch = (b['chapters'] as List).map((c) => (c as List).cast<String>()).toList();
    chapters[id] = ch;
    books.add(BibleBookInfo(id: id, name: b['name'] as String, chapterCount: ch.length, isOld: b['testament'] == 'OT'));
  }
  return _LoadedBible(books, chapters);
}

/// Reads complete translations bundled as JSON assets.
class AssetBibleRepository implements BibleRepository {
  AssetBibleRepository({AssetLoader? loader, this.parseInBackground = true})
    : _loader = loader ?? rootBundle.loadString;

  final AssetLoader _loader;
  final bool parseInBackground;
  final Map<String, Future<_LoadedBible>> _cache = {};

  static const _assets = {'KJV': 'assets/bible/kjv.json', 'WEB': 'assets/bible/web.json'};

  @override
  List<BibleVersionInfo> get versions => bibleVersionCatalogue;

  Future<_LoadedBible> _load(String versionId) {
    final asset = _assets[versionId];
    if (asset == null) {
      return Future.error(FeatureUnavailableFailure('The $versionId translation is not installed.'));
    }
    return _cache.putIfAbsent(versionId, () async {
      try {
        final raw = await _loader(asset);
        return parseInBackground ? await compute(_parseBible, raw) : _parseBible(raw);
      } catch (e) {
        _cache.remove(versionId);
        throw const UnknownFailure('The Bible text could not be opened.');
      }
    });
  }

  @override
  Future<List<BibleBookInfo>> books(String versionId) async => (await _load(versionId)).books;

  @override
  Future<List<Verse>> chapter(String versionId, String bookId, int chapter) async {
    final bible = await _load(versionId);
    final chapters = bible.chapters[bookId];
    if (chapters == null || chapter < 1 || chapter > chapters.length) throw const NotFoundFailure();
    final verses = chapters[chapter - 1];
    return [
      for (var i = 0; i < verses.length; i++) Verse(bookId: bookId, chapter: chapter, number: i + 1, text: verses[i]),
    ];
  }

  @override
  Future<Passage> passage(String versionId, ScriptureReference reference) async {
    final all = await chapter(versionId, reference.bookId, reference.chapter);
    if (reference.isWholeChapter) return Passage(reference: reference, versionId: versionId, verses: all);
    final start = reference.verseStart!;
    final end = reference.verseEnd ?? start;
    if (start < 1 || end > all.length) throw const NotFoundFailure('That verse is not in this chapter.');
    return Passage(reference: reference, versionId: versionId, verses: all.sublist(start - 1, end));
  }

  @override
  Future<List<VerseSearchHit>> search(String versionId, String query, {int limit = 40}) async {
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 1).toList();
    if (words.isEmpty) return const [];
    final bible = await _load(versionId);
    final hits = <VerseSearchHit>[];
    for (final e in bible.index) {
      if (e.lower.isNotEmpty && words.every(e.lower.contains)) {
        hits.add(
          VerseSearchHit(
            versionId: versionId,
            verse: Verse(
              bookId: e.bookId,
              chapter: e.chapter,
              number: e.verse,
              text: bible.chapters[e.bookId]![e.chapter - 1][e.verse - 1],
            ),
          ),
        );
        if (hits.length >= limit) break;
      }
    }
    return hits;
  }
}
