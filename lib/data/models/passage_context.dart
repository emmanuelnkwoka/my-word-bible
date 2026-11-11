import 'package:flutter/foundation.dart';

import 'scripture_reference.dart';

/// Who a passage addresses.
enum AddresseeType {
  /// A named or specific historical individual (e.g. Gaius in 3 John).
  specificIndividual('Specific individual'),

  /// A representative address that speaks to any reader in that position
  /// (e.g. "my son" in Proverbs' wisdom instruction).
  representative('Representative address'),

  /// A people or community (e.g. Israel, a church).
  collective('Collective audience'),

  /// Addressed to God (prayer, praise).
  god('Addressed to God'),

  /// Not recorded or not clear.
  unspecified('Not recorded');

  const AddresseeType(this.label);
  final String label;
}

/// Whose voice is speaking.
enum SpeakerVoice {
  /// The author or narrator's own words.
  author('Author'),

  /// A human speaker within the text.
  human('Human speaker'),

  /// Direct speech from God ("thus saith the LORD", "I am thy God").
  divine('Direct divine speech');

  const SpeakerVoice(this.label);
  final String label;
}

/// Whether a relationship term is representative or refers to a specific,
/// real relationship that must be preserved.
enum RelationshipKind { representative, specific }

@immutable
class RelationshipReference {
  const RelationshipReference({required this.term, required this.kind, this.note = ''});
  final String term;
  final RelationshipKind kind;
  final String note;

  factory RelationshipReference.fromJson(Map<String, dynamic> j) => RelationshipReference(
    term: j['term'] as String,
    kind: RelationshipKind.values.byName(j['kind'] as String),
    note: j['note'] as String? ?? '',
  );
}

/// Human-authored context for a passage (a verse or a range). Never generated.
@immutable
class PassageContext {
  const PassageContext({
    required this.reference,
    required this.author,
    required this.speaker,
    required this.originalAudience,
    required this.addressee,
    this.historicalContext = '',
    this.literaryContext = '',
    this.isConditionalPromise = false,
    this.conditionNote = '',
    this.relationships = const [],
    this.theologicalNotes = '',
    this.through,
  });

  /// The verse or range this context covers.
  final ScriptureReference reference;
  final String author;
  final SpeakerVoice speaker;
  final String originalAudience;
  final AddresseeType addressee;
  final String historicalContext;
  final String literaryContext;

  /// The passage contains a promise that depends on a condition (possibly in
  /// a neighbouring verse).
  final bool isConditionalPromise;
  final String conditionNote;
  final List<RelationshipReference> relationships;
  final String theologicalNotes;

  /// Last verse covered, for ranges that run into a later chapter
  /// (e.g. Proverbs 1:8 through 9:18). Null when [reference] says it all.
  final ScriptureReference? through;

  int _key(int chapter, int verse) => chapter * 1000 + verse;

  int get _startKey => _key(reference.chapter, reference.verseStart ?? 1);

  int get _endKey {
    final end = through;
    if (end != null) return _key(end.chapter, end.verseEnd ?? end.verseStart ?? 999);
    return _key(reference.chapter, reference.verseEnd ?? reference.verseStart ?? 999);
  }

  bool covers(ScriptureReference verse) {
    if (verse.bookId != reference.bookId || verse.verseStart == null) return false;
    final key = _key(verse.chapter, verse.verseStart!);
    return key >= _startKey && key <= _endKey;
  }

  /// Size of the covered span; smaller spans are more specific.
  int get span => _endKey - _startKey;

  factory PassageContext.fromJson(Map<String, dynamic> j) => PassageContext(
    reference: ScriptureReference.parseCompact(j['reference'] as String),
    author: j['author'] as String,
    speaker: SpeakerVoice.values.byName(j['speaker'] as String),
    originalAudience: j['originalAudience'] as String,
    addressee: AddresseeType.values.byName(j['addressee'] as String),
    historicalContext: j['historicalContext'] as String? ?? '',
    literaryContext: j['literaryContext'] as String? ?? '',
    isConditionalPromise: j['isConditionalPromise'] as bool? ?? false,
    conditionNote: j['conditionNote'] as String? ?? '',
    relationships:
        (j['relationships'] as List?)?.cast<Map<String, dynamic>>().map(RelationshipReference.fromJson).toList() ??
        const [],
    theologicalNotes: j['theologicalNotes'] as String? ?? '',
    through: j['through'] == null ? null : ScriptureReference.parseCompact(j['through'] as String),
  );
}
