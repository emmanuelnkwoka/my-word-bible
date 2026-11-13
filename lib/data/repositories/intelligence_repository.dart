import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/errors/app_failure.dart';
import '../models/intelligence.dart';
import '../models/scripture_reference.dart';
import 'bible_repository.dart' show AssetLoader;

/// The complete, loaded intelligence corpus with lookup indexes.
class IntelligenceCorpus {
  IntelligenceCorpus({
    required this.manifest,
    required this.contexts,
    required this.situations,
    required this.promises,
    required this.blessings,
    required this.prayers,
    required this.declarations,
    required this.commands,
    required this.identityThemes,
    required this.worshipThemes,
    required this.relationships,
    required this.journeys,
    required this.terms,
    required this.links,
  });

  final IntelManifest manifest;
  final List<IntelContext> contexts;
  final List<LifeSituation> situations;
  final List<IntelPromise> promises;
  final List<Blessing> blessings;
  final List<IntelPrayer> prayers;
  final List<Declaration> declarations;
  final List<IntelCommand> commands;
  final List<IdentityTheme> identityThemes;
  final List<WorshipTheme> worshipThemes;
  final List<ScriptureRelationship> relationships;
  final List<Journey> journeys;
  final List<TaxonomyTerm> terms;
  final List<TaxonomyLink> links;

  /// Every record, in file order.
  late final List<IntelRecord> records = List.unmodifiable(<IntelRecord>[
    ...contexts,
    ...situations,
    ...promises,
    ...blessings,
    ...prayers,
    ...declarations,
    ...commands,
    ...identityThemes,
    ...worshipThemes,
    ...relationships,
    ...journeys,
  ]);

  /// Record lookup by id. When ids collide the first record wins; the
  /// validator reports duplicates.
  late final Map<String, IntelRecord> _byId = () {
    final m = <String, IntelRecord>{};
    for (final r in records) {
      m.putIfAbsent(r.id, () => r);
    }
    return m;
  }();

  IntelRecord? byId(String id) => _byId[id];

  T? typed<T extends IntelRecord>(String id) {
    final r = _byId[id];
    return r is T ? r : null;
  }

  late final Map<String, List<IntelContext>> _contextsByBook = () {
    final m = <String, List<IntelContext>>{};
    for (final c in contexts) {
      (m[c.reference.bookId] ??= []).add(c);
    }
    return m;
  }();

  /// Contexts covering any verse of [reference], most specific first.
  List<IntelContext> contextsFor(ScriptureReference reference) {
    final found = (_contextsByBook[reference.bookId] ?? const <IntelContext>[])
        .where((c) => referencesOverlap(c.reference, reference))
        .toList();
    found.sort((a, b) => _span(a.reference).compareTo(_span(b.reference)));
    return found;
  }

  /// Relationships touching [reference], seen from that side.
  List<RelationshipView> relationshipsFor(ScriptureReference reference) => [
    for (final r in relationships)
      if (referencesOverlap(r.from, reference))
        RelationshipView(relationship: r, other: r.to, outgoing: true)
      else if (r.bidirectional && referencesOverlap(r.to, reference))
        RelationshipView(relationship: r, other: r.from, outgoing: false),
  ];

  List<Journey> journeysForSituation(String situationId) =>
      journeys.where((j) => j.situationId == situationId).toList();

  /// Records of any kind that cite [reference].
  List<IntelRecord> recordsCiting(ScriptureReference reference) => [
    for (final r in records)
      if (r.kind != IntelKind.context && r.references.any((x) => referencesOverlap(x, reference))) r,
  ];

  List<TaxonomyTerm> termsFor(String objectId) {
    final ids = links.where((l) => l.objectId == objectId).map((l) => l.termId).toSet();
    return terms.where((t) => ids.contains(t.id)).toList();
  }

  /// Flat entries for the future unified search (Stage E).
  late final List<IntelSearchEntry> searchEntries = List.unmodifiable([
    for (final r in records)
      if (r.kind != IntelKind.relationship)
        IntelSearchEntry(
          id: r.id,
          kind: r.kind,
          title: r.title,
          subtitle: _subtitle(r),
          keywords: _keywords(r),
          references: r.references,
          body: r is EditorialContent ? r.text : '',
        ),
  ]);

