import 'package:flutter/foundation.dart';

import 'mwb_rule.dart' show RiskLevel;
import 'scripture_reference.dart';

/// GODSAID Scripture Intelligence: typed records loaded from `assets/intel`.
///
/// Records point at Scripture through canonical references only. They never
/// store translated verse text, so one record serves KJV, WEB and any future
/// translation. Editorial content (prayers, blessings, declarations, notes)
/// is typed separately so it can never be presented as Scripture.

/// A corpus file that does not match the schema.
class IntelFormatException implements Exception {
  const IntelFormatException(this.message);
  final String message;
  @override
  String toString() => 'IntelFormatException: $message';
}

// ── Shared vocabulary ───────────────────────────────────────────────────

enum IntelKind {
  context('Passage context'),
  situation('Life situation'),
  promise('Promise'),
  blessing('Blessing'),
  prayer('Prayer'),
  declaration('Declaration'),
  command('Command'),
  identityTheme('Identity theme'),
  worshipTheme('Worship and thanksgiving'),
  relationship('Scripture relationship'),
  journey('Guided journey');

  const IntelKind(this.label);
  final String label;

  /// Kinds whose main text is written by editors, not taken from Scripture.
  bool get hasEditorialText => this == blessing || this == prayer || this == declaration;
}

/// Who is speaking, in the three groups GODSAID keeps distinct.
enum IntelVoice {
  god('God’s direct words'),
  jesus('Words of Jesus'),
  inspiredHuman('Inspired human message');

  const IntelVoice(this.label);
  final String label;
}

/// Who a passage was first addressed to.
enum IntelAddressee {
  specificIndividual('A specific person'),
  representative('Representative address'),
  collective('A people or community'),
  god('Addressed to God'),
  general('General statement'),
  testimony('First-person testimony'),
  narrative('Narrative'),
  unspecified('Not recorded');

  const IntelAddressee(this.label);
  final String label;
}

enum InspirationClass {
  recordedDivineSpeech('Recorded divine speech'),
  directDivineSpeech('Direct divine speech'),
  historicalNarrative('Historical narrative'),
  poetic('Poetic / liturgical'),
  wisdom('Wisdom literature'),
  propheticOracle('Prophetic oracle'),
  wordsOfJesus('Words of Jesus'),
  apostolicInstruction('Apostolic instruction'),
  apocalypticVision('Apocalyptic vision');

  const InspirationClass(this.label);
  final String label;
}

/// Whether a passage may be considered for MWB personalisation. There is
/// deliberately no "approved" value: approval exists only in MWB rulesets,
/// recorded by a human reviewer.
enum PersonalisationEligibility { notEligible, reviewRequired, unassessed }

enum PromiseScope {
  corporate('Given to a people'),
  individualHistorical('Given to a specific person'),
  general('General promise');

  const PromiseScope(this.label);
  final String label;
}

enum CommandType { directImperative, exhortation, invitation }

enum WorshipKind { praise, thanksgiving, trust }

enum RelationshipType {
  theme('Similar theme'),
  explanation('Helps explain'),
  quotation('Quotation'),
  supporting('Supporting Scripture'),
  promise('Promise and its condition'),
  contextual('Same passage context');

  const RelationshipType(this.label);
  final String label;
}

enum JourneyStepType { situation, verse, promise, identity, worship, command, prayer, declaration, blessing }

enum ProvenanceOrigin {
  /// A verified export of the historical GODSAID corpus.
  historicalExport,

  /// Taken from the MWB HTML demonstration and curated.
  demoSeed,

  /// Written during Stage C curation.
  newlyCurated,
}

enum EditorialStatus { pendingEditorialReview, editoriallyReviewed, needsRevision }

@immutable
class Provenance {
  const Provenance({required this.origin, this.seedId, this.seedLine, this.basis = '', this.changes = const []});
  final ProvenanceOrigin origin;
  final String? seedId;
  final int? seedLine;
  final String basis;
  final List<String> changes;

  factory Provenance._read(_Reader r) => Provenance(
    origin: r.enumValue('origin', ProvenanceOrigin.values),
    seedId: r.optStr('seedId'),
    seedLine: r.optInt('seedLine'),
    basis: r.optStr('basis') ?? '',
    changes: r.strings('changes', optional: true),
  );
}

