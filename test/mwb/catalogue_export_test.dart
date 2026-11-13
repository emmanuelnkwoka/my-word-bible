// Writes the personalisation review records consumed by
// tool/export_review_catalogue.js (Excel, CSV and printable exports).
//
//   EXPORT_REVIEW_CATALOGUE=1 flutter test test/mwb/catalogue_export_test.dart
//   node tool/export_review_catalogue.js
//
// Validation results come from the app's own PersonalisationValidator, so the
// exports show exactly what the app enforces. Nothing here approves anything.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/core/storage/key_value_store.dart';
import 'package:my_word_bible/data/models/mwb_rule.dart';
import 'package:my_word_bible/data/models/personalisation_catalogue.dart';
import 'package:my_word_bible/data/repositories/mwb_ruleset_repository.dart';
import 'package:my_word_bible/data/repositories/theological_review_repository.dart';
import 'package:my_word_bible/features/personalisation/domain/personalisation_validator.dart';
import 'package:my_word_bible/features/personalisation/domain/review_queue.dart';
import 'package:my_word_bible/features/personalisation/domain/ruleset_processor.dart';

import '../helpers/test_app.dart';
import 'mwb_test_support.dart';

const _out = 'exports/personalisation-review/review_records.json';

String _join(Iterable<String> xs) => xs.where((x) => x.trim().isNotEmpty).join(' | ');

