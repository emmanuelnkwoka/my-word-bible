import 'package:flutter/foundation.dart';

import '../../../data/models/bible_canon.dart';
import '../../../data/models/intelligence.dart';
import '../../../data/models/mwb_rule.dart' show RiskLevel;
import '../../../data/models/scripture_reference.dart';
import '../../../data/repositories/bible_repository.dart';
import '../../../data/repositories/intelligence_repository.dart';

/// Read-only view of one translation's text, used to check references.
class CanonicalScripture {
  CanonicalScripture(this.versionId, this._chapters);

  final String versionId;

  /// bookId → chapters → verse texts ('' for verses the translation omits).
  final Map<String, List<List<String>>> _chapters;

  static Future<CanonicalScripture> load(BibleRepository bible, String versionId) async {
    final chapters = <String, List<List<String>>>{};
    for (final b in await bible.books(versionId)) {
      chapters[b.id] = [
        for (var c = 1; c <= b.chapterCount; c++) [for (final v in await bible.chapter(versionId, b.id, c)) v.text],
      ];
    }
    return CanonicalScripture(versionId, chapters);
  }

  /// Text of one verse; null when the verse does not exist, '' when omitted.
  String? verse(String bookId, int chapter, int verse) {
    final ch = _chapters[bookId];
    if (ch == null || chapter < 1 || chapter > ch.length) return null;
    final vs = ch[chapter - 1];
    if (verse < 1 || verse > vs.length) return null;
    return vs[verse - 1];
  }

  /// Joined text of a verse reference or range; null if any verse is absent.
  String? text(ScriptureReference r) {
    if (r.verseStart == null) return null;
    final parts = <String>[];
    for (var v = r.verseStart!; v <= (r.verseEnd ?? r.verseStart!); v++) {
      final t = verse(r.bookId, r.chapter, v);
      if (t == null) return null;
      parts.add(t);
    }
    return parts.join(' ');
  }

  /// True when the reference exists but at least one verse is omitted.
  bool hasOmission(ScriptureReference r) {
    if (r.verseStart == null) return false;
    for (var v = r.verseStart!; v <= (r.verseEnd ?? r.verseStart!); v++) {
      if (verse(r.bookId, r.chapter, v)?.isEmpty ?? false) return true;
    }
    return false;
  }
}

enum IntelSeverity { error, warning }

enum IntelIssueCode {
  duplicateId,
  unresolvedReference,
  wholeChapterReference,
  omittedInTranslation,
  unknownTarget,
  orphan,
  prayerNeedsTwoReferences,
  genderedPronoun,
  placeholderMisuse,
  missingExplanation,
  journeyStepUnresolved,
  journeyOrder,
  contextIncomplete,
  missingContext,
  conditionMissing,
  corporateAsIndividual,
  scriptureCopiedAsEditorial,
  approvalNotRecorded,
  riskUnderstated,
  rejectedSeedReused,
  provenanceIncomplete,
  linkInconsistent,
  editorialLabelMissing,
}

@immutable
class IntelIssue {
  const IntelIssue(this.code, this.severity, this.objectId, this.message);
  final IntelIssueCode code;
  final IntelSeverity severity;

  /// The record (or taxonomy term) with the problem.
  final String objectId;
  final String message;

  bool get isError => severity == IntelSeverity.error;

  @override
  String toString() => '${severity.name}:${code.name}: $objectId: $message';
}

@immutable
class IntelValidationReport {
  const IntelValidationReport(this.issues, {required this.recordsChecked, required this.referencesChecked});
  final List<IntelIssue> issues;
  final int recordsChecked;
  final int referencesChecked;

  List<IntelIssue> get errors => issues.where((i) => i.isError).toList();
  List<IntelIssue> get warnings => issues.where((i) => !i.isError).toList();
  bool get passed => errors.isEmpty;

  bool has(IntelIssueCode code, [String? objectId]) =>
      issues.any((i) => i.code == code && (objectId == null || i.objectId == objectId));
}

/// Checks the corpus for referential integrity and Scripture integrity.
///
/// [canonical] is the translation references must resolve in (KJV).
/// [others] are further installed translations; a reference that is
/// omitted or absent there is reported as a warning.
class IntelligenceValidator {
  const IntelligenceValidator({required this.canonical, this.others = const []});

  final CanonicalScripture canonical;
  final List<CanonicalScripture> others;