@immutable
class EditorialReview {
  const EditorialReview({required this.status, this.flags = const [], this.reviewer, this.reviewedOn});
  final EditorialStatus status;

  /// Concerns an editor must look at.
  final List<String> flags;
  final String? reviewer;
  final String? reviewedOn;

  bool get isPending => status != EditorialStatus.editoriallyReviewed;

  factory EditorialReview._read(_Reader r) => EditorialReview(
    status: r.enumValue('status', EditorialStatus.values),
    flags: r.strings('flags', optional: true),
    reviewer: r.optStr('reviewer'),
    reviewedOn: r.optStr('reviewedOn'),
  );
}

/// Common shape of every intelligence record.
abstract class IntelRecord {
  const IntelRecord({required this.id, required this.provenance, required this.review});
  final String id;
  final Provenance provenance;
  final EditorialReview review;
  IntelKind get kind;

  /// Canonical Scripture this record points to.
  List<ScriptureReference> get references;

  /// Human-readable title for lists and search.
  String get title;
}

/// A record whose main text was written by editors. It is never Scripture.
abstract class EditorialContent extends IntelRecord {
  const EditorialContent({required super.id, required super.provenance, required super.review});
  String get text;

  bool get isScripture => false;

  /// Label that must accompany the text wherever it is shown.
  String get displayLabel;
}

// ── Records ─────────────────────────────────────────────────────────────

@immutable
class IntelContext extends IntelRecord {
  const IntelContext({
    required super.id,
    required this.reference,
    required this.voice,
    required this.speaker,
    required this.author,
    required this.originalAudience,
    required this.addressee,
    required this.literaryForm,
    required this.classification,
    required this.eligibility,
    required this.personalisationRisk,
    required super.provenance,
    required super.review,
    this.historicalContext = '',
    this.literaryContext = '',
    this.isConditional = false,
    this.conditionNote = '',
    this.personalisationNote = '',
    this.contextNote = '',
    this.keywords = const [],
  });

  final ScriptureReference reference;
  final IntelVoice voice;
  final String speaker;
  final String author;
  final String originalAudience;
  final IntelAddressee addressee;
  final String historicalContext;
  final String literaryForm;
  final String literaryContext;
  final InspirationClass classification;
  final bool isConditional;
  final String conditionNote;
  final PersonalisationEligibility eligibility;
  final RiskLevel personalisationRisk;
  final String personalisationNote;
  final String contextNote;
  final List<String> keywords;

  @override
  IntelKind get kind => IntelKind.context;
  @override
  List<ScriptureReference> get references => [reference];
  @override
  String get title => reference.label;
}

@immutable
class LifeSituation extends IntelRecord {
  const LifeSituation({
    required super.id,
    required this.name,
    required this.description,
    required this.references,
    required super.provenance,
    required super.review,
    this.promiseIds = const [],
    this.prayerIds = const [],
    this.declarationIds = const [],
    this.journeyIds = const [],
  });
  final String name;
  final String description;
  @override
  final List<ScriptureReference> references;
  final List<String> promiseIds;
  final List<String> prayerIds;
  final List<String> declarationIds;
  final List<String> journeyIds;

  @override
  IntelKind get kind => IntelKind.situation;
  @override
  String get title => name;
}

@immutable
class IntelPromise extends IntelRecord {
  const IntelPromise({
    required super.id,
    required this.title,
    required this.references,
    required this.category,
    required this.originalAudience,
    required this.scope,
    required this.receptionGuidance,
    required super.provenance,
    required super.review,
    this.themes = const [],
    this.conditions = const [],
    this.contextNote = '',
  });
  @override
  final String title;
  @override
  final List<ScriptureReference> references;
  final String category;
  final List<String> themes;
  final String originalAudience;
  final PromiseScope scope;

  /// Conditions stated in or around the passage. Empty only when the
  /// passage carries none.
  final List<String> conditions;
  final String contextNote;
  final String receptionGuidance;

  bool get isConditional => conditions.isNotEmpty;

  @override
  IntelKind get kind => IntelKind.promise;
}

