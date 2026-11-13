import 'package:flutter/foundation.dart';

import '../../../data/models/bible.dart';

/// What a rendered segment is.
enum SegmentKind {
  /// Unchanged canonical source text.
  source,

  /// Text inserted by a personalisation rule (the name and its punctuation).
  personalisation,

  /// A tracked replacement of source text (punctuation or a minimal
  /// grammatical adjustment). [RenderSegment.original] holds the source.
  adjustment,
}

/// One piece of a rendered verse, linked back to the source.
@immutable
class RenderSegment {
  const RenderSegment.source(this.text) : kind = SegmentKind.source, original = text, ruleId = null;

  const RenderSegment.personalisation(this.text, {required this.ruleId})
    : kind = SegmentKind.personalisation,
      original = '';

  const RenderSegment.adjustment(this.text, {required this.original, required this.ruleId})
    : kind = SegmentKind.adjustment;

  final SegmentKind kind;

  /// Text as displayed.
  final String text;

  /// The source text this segment stands for ('' for insertions).
  final String original;
  final String? ruleId;
}

/// Why a verse was (or was not) personalised.
enum RenderOutcome {
  personalised,

  /// Mode B: the verse text is unchanged and an approved title carries the
  /// reader's name ([RenderedVerse.title]).
  titled,

  /// No rule exists for this verse in this edition.
  noRule,

  /// The reader turned name insertion off.
  nameInsertionOff,

  /// No usable name in the profile.
  nameUnavailable,

  /// Rules exist but none may be published under the current policy (e.g.
  /// not yet approved, rejected, retired).
  ruleNotPublishable,

  /// More than one distinct rule could apply; nothing is guessed.
  ruleConflict,

  /// The rule failed validation against the canonical text.
  validationFailed,

  /// The rule, edition or source version do not match.
  versionMismatch,

  /// An unexpected error; the source is shown.
  renderError,
}

/// A verse as shown in an MWB edition. Always carries the untouched source.
@immutable
class RenderedVerse {
  const RenderedVerse({
    required this.source,
    required this.sourceVersionId,
    required this.targetVersionId,
    required this.segments,
    required this.outcome,
    this.ruleId,
    this.isPreview = false,
    this.title,
  });

  /// A verse shown exactly as the source.
  factory RenderedVerse.original(
    Verse source, {
    required String sourceVersionId,
    required String targetVersionId,
    required RenderOutcome outcome,
    String? ruleId,
  }) => RenderedVerse(
    source: source,
    sourceVersionId: sourceVersionId,
    targetVersionId: targetVersionId,
    segments: [RenderSegment.source(source.text)],
    outcome: outcome,
    ruleId: ruleId,
  );

  final Verse source;
  final String sourceVersionId;
  final String targetVersionId;
  final List<RenderSegment> segments;
  final RenderOutcome outcome;
  final String? ruleId;

  /// Rendered with an unapproved rule under the reviewer preview policy.
  /// Must be labelled "Proposed — not approved" wherever it is shown.
  final bool isPreview;

  /// Mode B title with the reader's name; editorial text, not Scripture.
  final String? title;

  /// Mode A: the text itself carries the reader's name.
  bool get isPersonalised => outcome == RenderOutcome.personalised;

  /// Mode B: unchanged text with a personalised title.
  bool get isTitled => outcome == RenderOutcome.titled;

  /// Display text.
  String get text => segments.map((s) => s.text).join();

  /// The source verse rebuilt from the segments. Equal to [Verse.text]
  /// character for character.
  String get originalText => segments.map((s) => s.original).join();
}
