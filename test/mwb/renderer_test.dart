import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/core/storage/key_value_store.dart';
import 'package:my_word_bible/data/models/bible.dart';
import 'package:my_word_bible/data/models/mwb_rule.dart';
import 'package:my_word_bible/data/models/user_profile.dart';
import 'package:my_word_bible/features/personalisation/domain/mwb_renderer.dart';
import 'package:my_word_bible/features/personalisation/domain/mwb_rendering_service.dart';
import 'package:my_word_bible/features/personalisation/domain/personal_name.dart';
import 'package:my_word_bible/features/personalisation/domain/rendered_verse.dart';

import '../helpers/test_app.dart';
import 'mwb_test_support.dart';

Future<Verse> verse(String reference) async => (await sharedTestBible.passage('KJV', ref(reference))).verses.single;

Future<RenderedVerse> renderShipped(
  String reference, {
  PublicationPolicy policy = PublicationPolicy.approvedOnly,
  UserProfile? profile = emmanuel,
  Map<String, List<ReviewRecord>> approvals = const {},
}) async {
  final base = shippedRuleset();
  final rules = [for (final r in base.rules) r.withReviews(approvals[r.id] ?? const [])];
  final v = await verse(reference);
  return renderer(policy).render(
    source: v,
    sourceVersionId: 'KJV',
    targetVersionId: 'KJV-MWB',
    ruleset: rulesetOf(rules),
    name: PersonalNameResolver.resolve(profile),
    context: await contextRepo().contextFor(v.reference),
  );
}