  String _subtitle(IntelRecord r) => switch (r) {
    IntelContext c => '${c.voice.label} · ${c.speaker}',
    LifeSituation s => s.description,
    IntelPromise p => 'Promise · ${p.category}',
    Blessing b => 'Blessing · ${b.category}',
    IntelPrayer _ => 'Prayer',
    Declaration d => 'Declaration · ${d.category}',
    IntelCommand _ => 'Command',
    IdentityTheme _ => 'Identity',
    WorshipTheme w => 'Worship · ${w.worshipKind.name}',
    Journey j => '${j.steps.length}-step journey',
    _ => r.kind.label,
  };

  List<String> _keywords(IntelRecord r) => {
    if (r is IntelContext) ...r.keywords,
    for (final t in termsFor(r.id)) t.label.toLowerCase(),
    if (r is IntelPromise) r.category.toLowerCase(),
  }.toList();

  static int _span(ScriptureReference r) => (r.verseEnd ?? r.verseStart ?? 999) - (r.verseStart ?? 0);
}

/// True when two references share at least one verse. A whole-chapter
/// reference overlaps every verse in that chapter.
bool referencesOverlap(ScriptureReference a, ScriptureReference b) {
  if (a.bookId != b.bookId || a.chapter != b.chapter) return false;
  if (a.verseStart == null || b.verseStart == null) return true;
  final aEnd = a.verseEnd ?? a.verseStart!;
  final bEnd = b.verseEnd ?? b.verseStart!;
  return a.verseStart! <= bEnd && b.verseStart! <= aEnd;
}

@immutable
class RelationshipView {
  const RelationshipView({required this.relationship, required this.other, required this.outgoing});
  final ScriptureRelationship relationship;
  final ScriptureReference other;
  final bool outgoing;
}

@immutable
class IntelSearchEntry {
  const IntelSearchEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.keywords,
    required this.references,
    this.body = '',
  });
  final String id;
  final IntelKind kind;
  final String title;
  final String subtitle;
  final List<String> keywords;
  final List<ScriptureReference> references;

  /// Editorial text (prayers, blessings, declarations); never Scripture.
  final String body;
}

/// Local, read-only access to the Scripture intelligence corpus.
abstract interface class IntelligenceRepository {
  Future<IntelligenceCorpus> corpus();
  Future<IntelContext?> contextFor(ScriptureReference reference);
  Future<List<LifeSituation>> situations();
  Future<LifeSituation?> situation(String id);
  Future<List<IntelPromise>> promises();
  Future<List<Blessing>> blessings();
  Future<List<IntelPrayer>> prayers();
  Future<List<Declaration>> declarations();
  Future<List<IntelCommand>> commands();
  Future<List<IdentityTheme>> identityThemes();
  Future<List<WorshipTheme>> worshipThemes();
  Future<List<RelationshipView>> relationshipsFor(ScriptureReference reference);
  Future<List<Journey>> journeys();
  Future<List<Journey>> journeysForSituation(String situationId);
  Future<List<IntelSearchEntry>> searchEntries();
}

/// Reads `assets/intel/*.json` once, on first use, and keeps the parsed
/// corpus in memory. No network access.
class AssetIntelligenceRepository implements IntelligenceRepository {
  AssetIntelligenceRepository({AssetLoader? loader, this.parseInBackground = true})
    : _loader = loader ?? rootBundle.loadString;

  static const directory = 'assets/intel';
  static const dataFiles = [
    'contexts.json',
    'situations.json',
    'promises.json',
    'blessings.json',
    'prayers.json',
    'declarations.json',
    'commands.json',
    'identity_themes.json',
    'worship_themes.json',
    'relationships.json',
    'journeys.json',
    'taxonomy.json',
  ];

  final AssetLoader _loader;
  final bool parseInBackground;
  Future<IntelligenceCorpus>? _corpus;

  /// Number of times the asset files have been read (for tests).
  @visibleForTesting
  int loads = 0;

  @override
  Future<IntelligenceCorpus> corpus() => _corpus ??= _load();