void main() {
  final enabled = Platform.environment['EXPORT_REVIEW_CATALOGUE'] == '1';

  test('export review records', () async {
    final catalogues = AssetPersonalisationCatalogueRepository(loader: (p) async => File(p).readAsStringSync());
    final service = ReviewQueueService(
      rulesets: AssetMwbRulesetRepository(loader: (p) async => File(p).readAsStringSync(), catalogue: catalogues),
      bible: sharedTestBible,
      contexts: contextRepo(),
      reviews: LocalTheologicalReviewRepository(InMemoryKeyValueStore()),
      processor: MwbRulesetProcessor(PersonalisationValidator(catalogue)),
    );
    final editions = <Map<String, dynamic>>[];
    for (final edition in ['KJV-MWB', 'WEB-MWB']) {
      final cat = await catalogues.catalogue(edition);
      final source = cat.sourceVersionId;
      final queue = await service.queue(edition);
      final ruleset = await service.effectiveRuleset(edition);

      final verses = <List<Object>>[];
      for (final b in cat.books) {
        for (var c = 1; c <= b.chapters.length; c++) {
          final canon = await sharedTestBible.chapter(source, b.id, c);
          for (var v = 1; v <= b.chapters[c - 1].length; v++) {
            final k = cat.decode(b.chapters[c - 1][v - 1]);
            verses.add([b.id, b.name, c, v, k.verseClass.name, k.reason.code, canon[v - 1].text]);
          }
        }
      }

      final proposals = <Map<String, dynamic>>[];
      for (final p in queue) {
        final r = p.rule;
        final book = cat.book(r.reference.bookId)!;
        final ctx = p.context;
        final issues = p.report.issues;
        String check(Set<ValidationCode> codes, String ok) {
          final hit = issues.where((i) => codes.contains(i.code)).map((i) => '${i.severity.name}: ${i.message}');
          return hit.isEmpty ? ok : hit.join(' | ');
        }

        final k = cat.classify(r.reference.bookId, r.reference.chapter, r.reference.verseStart!);
        proposals.add({
          'id': r.id,
          'ruleVersion': r.ruleVersion,
          'proposalVersion': r.ruleVersion,
          'edition': edition,
          'translation': source,
          'bookId': r.reference.bookId,
          'book': book.name,
          'chapter': r.reference.chapter,
          'verse': r.reference.verseStart,
          'reference': r.reference.label,
          'original': p.canonicalText ?? '',
          'proposed': r.presentationMode == PresentationMode.nameInTitle ? (p.canonicalText ?? '') : (p.previewText ?? ''),
          'mode': r.presentationMode.name,
          'modeLabel': r.presentationMode == PresentationMode.nameInText ? 'Mode A — name in the Scripture' : 'Mode B — name in the title',
          'title': r.titleTemplate?.replaceAll(namePlaceholder, reviewNamePlaceholder) ?? '',
          'titleSource': r.meta.titleSource ?? '',
          'operations': _join(
            r.edits.map((e) => '${e.operation.name} ${e.position.name} “${e.anchor}”${e.occurrence == null ? '' : ' #${e.occurrence}'} → “${e.text}”'),
          ),
          'placeholder': '$namePlaceholder (full, first or preferred name, as the reader chooses; titles use the first or preferred name)',
          'author': r.meta.author.isNotEmpty ? r.meta.author : (ctx?.author ?? book.author),
          'speaker': r.meta.speaker.isNotEmpty ? r.meta.speaker : (ctx?.speaker.label ?? ''),
          'audience': r.meta.audience.isNotEmpty ? r.meta.audience : (ctx?.originalAudience ?? book.audience),
          'classification': k?.verseClass.label ?? '',
          'reason': k?.reason.label ?? '',
          'contextSource': r.meta.contextSource.isNotEmpty ? r.meta.contextSource : (ctx == null ? 'Hand-authored rule' : 'Passage context (assets/mwb/passage_context.json)'),
          'literaryForm': r.meta.literaryForm.isNotEmpty ? r.meta.literaryForm : book.form,
          'rationale': r.meta.rationale.isNotEmpty ? r.meta.rationale : _join(r.riskReasons),
          'grammar': p.report.passed
              ? 'Passed${r.grammaticalConditions.isEmpty ? '' : ': ${_join(r.grammaticalConditions)}'}'
              : 'Failed: ${_join(issues.where((i) => i.isError).map((i) => i.message))}',
          'meaning': check({
            ValidationCode.recoveryFailed,
            ValidationCode.sourceWordDeleted,
            ValidationCode.excessiveChange,
            ValidationCode.foreignVocabulary,
            ValidationCode.capitalisationChanged,
            ValidationCode.titleModeEditsScripture,
            ValidationCode.genderedTermChanged,
          }, r.presentationMode == PresentationMode.nameInTitle ? 'Scripture unchanged' : 'Source recoverable; no source word changed'),
          'pronouns': check({
            ValidationCode.pronounReplaced,
            ValidationCode.residualPronoun,
            ValidationCode.verbAgreement,
            ValidationCode.titleFirstPerson,
          }, 'No pronoun or person/number change'),
          'automated': p.report.passed ? 'Passed' : 'Failed',
          'warnings': _join(issues.where((i) => !i.isError).map((i) => i.message)),
          'risk': p.risk.label,
          'confidence': r.meta.confidence,
          'uncertainty': r.meta.uncertainty,
          'reviewQuestion': r.reviewQuestion ?? '',
          'provenance': r.meta.isGenerated
              ? 'Generated by tool/build_personalisation_catalogue.js, catalogue ${r.meta.catalogueVersion}, generator rule v${r.meta.generatorRuleVersion}'
              : 'Hand-authored (assets/mwb/rulesets/${edition.toLowerCase()}.json)',
          'ruleSetVersion': ruleset.rulesetVersion,
          'status': p.status.name,
          'statusLabel': p.status.label,
          'history': _join(
            r.reviews.map(
              (h) =>
                  '${h.at.toIso8601String().substring(0, 10)} ${h.action.name} by ${h.reviewer ?? 'unnamed'} (v${h.ruleVersion})${h.rejectionReason ?? (h.comments.isEmpty ? '' : ': ${h.comments}')}',
            ),
          ),
          'notes': r.notes,
        });
      }
      editions.add({
        'edition': edition,
        'translation': source,
        'catalogueVersion': cat.catalogueVersion,
        'generatorRuleVersion': cat.generatorRuleVersion,
        'reasons': [
          for (final r in cat.reasons) {'code': r.code, 'class': r.verseClass.name, 'label': r.label, 'explanation': r.explanation},
        ],
        'classes': [for (final c in VerseClass.values) {'code': c.name, 'label': c.label}],
        'verses': verses,
        'proposals': proposals,
      });
    }
    if (enabled) {
      final f = File(_out)..parent.createSync(recursive: true);
      f.writeAsStringSync(jsonEncode({'schema': 1, 'editions': editions}));
    }
    expect(editions, hasLength(2));
    expect(editions.every((e) => (e['proposals'] as List).every((p) => p['status'] != 'approved')), isTrue);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