@immutable
class Blessing extends EditorialContent {
  const Blessing({
    required super.id,
    required this.title,
    required this.category,
    required this.text,
    required this.references,
    required super.provenance,
    required super.review,
    this.themes = const [],
    this.groundingNote = '',
  });
  @override
  final String title;
  final String category;
  final List<String> themes;
  @override
  final String text;
  @override
  final List<ScriptureReference> references;
  final String groundingNote;

  @override
  IntelKind get kind => IntelKind.blessing;
  @override
  String get displayLabel => 'Blessing — grounded in Scripture, not Scripture text';
}

@immutable
class IntelPrayer extends EditorialContent {
  const IntelPrayer({
    required super.id,
    required this.title,
    required this.situationId,
    required this.text,
    required this.references,
    required super.provenance,
    required super.review,
  });
  @override
  final String title;
  final String situationId;
  @override
  final String text;
  @override
  final List<ScriptureReference> references;

  @override
  IntelKind get kind => IntelKind.prayer;
  @override
  String get displayLabel => 'Prayer — assembled from Scripture, not Scripture text';
}

@immutable
class Declaration extends EditorialContent {
  const Declaration({
    required super.id,
    required this.title,
    required this.category,
    required this.text,
    required this.firstPersonText,
    required this.references,
    required super.provenance,
    required super.review,
    this.themes = const [],
    this.groundingNote = '',
  });

  /// The name placeholder, shared with MWB rulesets.
  static const namePlaceholder = '{name}';

  @override
  final String title;
  final String category;
  final List<String> themes;

  /// Third-person form using [namePlaceholder]; no gendered pronouns.
  @override
  final String text;

  /// First-person form, used when no usable name is set.
  final String firstPersonText;
  @override
  final List<ScriptureReference> references;
  final String groundingNote;

  /// The declaration for a reader. Uses the first-person form when [name]
  /// is null or blank; never invents a name.
  String personalised(String? name) {
    final n = name?.trim();
    if (n == null || n.isEmpty) return firstPersonText;
    return text.replaceAll(namePlaceholder, n);
  }

  @override
  IntelKind get kind => IntelKind.declaration;
  @override
  String get displayLabel => 'Declaration — spoken in faith, grounded in Scripture, not Scripture text';
}

@immutable
class IntelCommand extends IntelRecord {
  const IntelCommand({
    required super.id,
    required this.title,
    required this.references,
    required this.commandType,
    required this.addressedTo,
    required super.provenance,
    required super.review,
    this.themes = const [],
    this.relatedPromiseIds = const [],
    this.contextNote = '',
  });
  @override
  final String title;
  @override
  final List<ScriptureReference> references;
  final CommandType commandType;
  final String addressedTo;
  final List<String> themes;

  /// Promises attached to this command. A command is never itself a promise.
  final List<String> relatedPromiseIds;
  final String contextNote;

  @override
  IntelKind get kind => IntelKind.command;
}

@immutable
class IdentityTheme extends IntelRecord {
  const IdentityTheme({
    required super.id,
    required this.title,
    required this.references,
    required this.holder,
    required this.note,
    required super.provenance,
    required super.review,
    this.themes = const [],
  });
  @override
  final String title;
  @override
  final List<ScriptureReference> references;

  /// Who the identity statement describes in its setting.
  final String holder;
  final String note;
  final List<String> themes;

  @override
  IntelKind get kind => IntelKind.identityTheme;
}

@immutable
class WorshipTheme extends IntelRecord {
  const WorshipTheme({
    required super.id,
    required this.title,
    required this.references,
    required this.worshipKind,
    required super.provenance,
    required super.review,
    this.themes = const [],
  });
  @override
  final String title;
  @override
  final List<ScriptureReference> references;
  final WorshipKind worshipKind;
  final List<String> themes;

  @override
  IntelKind get kind => IntelKind.worshipTheme;
}

@immutable
class ScriptureRelationship extends IntelRecord {
  const ScriptureRelationship({
    required super.id,
    required this.from,
    required this.to,
    required this.type,
    required this.explanation,
    required super.provenance,
    required super.review,
    this.bidirectional = true,
  });
  final ScriptureReference from;
  final ScriptureReference to;
  final RelationshipType type;
  final bool bidirectional;
  final String explanation;