void main() {
  group('Approved-only publication (production policy)', () {
    test('no shipped rule renders: nothing has a recorded human approval', () async {
      final ruleset = shippedRuleset();
      for (final rule in ruleset.rules) {
        final v = (await sharedTestBible.passage('KJV', rule.reference)).verses.single;
        final r = renderer().render(
          source: v,
          sourceVersionId: 'KJV',
          targetVersionId: 'KJV-MWB',
          ruleset: ruleset,
          name: PersonalNameResolver.resolve(emmanuel),
          context: await contextRepo().contextFor(v.reference),
        );
        expect(r.isPersonalised, isFalse, reason: rule.id);
        expect(r.text, v.text, reason: rule.id);
      }
      final pro2315 = await renderShipped('PRO 23:15');
      expect(pro2315.outcome, RenderOutcome.ruleNotPublishable);
      expect(pro2315.text, await kjv('PRO 23:15'));
    });

    test('a rule with a recorded, current human approval renders Proverbs 23:15', () async {
      final r = await renderShipped(
        'PRO 23:15',
        approvals: {
          'kjv-mwb.PRO.23.15.a': [testApproval()],
        },
      );
      expect(r.outcome, RenderOutcome.personalised);
      expect(r.isPreview, isFalse);
      expect(r.text, 'My son, Emmanuel Nkwoka, if thine heart be wise, my heart shall rejoice, even mine.');
      expect(r.originalText, await kjv('PRO 23:15'));
      expect(r.segments.map((s) => s.kind), [SegmentKind.source, SegmentKind.personalisation, SegmentKind.source]);
      expect(r.segments.first.text, 'My son,');
      expect(r.segments[1].text, ' Emmanuel Nkwoka,');
    });

    test('approval without a named reviewer cannot activate a rule', () async {
      final r = await renderShipped(
        'PRO 23:15',
        approvals: {
          'kjv-mwb.PRO.23.15.a': [testApproval(reviewer: null)],
        },
      );
      expect(r.isPersonalised, isFalse);
    });

    test('an approval for an earlier rule version cannot activate a rule', () async {
      final r = await renderShipped(
        'PRO 23:15',
        approvals: {
          'kjv-mwb.PRO.23.15.a': [testApproval(ruleVersion: 0)],
        },
      );
      expect(r.isPersonalised, isFalse);
    });

    test('a status of "approved" in the data without an approval record is ignored', () async {
      final v = await verse('PRO 3:1');
      final forged = makeRule(
        id: 'forged',
        reference: 'PRO 3:1',
        sourceText: v.text,
        edits: [nameAfter('My son,')],
        status: RuleStatus.approved,
      );
      final r = renderer().render(
        source: v,
        sourceVersionId: 'KJV',
        targetVersionId: 'KJV-MWB',
        ruleset: rulesetOf([forged]),
        name: PersonalNameResolver.resolve(emmanuel),
      );
      expect(r.outcome, RenderOutcome.ruleNotPublishable);
      expect(r.text, v.text);
    });

    test('a later rejection withdraws an approval', () async {
      final r = await renderShipped(
        'PRO 23:15',
        approvals: {
          'kjv-mwb.PRO.23.15.a': [
            testApproval(),
            ReviewRecord(
              action: ReviewAction.rejected,
              at: DateTime(2026, 11, 12),
              ruleVersion: 1,
              reviewer: 'Test Reviewer',
              rejectionReason: 'test',
            ),
          ],
        },
      );
      expect(r.isPersonalised, isFalse);
    });
  });

  group('Reviewer preview policy', () {
    test('Proverbs 23:18 renders the KJV-faithful candidate, marked as a preview', () async {
      final r = await renderShipped('PRO 23:18', policy: PublicationPolicy.reviewPreview);
      expect(r.outcome, RenderOutcome.personalised);
      expect(r.isPreview, isTrue);
      expect(r.ruleId, 'kjv-mwb.PRO.23.18.b');
      expect(r.text, 'For surely there is an end; and, Emmanuel Nkwoka, thine expectation shall not be cut off.');
      expect(r.originalText, await kjv('PRO 23:18'));
    });

    test('the rejected historical Proverbs 23:18 wording never renders', () async {
      final rejected = shippedRule('kjv-mwb.PRO.23.18.a');
      expect(rejected.effectiveStatus, RuleStatus.rejected);
      final v = await verse('PRO 23:18');
      for (final policy in PublicationPolicy.values) {
        final r = renderer(policy).render(
          source: v,
          sourceVersionId: 'KJV',
          targetVersionId: 'KJV-MWB',
          ruleset: rulesetOf([rejected]),
          name: PersonalNameResolver.resolve(emmanuel),
        );
        expect(r.outcome, RenderOutcome.ruleNotPublishable);
        expect(r.text, isNot(contains('future')));
      }
    });

    test('retired rules never render', () async {
      final r = await renderShipped(
        'PRO 3:1',
        policy: PublicationPolicy.reviewPreview,
        approvals: {
          'kjv-mwb.PRO.3.1.a': [ReviewRecord(action: ReviewAction.retired, at: DateTime(2026, 11, 11), ruleVersion: 1)],
        },
      );
      expect(r.isPersonalised, isFalse);
    });
  });

  group('Fail-safe rendering', () {
    test('a broken anchor returns the source', () async {
      final v = await verse('PRO 3:1');
      final rule = makeRule(
        id: 'broken',
        reference: 'PRO 3:1',
        sourceText: v.text,
        edits: [nameAfter('My daughter,')],
        reviews: [testApproval()],
      );
      final r = renderer().render(
        source: v,
        sourceVersionId: 'KJV',
        targetVersionId: 'KJV-MWB',
        ruleset: rulesetOf([rule]),
        name: PersonalNameResolver.resolve(emmanuel),
      );
      expect(r.outcome, RenderOutcome.validationFailed);
      expect(r.text, v.text);
    });

    test('a rule written against different source text returns the source', () async {
      final v = await verse('PRO 3:1');
      final rule = makeRule(
        id: 'drifted',
        reference: 'PRO 3:1',
        sourceText: 'My son, forget not my law;',
        edits: [nameAfter('My son,')],
        reviews: [testApproval()],
      );
      final r = renderer().render(
        source: v,
        sourceVersionId: 'KJV',
        targetVersionId: 'KJV-MWB',
        ruleset: rulesetOf([rule]),
        name: PersonalNameResolver.resolve(emmanuel),
      );
      expect(r.outcome, RenderOutcome.validationFailed);
      expect(r.text, v.text);
    });

    test('version mismatches return the source', () async {
      final v = await verse('PRO 23:15');
      final ruleset = rulesetOf([
        shippedRule('kjv-mwb.PRO.23.15.a', [testApproval()]),
      ]);
      final name = PersonalNameResolver.resolve(emmanuel);
      // KJV rules may not be applied to another edition, nor to another source.
      for (final (source, target) in [('KJV', 'NKJV-MWB'), ('NKJV', 'KJV-MWB'), ('KJV', 'KJV'), ('KJV', 'NOPE')]) {
        final r = renderer().render(
          source: v,
          sourceVersionId: source,
          targetVersionId: target,
          ruleset: ruleset,
          name: name,
        );
        expect(r.outcome, RenderOutcome.versionMismatch, reason: '$source -> $target');
        expect(r.text, v.text);
      }
    });

    test('a KJV-sourced rule inside another edition\'s ruleset is ignored', () async {
      final v = await verse('PRO 23:15');
      final foreign = makeRule(
        id: 'nkjv-rule',
        reference: 'PRO 23:15',
        sourceText: v.text,
        edits: [nameAfter('My son,')],
        sourceVersionId: 'NKJV',
        targetVersionId: 'NKJV-MWB',
        reviews: [testApproval()],
      );
      final r = renderer().render(
        source: v,
        sourceVersionId: 'KJV',
        targetVersionId: 'KJV-MWB',
        ruleset: rulesetOf([foreign]),
        name: PersonalNameResolver.resolve(emmanuel),
      );
      expect(r.outcome, RenderOutcome.noRule);
    });

    test('two different publishable rules for one verse are not guessed between', () async {
      final v = await verse('PRO 3:1');
      final a = makeRule(id: 'a', reference: 'PRO 3:1', sourceText: v.text, edits: [nameAfter('My son,')]);
      final b = makeRule(id: 'b', reference: 'PRO 3:1', sourceText: v.text, edits: [nameAfter('My son,')]);
      final r = renderer(PublicationPolicy.reviewPreview).render(
        source: v,
        sourceVersionId: 'KJV',
        targetVersionId: 'KJV-MWB',
        ruleset: rulesetOf([a, b]),
        name: PersonalNameResolver.resolve(emmanuel),
      );
      expect(r.outcome, RenderOutcome.ruleConflict);
      expect(r.text, v.text);
    });

    test('verses without rules and missing rulesets return the source', () async {
      final v = await verse('JHN 3:16');
      final name = PersonalNameResolver.resolve(emmanuel);
      for (final rs in [shippedRuleset(), null]) {
        final r = renderer().render(
          source: v,
          sourceVersionId: 'KJV',
          targetVersionId: 'KJV-MWB',
          ruleset: rs,
          name: name,
        );
        expect(r.outcome, RenderOutcome.noRule);
        expect(r.text, v.text);
      }
    });
  });

  group('Name preferences and missing profile data', () {
    final approved = {
      'kjv-mwb.PRO.23.15.a': [testApproval()],
    };
    Future<String> render(UserProfile? p) async =>
        (await renderShipped('PRO 23:15', profile: p, approvals: approved)).text;

    test('full name is the default', () async {
      expect(emmanuel.namePreference, NamePreference.fullName);
      expect(await render(emmanuel), startsWith('My son, Emmanuel Nkwoka, if'));
    });

    test('first name, preferred name and no name', () async {
      expect(
        await render(emmanuel.copyWith(namePreference: NamePreference.firstName)),
        startsWith('My son, Emmanuel, if'),
      );
      expect(
        await render(emmanuel.copyWith(namePreference: NamePreference.preferredName, preferredName: 'Emma')),
        startsWith('My son, Emma, if'),
      );
      final off = await renderShipped(
        'PRO 23:15',
        profile: emmanuel.copyWith(namePreference: NamePreference.none),
        approvals: approved,
      );
      expect(off.outcome, RenderOutcome.nameInsertionOff);
      expect(off.text, await kjv('PRO 23:15'));
    });

    test('missing data is never invented', () async {
      // No surname: the first name is used, nothing is made up.
      const noSurname = UserProfile(firstName: 'Grace', gender: GenderPreference.female);
      expect(PersonalNameResolver.resolve(noSurname).status, NameStatus.fellBackToFirstName);
      expect(await render(noSurname), startsWith('My son, Grace, if'));
      // No usable name at all: source text.
      for (final p in [null, const UserProfile(firstName: '  ', gender: GenderPreference.preferNotToSay)]) {
        final r = await renderShipped('PRO 23:15', profile: p, approvals: approved);
        expect(r.outcome, RenderOutcome.nameUnavailable);
        expect(r.text, await kjv('PRO 23:15'));
      }
    });

    test('names that could inject text into Scripture are refused', () async {
      for (final bad in ['Grace; and God said', 'x' * 61, '{name}', 'A<b>', '7even']) {
        final p = UserProfile(
          firstName: bad,
          gender: GenderPreference.female,
          namePreference: NamePreference.firstName,
        );
        expect(PersonalNameResolver.resolve(p).status, NameStatus.invalid, reason: bad);
        expect(await render(p), await kjv('PRO 23:15'));
      }
      const accented = UserProfile(firstName: 'Chiamaka', lastName: "O'Neil-Ọkafọ", gender: GenderPreference.female);
      expect(PersonalNameResolver.resolve(accented).name, "Chiamaka O'Neil-Ọkafọ");
    });

    test('gender never changes a rendering: "My son" is kept for every reader', () async {
      final outputs = {for (final g in GenderPreference.values) g: await render(emmanuel.copyWith(gender: g))};
      expect(outputs.values.toSet(), hasLength(1));
      final text = outputs.values.toSet().single;
      expect(text, contains('My son, Emmanuel Nkwoka,'));
      expect(text, isNot(contains('daughter')));
    });

    test('profiles saved before the new fields existed still load', () {
      final old = UserProfile.fromJson({'firstName': 'Grace', 'gender': 'female'});
      expect(old.lastName, '');
      expect(old.preferredName, '');
      expect(old.namePreference, NamePreference.fullName);
      final round = UserProfile.fromJson(emmanuel.copyWith(namePreference: NamePreference.firstName).toJson());
      expect(round.lastName, 'Nkwoka');
      expect(round.namePreference, NamePreference.firstName);
    });
  });

  group('Rendering service over a whole chapter', () {
    test('only approved verses change; every verse rebuilds its source; canonical text is untouched', () async {
      final store = InMemoryKeyValueStore();
      final reviews = reviewService(store: store);
      await reviews.reviews.append('kjv-mwb.PRO.23.15.a', testApproval());
      final service = MwbRenderingService(
        catalogue: catalogue,
        renderer: renderer(),
        reviewQueue: reviews,
        contexts: contextRepo(),
      );
      final before = (await sharedTestBible.chapter('KJV', 'PRO', 23)).map((v) => v.text).toList();
      final rendered = await service.renderVerses(
        targetVersionId: 'KJV-MWB',
        sourceVerses: await sharedTestBible.chapter('KJV', 'PRO', 23),
        profile: emmanuel,
      );
      expect(rendered.where((r) => r.isPersonalised).map((r) => r.source.number), [15]);
      for (var i = 0; i < rendered.length; i++) {
        expect(rendered[i].originalText, before[i]);
      }
      final after = (await sharedTestBible.chapter('KJV', 'PRO', 23)).map((v) => v.text).toList();
      expect(after, before);
      // Renderings are never persisted.
      expect(store.snapshot.values.join(), isNot(contains('Emmanuel')));
    });

    test('an edition without a ruleset renders every verse as the source', () async {
      final service = MwbRenderingService(
        catalogue: catalogue,
        renderer: renderer(),
        reviewQueue: reviewService(),
        contexts: contextRepo(),
      );
      final verses = await sharedTestBible.chapter('KJV', 'JHN', 3);
      final rendered = await service.renderVerses(targetVersionId: 'NIV-MWB', sourceVerses: verses, profile: emmanuel);
      expect(rendered.map((r) => r.text), verses.map((v) => v.text));
      expect(rendered.any((r) => r.isPersonalised), isFalse);
    });
  });
}
