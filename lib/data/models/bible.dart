import 'package:flutter/foundation.dart';

import 'scripture_reference.dart';
import 'version_licence.dart';

export 'version_licence.dart';

/// Availability of a Bible version within the app (technical support only;
/// legal permission is tracked in [VersionLicence]).
enum BibleVersionStatus {
  /// Full text bundled on the device.
  installed,

  /// Freely licensed but not yet bundled in this build.
  notInstalled,

  /// Listed for transparency but requires publisher licensing / online service.
  requiresLicense,

  /// A personalised MWB edition whose engine exists but is not yet available
  /// for reading in this build.
  inDevelopment,
}

/// Whether a catalogue entry is an original translation or a personalised
/// MWB edition derived from one.
enum BibleVersionKind { original, personalised }

/// Whether personalised rendering can run for a catalogue entry.
enum PersonalisationAvailability {
  /// Original translations are never personalised.
  notApplicable,

  /// Engine and rules are being built; not yet available to readers.
  inDevelopment,

  /// The source translation's licence does not (yet) permit a derivative.
  blockedByLicence,

  /// Available to readers.
  available,
}

/// How personalisation rules may be published for an MWB edition.
enum ReviewPolicy {
  notApplicable,

  /// Only rules with a recorded human theological approval are shown to
  /// readers. Automated validation alone never publishes a rule.
  approvedRulesOnly,
}

@immutable
class BibleVersionInfo {
  const BibleVersionInfo({
    required this.id,
    required this.abbreviation,
    required this.name,
    required this.status,
    required this.note,
    this.kind = BibleVersionKind.original,
    this.sourceVersionId,
    this.licence,
    this.personalisation = PersonalisationAvailability.notApplicable,
    this.reviewPolicy = ReviewPolicy.notApplicable,
  });

  final String id;
  final String abbreviation;
  final String name;
  final BibleVersionStatus status;

  /// Honest description of the version's availability and licensing.
  final String note;

  final BibleVersionKind kind;

  /// For a personalised edition, the original translation it is derived from.
  final String? sourceVersionId;

  final VersionLicence? licence;
  final PersonalisationAvailability personalisation;
  final ReviewPolicy reviewPolicy;

  bool get isInstalled => status == BibleVersionStatus.installed;
  bool get isPersonalised => kind == BibleVersionKind.personalised;

  /// The original translation this entry belongs to (itself for originals).
  String get familyId => sourceVersionId ?? id;
}

/// A single verse of canonical text. [text] is exactly the translation text
/// and is never modified for personalisation.
@immutable
class Verse {
  const Verse({required this.bookId, required this.chapter, required this.number, required this.text});

  final String bookId;
  final int chapter;
  final int number;
  final String text;

  ScriptureReference get reference => ScriptureReference(bookId: bookId, chapter: chapter, verseStart: number);

  /// The translation does not include this verse (e.g. the WEB footnotes
  /// Luke 17:36). The number is kept so references stay aligned.
  bool get isOmitted => text.isEmpty;
}

/// A resolved passage: canonical verses plus their source.
@immutable
class Passage {
  const Passage({required this.reference, required this.versionId, required this.verses});

  final ScriptureReference reference;
  final String versionId;
  final List<Verse> verses;

  String get text => verses.map((v) => v.text).join(' ');
}

/// Book + chapter availability for a loaded translation.
@immutable
class BibleBookInfo {
  const BibleBookInfo({required this.id, required this.name, required this.chapterCount, required this.isOld});

  final String id;
  final String name;
  final int chapterCount;
  final bool isOld;
}

@immutable
class VerseSearchHit {
  const VerseSearchHit({required this.verse, required this.versionId});
  final Verse verse;
  final String versionId;
}