  @override
  IntelKind get kind => IntelKind.relationship;
  @override
  List<ScriptureReference> get references => [from, to];
  @override
  String get title => '${from.label} ↔ ${to.label}';
}

@immutable
class JourneyStep {
  const JourneyStep({required this.order, required this.type, required this.note, this.reference, this.targetId});
  final int order;
  final JourneyStepType type;
  final String note;

  /// Set for verse steps.
  final ScriptureReference? reference;

  /// Set for every other step type.
  final String? targetId;
}

@immutable
class Journey extends IntelRecord {
  const Journey({
    required super.id,
    required this.title,
    required this.description,
    required this.situationId,
    required this.steps,
    required super.provenance,
    required super.review,
  });
  @override
  final String title;
  final String description;
  final String situationId;
  final List<JourneyStep> steps;

  @override
  IntelKind get kind => IntelKind.journey;
  @override
  List<ScriptureReference> get references => [
    for (final s in steps)
      if (s.reference != null) s.reference!,
  ];
}

@immutable
class TaxonomyTerm {
  const TaxonomyTerm({required this.id, required this.label, required this.kind});
  final String id;
  final String label;
  final String kind;
}

@immutable
class TaxonomyLink {
  const TaxonomyLink({required this.termId, required this.objectType, required this.objectId});
  final String termId;
  final IntelKind objectType;
  final String objectId;
}

/// A seed record that was deliberately not adopted.
@immutable
class RejectedSeed {
  const RejectedSeed({required this.kind, required this.seedId, required this.reason, this.seedLine, this.replacement});
  final String kind;
  final String seedId;
  final int? seedLine;
  final String reason;
  final String? replacement;
}

@immutable
class IntelManifest {
  const IntelManifest({
    required this.schemaVersion,
    required this.corpusVersion,
    required this.canonicalVersion,
    required this.files,
    required this.rejected,
  });

  /// Schema versions this build understands.
  static const supportedSchema = 1;

  final int schemaVersion;
  final String corpusVersion;
  final String canonicalVersion;

  /// File name → expected record count.
  final Map<String, int> files;
  final List<RejectedSeed> rejected;
}

// ── Strict decoding ─────────────────────────────────────────────────────

/// Reads one JSON object and rejects unknown fields, so a misspelt key or a
/// stray verse-text field fails loudly instead of being ignored.
class _Reader {
  _Reader(Object? json, this.where, Set<String> allowed) : map = _asMap(json, where) {
    final unknown = map.keys.where((k) => !allowed.contains(k)).toList();
    if (unknown.isNotEmpty) throw IntelFormatException('$where: unknown field(s) ${unknown.join(', ')}');
  }

  final Map<String, dynamic> map;
  final String where;

  static Map<String, dynamic> _asMap(Object? json, String where) {
    if (json is Map<String, dynamic>) return json;
    throw IntelFormatException('$where: expected an object');
  }

  Never _bad(String key, String expected) => throw IntelFormatException('$where: "$key" must be $expected');

  String str(String key) {
    final v = map[key];
    if (v is! String) _bad(key, 'a string');
    return v;
  }

  String? optStr(String key) {
    final v = map[key];
    if (v == null) return null;
    if (v is! String) _bad(key, 'a string');
    return v;
  }

  int? optInt(String key) {
    final v = map[key];
    if (v == null) return null;
    if (v is! int) _bad(key, 'an integer');
    return v;
  }

  int integer(String key) => optInt(key) ?? _bad(key, 'an integer');

  bool boolean(String key, {bool fallback = false}) {
    final v = map[key];
    if (v == null) return fallback;
    if (v is! bool) _bad(key, 'true or false');
    return v;
  }

  List<String> strings(String key, {bool optional = false}) {
    final v = map[key];
    if (v == null && optional) return const [];
    if (v is! List || v.any((e) => e is! String)) _bad(key, 'a list of strings');
    return List.unmodifiable(v.cast<String>());
  }

  List<Object?> list(String key) {
    final v = map[key];
    if (v is! List) _bad(key, 'a list');
    return v;
  }