  /// Lower-case gendered pronouns are never allowed in declarations;
  /// capitalised He/Him/His are allowed only as reverent references to God.
  static final _genderedLower = RegExp(r'\b(he|him|his|himself|she|her|hers|herself)\b');
  static final _feminineCapital = RegExp(r'\b(She|Her|Hers|Herself)\b');
  static final _placeholder = RegExp(r'\{[^}]*\}|⟦[^⟧]*⟧');

  IntelValidationReport validate(IntelligenceCorpus c) {
    final issues = <IntelIssue>[];
    var refs = 0;
    void err(IntelIssueCode code, String id, String m) => issues.add(IntelIssue(code, IntelSeverity.error, id, m));
    void warn(IntelIssueCode code, String id, String m) => issues.add(IntelIssue(code, IntelSeverity.warning, id, m));

    // 3. Duplicate ids (records and taxonomy terms share one id space).
    final seen = <String, IntelKind>{};
    for (final r in c.records) {
      final prev = seen[r.id];
      if (prev != null) err(IntelIssueCode.duplicateId, r.id, 'Id used by a ${prev.label} and a ${r.kind.label}.');
      seen[r.id] = r.kind;
    }
    final termIds = <String>{};
    for (final t in c.terms) {
      if (!termIds.add(t.id) || seen.containsKey(t.id)) {
        err(IntelIssueCode.duplicateId, t.id, 'Taxonomy term id is not unique.');
      }
    }

    // 1. Every Scripture reference resolves.
    void checkRef(String id, ScriptureReference r, String field) {
      refs++;
      if (r.verseStart == null) {
        err(IntelIssueCode.wholeChapterReference, id, '$field "${_compact(r)}" must name verses, not a whole chapter.');
        return;
      }
      if (BibleCanon.byId(r.bookId) == null) {
        err(IntelIssueCode.unresolvedReference, id, '$field "${_compact(r)}": unknown book ${r.bookId}.');
        return;
      }
      if (r.verseEnd != null && r.verseEnd! < r.verseStart!) {
        err(IntelIssueCode.unresolvedReference, id, '$field "${_compact(r)}": range ends before it starts.');
        return;
      }
      if (canonical.text(r) == null) {
        err(
          IntelIssueCode.unresolvedReference,
          id,
          '$field "${_compact(r)}" does not exist in ${canonical.versionId}.',
        );
        return;
      }
      for (final o in others) {
        if (o.text(r) == null) {
          warn(IntelIssueCode.omittedInTranslation, id, '$field "${_compact(r)}" is not in ${o.versionId}.');
        } else if (o.hasOmission(r)) {
          warn(
            IntelIssueCode.omittedInTranslation,
            id,
            '$field "${_compact(r)}" includes a verse ${o.versionId} omits.',
          );
        }
      }
    }

    for (final r in c.records) {
      if (r is Journey) {
        for (final s in r.steps) {
          if (s.reference != null) checkRef(r.id, s.reference!, 'Step ${s.order}');
        }
      } else if (r is ScriptureRelationship) {
        checkRef(r.id, r.from, 'from');
        checkRef(r.id, r.to, 'to');
      } else {
        for (final x in r.references) {
          checkRef(r.id, x, 'reference');
        }
      }
    }

    // 4. Orphans: records that lead nowhere.
    for (final r in c.records) {
      if (r is! Journey && r.references.isEmpty) {
        err(IntelIssueCode.orphan, r.id, 'A ${r.kind.label.toLowerCase()} must cite at least one Scripture reference.');
      }
    }
    final linkedTerms = c.links.map((l) => l.termId).toSet();
    for (final t in c.terms) {
      if (!linkedTerms.contains(t.id)) err(IntelIssueCode.orphan, t.id, 'Taxonomy term is not linked to any record.');
    }

    // 2. Referenced ids exist and have the right kind.
    void target<T extends IntelRecord>(String from, String id, String what) {
      if (c.typed<T>(id) == null) {
        err(
          IntelIssueCode.unknownTarget,
          from,
          '$what "$id" does not exist${c.byId(id) == null ? '' : ' as that kind'}.',
        );
      }
    }

    for (final s in c.situations) {
      for (final id in s.promiseIds) {
        target<IntelPromise>(s.id, id, 'Promise');
      }
      for (final id in s.prayerIds) {
        target<IntelPrayer>(s.id, id, 'Prayer');
      }
      for (final id in s.declarationIds) {
        target<Declaration>(s.id, id, 'Declaration');
      }
      for (final id in s.journeyIds) {
        target<Journey>(s.id, id, 'Journey');
      }
      final prayers = c.prayers.where((p) => p.situationId == s.id).map((p) => p.id).toSet();
      final journeys = c.journeys.where((j) => j.situationId == s.id).map((j) => j.id).toSet();
      if (!setEquals(prayers, s.prayerIds.toSet()) || !setEquals(journeys, s.journeyIds.toSet())) {
        warn(
          IntelIssueCode.linkInconsistent,
          s.id,
          'Linked prayers/journeys differ from those that name this situation.',
        );
      }
    }
    for (final p in c.prayers) {
      target<LifeSituation>(p.id, p.situationId, 'Situation');
    }
    for (final j in c.journeys) {
      target<LifeSituation>(j.id, j.situationId, 'Situation');
    }
    for (final m in c.commands) {
      for (final id in m.relatedPromiseIds) {
        target<IntelPromise>(m.id, id, 'Promise');
      }
    }
    for (final l in c.links) {
      if (!termIds.contains(l.termId)) {
        err(IntelIssueCode.unknownTarget, l.objectId, 'Taxonomy term "${l.termId}" does not exist.');
      }
      final o = c.byId(l.objectId);
      if (o == null || o.kind != l.objectType) {
        err(IntelIssueCode.unknownTarget, l.objectId, 'Taxonomy link points at a missing ${l.objectType.label}.');
      }
    }
    final liveIds = seen.keys.toSet();
    for (final x in c.manifest.rejected) {
      if (liveIds.contains(x.seedId)) {
        err(IntelIssueCode.rejectedSeedReused, x.seedId, 'A rejected seed record is present in the live corpus.');
      }
      final rep = x.replacement;
      if (rep != null && !liveIds.contains(rep)) {
        err(IntelIssueCode.unknownTarget, x.seedId, 'Replacement "$rep" for a rejected record does not exist.');
      }
    }

    // 5. Prayers cite two or more references.
    for (final p in c.prayers) {
      if (p.references.length < 2) {
        err(
          IntelIssueCode.prayerNeedsTwoReferences,
          p.id,
          'A prayer needs at least two supporting references; it has ${p.references.length}.',
        );
      }
    }

    // 6. Declarations: no gendered pronouns for the reader; safe name token.
    for (final d in c.declarations) {
      for (final (field, text) in [('text', d.text), ('firstPersonText', d.firstPersonText)]) {
        final g = [
          ..._genderedLower.allMatches(text),
          ..._feminineCapital.allMatches(text),
        ].map((m) => m.group(0)).toSet();
        if (g.isNotEmpty) {
          err(IntelIssueCode.genderedPronoun, d.id, '$field uses gender-specific pronoun(s): ${g.join(', ')}.');
        }
        final bad = _placeholder
            .allMatches(text)
            .map((m) => m.group(0)!)
            .where((p) => p != Declaration.namePlaceholder);
        if (bad.isNotEmpty) {
          err(IntelIssueCode.placeholderMisuse, d.id, '$field uses unknown placeholder(s): ${bad.join(', ')}.');
        }
      }
      if (!d.text.contains(Declaration.namePlaceholder)) {
        err(IntelIssueCode.placeholderMisuse, d.id, 'text must use ${Declaration.namePlaceholder} for the reader.');
      }
      if (d.firstPersonText.contains(Declaration.namePlaceholder)) {
        err(IntelIssueCode.placeholderMisuse, d.id, 'firstPersonText must not contain ${Declaration.namePlaceholder}.');
      }
    }
    // Placeholders belong only in declarations.
    for (final r in c.records) {
      if (r is Declaration) continue;
      for (final t in _texts(r)) {
        if (_placeholder.hasMatch(t)) {
          err(IntelIssueCode.placeholderMisuse, r.id, 'Name placeholders are only allowed in declarations.');
          break;
        }
      }
    }

    // 7. Relationships are typed and explained.
    for (final r in c.relationships) {
      if (r.explanation.trim().length < 20) {
        err(IntelIssueCode.missingExplanation, r.id, 'A relationship needs a defensible explanation.');
      }
      if (r.from == r.to) err(IntelIssueCode.missingExplanation, r.id, 'A relationship cannot link a verse to itself.');
    }

    // 8. Journey steps resolve and keep their order.
    for (final j in c.journeys) {
      if (j.steps.length < 2) err(IntelIssueCode.orphan, j.id, 'A journey needs at least two steps.');
      for (final (i, s) in j.steps.indexed) {
        if (s.order != i + 1) err(IntelIssueCode.journeyOrder, j.id, 'Step ${i + 1} has order ${s.order}.');
        final ok = switch (s.type) {
          JourneyStepType.verse => s.reference != null && s.targetId == null,
          JourneyStepType.situation => c.typed<LifeSituation>(s.targetId ?? '') != null,
          JourneyStepType.promise => c.typed<IntelPromise>(s.targetId ?? '') != null,
          JourneyStepType.identity => c.typed<IdentityTheme>(s.targetId ?? '') != null,
          JourneyStepType.worship => c.typed<WorshipTheme>(s.targetId ?? '') != null,
          JourneyStepType.command => c.typed<IntelCommand>(s.targetId ?? '') != null,
          JourneyStepType.prayer => c.typed<IntelPrayer>(s.targetId ?? '') != null,
          JourneyStepType.declaration => c.typed<Declaration>(s.targetId ?? '') != null,
          JourneyStepType.blessing => c.typed<Blessing>(s.targetId ?? '') != null,
        };
        if (!ok) {
          err(
            IntelIssueCode.journeyStepUnresolved,
            j.id,
            'Step ${s.order} (${s.type.name} ${s.targetId ?? ''}) does not resolve.',
          );
        }
        if (s.note.trim().isEmpty) err(IntelIssueCode.journeyStepUnresolved, j.id, 'Step ${s.order} has no note.');
      }
    }

    // 9. Contexts identify speaker, author and audience.
    for (final x in c.contexts) {
      for (final (field, v) in [
        ('speaker', x.speaker),
        ('author', x.author),
        ('originalAudience', x.originalAudience),
      ]) {
        if (v.trim().isEmpty) {
          err(IntelIssueCode.contextIncomplete, x.id, '$field is empty (write "Unknown" if it is not known).');
        }
      }
      if (x.addressee == IntelAddressee.unspecified) {
        warn(IntelIssueCode.contextIncomplete, x.id, 'Addressee is not recorded.');
      }
      if (x.isConditional && x.conditionNote.trim().isEmpty) {
        err(IntelIssueCode.conditionMissing, x.id, 'A conditional passage must state its condition.');
      }
      final minimum = _minimumRisk(x);
      if (x.personalisationRisk.index < minimum.index) {
        err(
          IntelIssueCode.riskUnderstated,
          x.id,
          'Personalisation risk ${x.personalisationRisk.label} is below ${minimum.label}.',
        );
      }
    }

    // 10–11. Promises keep conditions and corporate scope.
    for (final p in c.promises) {
      if (p.originalAudience.trim().isEmpty) err(IntelIssueCode.contextIncomplete, p.id, 'originalAudience is empty.');
      if (p.receptionGuidance.trim().isEmpty) {
        err(IntelIssueCode.contextIncomplete, p.id, 'receptionGuidance is empty.');
      }
      for (final r in p.references) {
        final ctx = c.contextsFor(r).firstOrNull;
        if (ctx == null) {
          err(
            IntelIssueCode.missingContext,
            p.id,
            'No passage context for ${_compact(r)}; a promise needs its audience.',
          );
          continue;
        }
        if (ctx.isConditional && p.conditions.isEmpty) {
          err(
            IntelIssueCode.conditionMissing,
            p.id,
            '${_compact(r)} is conditional ("${ctx.conditionNote}") but the promise lists no conditions.',
          );
        }
        if (ctx.addressee == IntelAddressee.collective && p.scope != PromiseScope.corporate) {
          err(
            IntelIssueCode.corporateAsIndividual,
            p.id,
            '${_compact(r)} was given to a people; scope must be corporate, not ${p.scope.name}.',
          );
        }
        if (ctx.addressee == IntelAddressee.specificIndividual && p.scope == PromiseScope.general) {
          err(
            IntelIssueCode.corporateAsIndividual,
            p.id,
            '${_compact(r)} was given to a specific person; it cannot be a general promise.',
          );
        }
      }
    }
    for (final r in [...c.declarations, ...c.blessings]) {
      final collective = r.references.where(
        (x) => c.contextsFor(x).firstOrNull?.addressee == IntelAddressee.collective,
      );
      final note = r is Declaration ? r.groundingNote : (r as Blessing).groundingNote;
      if (collective.isNotEmpty && note.trim().isEmpty) {
        err(
          IntelIssueCode.corporateAsIndividual,
          r.id,
          'Grounded in corporate passage(s) ${collective.map(_compact).join(', ')} without a groundingNote.',
        );
      }
    }
    for (final t in c.identityThemes) {
      if (t.holder.trim().isEmpty || t.note.trim().isEmpty) {
        err(
          IntelIssueCode.corporateAsIndividual,
          t.id,
          'An identity theme must say who it describes and how it is received.',
        );
      }
    }

    // 12 + 14. Editorial text is labelled and is not a copy of Scripture.
    for (final e in <EditorialContent>[...c.prayers, ...c.blessings, ...c.declarations]) {
      if (e.isScripture || e.displayLabel.trim().isEmpty) {
        err(IntelIssueCode.editorialLabelMissing, e.id, 'Editorial content must carry a non-Scripture label.');
      }
      final texts = [e.text, if (e is Declaration) e.firstPersonText].map(_norm);
      for (final r in e.references) {
        final verse = canonical.text(r);
        if (verse != null && texts.contains(_norm(verse))) {
          err(
            IntelIssueCode.scriptureCopiedAsEditorial,
            e.id,
            'Editorial text is identical to ${_compact(r)}; Scripture must be shown as Scripture.',
          );
        }
      }
    }

    // 13. Nothing is marked reviewed without a recorded reviewer and date.
    for (final r in c.records) {
      if (r.review.status == EditorialStatus.editoriallyReviewed &&
          ((r.review.reviewer ?? '').trim().isEmpty || (r.review.reviewedOn ?? '').trim().isEmpty)) {
        err(IntelIssueCode.approvalNotRecorded, r.id, 'Marked reviewed without a recorded reviewer and date.');
      }
      final p = r.provenance;
      final complete = switch (p.origin) {
        ProvenanceOrigin.demoSeed => (p.seedId ?? '').isNotEmpty,
        ProvenanceOrigin.newlyCurated => p.basis.trim().isNotEmpty,
        ProvenanceOrigin.historicalExport => (p.seedId ?? '').isNotEmpty,
      };
      if (!complete) err(IntelIssueCode.provenanceIncomplete, r.id, 'Provenance (${p.origin.name}) lacks its source.');
    }

    return IntelValidationReport(List.unmodifiable(issues), recordsChecked: c.records.length, referencesChecked: refs);
  }