  Future<IntelligenceCorpus> _load() async {
    loads++;
    try {
      final raw = <String, String>{
        'manifest.json': await _loader('$directory/manifest.json'),
        for (final f in dataFiles) f: await _loader('$directory/$f'),
      };
      return parseInBackground ? await compute(parseIntelligenceCorpus, raw) : parseIntelligenceCorpus(raw);
    } on IntelFormatException catch (e) {
      _corpus = null;
      throw UnknownFailure('The Scripture intelligence data is invalid: ${e.message}');
    } catch (e) {
      _corpus = null;
      if (e is AppFailure) rethrow;
      throw const UnknownFailure('The Scripture intelligence data could not be opened.');
    }
  }

  @override
  Future<IntelContext?> contextFor(ScriptureReference reference) async =>
      (await corpus()).contextsFor(reference).firstOrNull;
  @override
  Future<List<LifeSituation>> situations() async => (await corpus()).situations;
  @override
  Future<LifeSituation?> situation(String id) async => (await corpus()).typed<LifeSituation>(id);
  @override
  Future<List<IntelPromise>> promises() async => (await corpus()).promises;
  @override
  Future<List<Blessing>> blessings() async => (await corpus()).blessings;
  @override
  Future<List<IntelPrayer>> prayers() async => (await corpus()).prayers;
  @override
  Future<List<Declaration>> declarations() async => (await corpus()).declarations;
  @override
  Future<List<IntelCommand>> commands() async => (await corpus()).commands;
  @override
  Future<List<IdentityTheme>> identityThemes() async => (await corpus()).identityThemes;
  @override
  Future<List<WorshipTheme>> worshipThemes() async => (await corpus()).worshipThemes;
  @override
  Future<List<RelationshipView>> relationshipsFor(ScriptureReference reference) async =>
      (await corpus()).relationshipsFor(reference);
  @override
  Future<List<Journey>> journeys() async => (await corpus()).journeys;
  @override
  Future<List<Journey>> journeysForSituation(String situationId) async =>
      (await corpus()).journeysForSituation(situationId);
  @override
  Future<List<IntelSearchEntry>> searchEntries() async => (await corpus()).searchEntries;
}

/// Parses the raw corpus files (file name → JSON text). Top-level so it can
/// run in a background isolate. Throws [IntelFormatException] on any schema
/// problem, naming the file and record.
IntelligenceCorpus parseIntelligenceCorpus(Map<String, String> raw) {
  Object? json(String file) {
    final text = raw[file];
    if (text == null) throw IntelFormatException('$file is missing');
    try {
      return jsonDecode(text);
    } on FormatException catch (e) {
      throw IntelFormatException('$file is not valid JSON: ${e.message}');
    }
  }

  final manifest = IntelDecoder.manifest(json('manifest.json'));
  final taxonomy = IntelDecoder.taxonomy(json('taxonomy.json'));
  final corpus = IntelligenceCorpus(
    manifest: manifest,
    contexts: IntelDecoder.contexts(json('contexts.json')),
    situations: IntelDecoder.situations(json('situations.json')),
    promises: IntelDecoder.promises(json('promises.json')),
    blessings: IntelDecoder.blessings(json('blessings.json')),
    prayers: IntelDecoder.prayers(json('prayers.json')),
    declarations: IntelDecoder.declarations(json('declarations.json')),
    commands: IntelDecoder.commands(json('commands.json')),
    identityThemes: IntelDecoder.identityThemes(json('identity_themes.json')),
    worshipThemes: IntelDecoder.worshipThemes(json('worship_themes.json')),
    relationships: IntelDecoder.relationships(json('relationships.json')),
    journeys: IntelDecoder.journeys(json('journeys.json')),
    terms: taxonomy.terms,
    links: taxonomy.links,
  );
  final actual = {
    'contexts.json': corpus.contexts.length,
    'situations.json': corpus.situations.length,
    'promises.json': corpus.promises.length,
    'blessings.json': corpus.blessings.length,
    'prayers.json': corpus.prayers.length,
    'declarations.json': corpus.declarations.length,
    'commands.json': corpus.commands.length,
    'identity_themes.json': corpus.identityThemes.length,
    'worship_themes.json': corpus.worshipThemes.length,
    'relationships.json': corpus.relationships.length,
    'journeys.json': corpus.journeys.length,
    'taxonomy.json': corpus.terms.length,
  };
  for (final e in actual.entries) {
    final expected = manifest.files[e.key];
    if (expected != e.value) {
      throw IntelFormatException('manifest.json lists ${expected ?? 'no'} record(s) for ${e.key}; found ${e.value}');
    }
  }
  return corpus;
}