  T enumValue<T extends Enum>(String key, List<T> values) {
    final s = str(key);
    for (final e in values) {
      if (e.name == s) return e;
    }
    throw IntelFormatException('$where: "$key" has unknown value "$s"');
  }

  _Reader child(String key, Set<String> allowed) => _Reader(map[key], '$where.$key', allowed);

  ScriptureReference ref(String key) => _parseRef(str(key), '$where.$key');

  List<ScriptureReference> refs(String key) => [for (final s in strings(key)) _parseRef(s, '$where.$key')];

  Provenance provenance() =>
      Provenance._read(child('provenance', {'origin', 'seedId', 'seedLine', 'basis', 'changes'}));

  EditorialReview review() => EditorialReview._read(child('review', {'status', 'flags', 'reviewer', 'reviewedOn'}));
}

ScriptureReference _parseRef(String s, String where) {
  try {
    return ScriptureReference.parseCompact(s);
  } on FormatException {
    throw IntelFormatException('$where: "$s" is not a canonical reference (expected e.g. "PSA 23:1")');
  }
}

const _base = {'id', 'provenance', 'review'};

/// Decoders for each corpus file. Each takes the decoded file JSON.
abstract final class IntelDecoder {
  static List<T> _records<T>(Object? json, String file, String key, T Function(_Reader) one, Set<String> fields) {
    final top = _Reader(json, file, {'schemaVersion', 'corpusVersion', key});
    final schema = top.integer('schemaVersion');
    if (schema != IntelManifest.supportedSchema) {
      throw IntelFormatException('$file: schema $schema is not supported (expected ${IntelManifest.supportedSchema})');
    }
    top.str('corpusVersion');
    final items = top.list(key);
    return List.unmodifiable([
      for (var i = 0; i < items.length; i++)
        one(_Reader(items[i], '$file › ${_idOf(items[i]) ?? '#$i'}', {..._base, ...fields})),
    ]);
  }

  static String? _idOf(Object? o) => o is Map && o['id'] is String ? o['id'] as String : null;

  static IntelManifest manifest(Object? json) {
    final r = _Reader(json, 'manifest.json', {
      'schemaVersion',
      'corpusVersion',
      'canonicalVersion',
      'generatedFrom',
      'files',
      'rejected',
    });
    final schema = r.integer('schemaVersion');
    if (schema != IntelManifest.supportedSchema) {
      throw IntelFormatException('manifest.json: schema $schema is not supported');
    }
    final files = r.map['files'];
    if (files is! Map<String, dynamic>) throw const IntelFormatException('manifest.json: "files" must be an object');
    return IntelManifest(
      schemaVersion: schema,
      corpusVersion: r.str('corpusVersion'),
      canonicalVersion: r.str('canonicalVersion'),
      files: {
        for (final e in files.entries)
          e.key: _Reader(e.value, 'manifest.json.files.${e.key}', {'key', 'count', 'links'}).integer('count'),
      },
      rejected: [
        for (final (i, o) in r.list('rejected').indexed)
          () {
            final x = _Reader(o, 'manifest.json.rejected[$i]', {'kind', 'seedId', 'seedLine', 'reason', 'replacement'});
            return RejectedSeed(
              kind: x.str('kind'),
              seedId: x.str('seedId'),
              seedLine: x.optInt('seedLine'),
              reason: x.str('reason'),
              replacement: x.optStr('replacement'),
            );
          }(),
      ],
    );
  }

  static List<IntelContext> contexts(Object? json) => _records(
    json,
    'contexts.json',
    'contexts',
    (r) {
      final p = r.child('personalisation', {'eligibility', 'risk', 'note'});
      return IntelContext(
        id: r.str('id'),
        reference: r.ref('reference'),
        voice: r.enumValue('voice', IntelVoice.values),
        speaker: r.str('speaker'),
        author: r.str('author'),
        originalAudience: r.str('originalAudience'),
        addressee: r.enumValue('addressee', IntelAddressee.values),
        historicalContext: r.optStr('historicalContext') ?? '',
        literaryForm: r.str('literaryForm'),
        literaryContext: r.optStr('literaryContext') ?? '',
        classification: r.enumValue('classification', InspirationClass.values),
        isConditional: r.boolean('isConditional'),
        conditionNote: r.optStr('conditionNote') ?? '',
        eligibility: p.enumValue('eligibility', PersonalisationEligibility.values),
        personalisationRisk: p.enumValue('risk', RiskLevel.values),
        personalisationNote: p.optStr('note') ?? '',
        contextNote: r.optStr('contextNote') ?? '',
        keywords: r.strings('keywords', optional: true),
        provenance: r.provenance(),
        review: r.review(),
      );
    },
    {
      'reference',
      'voice',
      'speaker',
      'author',
      'originalAudience',
      'addressee',
      'historicalContext',
      'literaryForm',
      'literaryContext',
      'classification',
      'isConditional',
      'conditionNote',
      'personalisation',
      'contextNote',
      'keywords',
    },
  );

  static List<LifeSituation> situations(Object? json) => _records(
    json,
    'situations.json',
    'situations',
    (r) => LifeSituation(
      id: r.str('id'),
      name: r.str('name'),
      description: r.str('description'),
      references: r.refs('references'),
      promiseIds: r.strings('promiseIds', optional: true),
      prayerIds: r.strings('prayerIds', optional: true),
      declarationIds: r.strings('declarationIds', optional: true),
      journeyIds: r.strings('journeyIds', optional: true),
      provenance: r.provenance(),
      review: r.review(),
    ),
    {'name', 'description', 'references', 'promiseIds', 'prayerIds', 'declarationIds', 'journeyIds'},
  );

  static List<IntelPromise> promises(Object? json) => _records(
    json,
    'promises.json',
    'promises',
    (r) => IntelPromise(
      id: r.str('id'),
      title: r.str('title'),
      references: r.refs('references'),
      category: r.str('category'),
      themes: r.strings('themes', optional: true),
      originalAudience: r.str('originalAudience'),
      scope: r.enumValue('scope', PromiseScope.values),
      conditions: r.strings('conditions', optional: true),
      contextNote: r.optStr('contextNote') ?? '',
      receptionGuidance: r.str('receptionGuidance'),
      provenance: r.provenance(),
      review: r.review(),
    ),
    {
      'title',
      'references',
      'category',
      'themes',
      'originalAudience',
      'scope',
      'conditions',
      'contextNote',
      'receptionGuidance',
    },
  );

  static List<Blessing> blessings(Object? json) => _records(
    json,
    'blessings.json',
    'blessings',
    (r) => Blessing(
      id: r.str('id'),
      title: r.str('title'),
      category: r.str('category'),
      themes: r.strings('themes', optional: true),
      text: r.str('text'),
      references: r.refs('references'),
      groundingNote: r.optStr('groundingNote') ?? '',
      provenance: r.provenance(),
      review: r.review(),
    ),
    {'title', 'category', 'themes', 'text', 'references', 'groundingNote'},
  );

  static List<IntelPrayer> prayers(Object? json) => _records(
    json,
    'prayers.json',
    'prayers',
    (r) => IntelPrayer(
      id: r.str('id'),
      title: r.str('title'),
      situationId: r.str('situationId'),
      text: r.str('text'),
      references: r.refs('references'),
      provenance: r.provenance(),
      review: r.review(),
    ),
    {'title', 'situationId', 'text', 'references'},
  );

  static List<Declaration> declarations(Object? json) => _records(
    json,
    'declarations.json',
    'declarations',
    (r) => Declaration(
      id: r.str('id'),
      title: r.str('title'),
      category: r.str('category'),
      themes: r.strings('themes', optional: true),
      text: r.str('text'),
      firstPersonText: r.str('firstPersonText'),
      references: r.refs('references'),
      groundingNote: r.optStr('groundingNote') ?? '',
      provenance: r.provenance(),
      review: r.review(),
    ),
    {'title', 'category', 'themes', 'text', 'firstPersonText', 'references', 'groundingNote'},
  );

  static List<IntelCommand> commands(Object? json) => _records(
    json,
    'commands.json',
    'commands',
    (r) => IntelCommand(
      id: r.str('id'),
      title: r.str('title'),
      references: r.refs('references'),
      commandType: r.enumValue('commandType', CommandType.values),
      addressedTo: r.str('addressedTo'),
      themes: r.strings('themes', optional: true),
      relatedPromiseIds: r.strings('relatedPromiseIds', optional: true),
      contextNote: r.optStr('contextNote') ?? '',
      provenance: r.provenance(),
      review: r.review(),
    ),
    {'title', 'references', 'commandType', 'addressedTo', 'themes', 'relatedPromiseIds', 'contextNote'},
  );

  static List<IdentityTheme> identityThemes(Object? json) => _records(
    json,
    'identity_themes.json',
    'identityThemes',
    (r) => IdentityTheme(
      id: r.str('id'),
      title: r.str('title'),
      references: r.refs('references'),
      holder: r.str('holder'),
      note: r.str('note'),
      themes: r.strings('themes', optional: true),
      provenance: r.provenance(),
      review: r.review(),
    ),
    {'title', 'references', 'holder', 'note', 'themes'},
  );

  static List<WorshipTheme> worshipThemes(Object? json) => _records(
    json,
    'worship_themes.json',
    'worshipThemes',
    (r) => WorshipTheme(
      id: r.str('id'),
      title: r.str('title'),
      references: r.refs('references'),
      worshipKind: r.enumValue('worshipKind', WorshipKind.values),
      themes: r.strings('themes', optional: true),
      provenance: r.provenance(),
      review: r.review(),
    ),
    {'title', 'references', 'worshipKind', 'themes'},
  );

  static List<ScriptureRelationship> relationships(Object? json) => _records(
    json,
    'relationships.json',
    'relationships',
    (r) => ScriptureRelationship(
      id: r.str('id'),
      from: r.ref('from'),
      to: r.ref('to'),
      type: r.enumValue('type', RelationshipType.values),
      bidirectional: r.boolean('bidirectional', fallback: true),
      explanation: r.str('explanation'),
      provenance: r.provenance(),
      review: r.review(),
    ),
    {'from', 'to', 'type', 'bidirectional', 'explanation'},
  );

  static List<Journey> journeys(Object? json) => _records(
    json,
    'journeys.json',
    'journeys',
    (r) => Journey(
      id: r.str('id'),
      title: r.str('title'),
      description: r.str('description'),
      situationId: r.str('situationId'),
      steps: [
        for (final (i, s) in r.list('steps').indexed)
          () {
            final x = _Reader(s, '${r.where}.steps[$i]', {'order', 'type', 'note', 'reference', 'targetId'});
            return JourneyStep(
              order: x.integer('order'),
              type: x.enumValue('type', JourneyStepType.values),
              note: x.str('note'),
              reference: x.optStr('reference') == null ? null : x.ref('reference'),
              targetId: x.optStr('targetId'),
            );
          }(),
      ],
      provenance: r.provenance(),
      review: r.review(),
    ),
    {'title', 'description', 'situationId', 'steps'},
  );

  static ({List<TaxonomyTerm> terms, List<TaxonomyLink> links}) taxonomy(Object? json) {
    final top = _Reader(json, 'taxonomy.json', {'schemaVersion', 'corpusVersion', 'terms', 'links'});
    if (top.integer('schemaVersion') != IntelManifest.supportedSchema) {
      throw const IntelFormatException('taxonomy.json: schema is not supported');
    }
    top.str('corpusVersion');
    return (
      terms: [
        for (final (i, t) in top.list('terms').indexed)
          () {
            final r = _Reader(t, 'taxonomy.json › terms[$i]', {'id', 'label', 'kind'});
            return TaxonomyTerm(id: r.str('id'), label: r.str('label'), kind: r.str('kind'));
          }(),
      ],
      links: [
        for (final (i, l) in top.list('links').indexed)
          () {
            final r = _Reader(l, 'taxonomy.json › links[$i]', {'termId', 'objectType', 'objectId'});
            return TaxonomyLink(
              termId: r.str('termId'),
              objectType: r.enumValue('objectType', IntelKind.values),
              objectId: r.str('objectId'),
            );
          }(),
      ],
    );
  }
}