  /// The lowest personalisation risk a context may declare.
  static RiskLevel _minimumRisk(IntelContext x) {
    if (x.voice == IntelVoice.god) return RiskLevel.critical;
    if (x.voice == IntelVoice.jesus || x.isConditional) return RiskLevel.high;
    return switch (x.addressee) {
      IntelAddressee.collective ||
      IntelAddressee.specificIndividual ||
      IntelAddressee.god ||
      IntelAddressee.testimony ||
      IntelAddressee.narrative => RiskLevel.high,
      IntelAddressee.general || IntelAddressee.unspecified => RiskLevel.medium,
      IntelAddressee.representative => RiskLevel.low,
    };
  }

  static Iterable<String> _texts(IntelRecord r) => switch (r) {
    IntelContext x => [x.speaker, x.author, x.originalAudience, x.contextNote, x.conditionNote, x.personalisationNote],
    LifeSituation x => [x.name, x.description],
    IntelPromise x => [x.title, x.receptionGuidance, x.contextNote, ...x.conditions],
    Blessing x => [x.title, x.text, x.groundingNote],
    IntelPrayer x => [x.title, x.text],
    IntelCommand x => [x.title, x.contextNote],
    IdentityTheme x => [x.title, x.holder, x.note],
    WorshipTheme x => [x.title],
    ScriptureRelationship x => [x.explanation],
    Journey x => [x.title, x.description, for (final s in x.steps) s.note],
    _ => const <String>[],
  };

  static String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static String _compact(ScriptureReference r) =>
      '${r.bookId} ${r.chapter}${r.verseStart == null ? '' : ':${r.verseStart}'}${r.verseEnd == null ? '' : '-${r.verseEnd}'}';
}
