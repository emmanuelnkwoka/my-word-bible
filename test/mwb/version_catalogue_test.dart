import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/core/constants/storage_keys.dart';
import 'package:my_word_bible/core/storage/key_value_store.dart';
import 'package:my_word_bible/core/theme/app_theme.dart';
import 'package:my_word_bible/core/theme/mwb_themes.dart';
import 'package:my_word_bible/data/catalogue/version_catalogue.dart';
import 'package:my_word_bible/data/models/bible.dart';
import 'package:my_word_bible/features/bible/application/bible_providers.dart';
import 'package:my_word_bible/features/bible/widgets/version_picker.dart';

import '../helpers/test_app.dart';

void main() {
  final catalogue = VersionCatalogue(bibleVersionCatalogue);

  group('Version catalogue', () {
    test('is internally consistent', () {
      expect(catalogue.integrityIssues(), isEmpty);
    });

    test('has the planned original + MWB families, grouped by source', () {
      final families = {for (final f in catalogue.families) f.original.id: f.editions.map((e) => e.id).toList()};
      expect(families['KJV'], ['KJV-MWB']);
      expect(families['NKJV'], ['NKJV-MWB']);
      expect(families['NIV'], ['NIV-MWB']);
      expect(families['NLT'], ['NLT-MWB']);
      for (final edition in catalogue.versions.where((v) => v.isPersonalised)) {
        expect(catalogue.sourceOf(edition.id)!.isPersonalised, isFalse, reason: edition.id);
        expect(edition.id, '${edition.sourceVersionId}-MWB');
        expect(edition.reviewPolicy, ReviewPolicy.approvedRulesOnly);
      }
    });

    test('every entry records licensing details', () {
      for (final v in catalogue.versions) {
        final l = v.licence;
        expect(l, isNotNull, reason: v.id);
        expect(l!.copyrightHolder, isNotEmpty, reason: v.id);
        expect(l.attribution, isNotEmpty, reason: v.id);
        expect(l.quotationRestrictions, isNotEmpty, reason: v.id);
      }
    });

    test('only KJV is selectable today', () {
      expect(catalogue.versions.where(catalogue.isSelectable).map((v) => v.id), ['KJV']);
    });

    test('restricted translations and their MWB editions stay disabled without permission', () {
      for (final id in ['NKJV', 'NIV', 'NLT']) {
        final original = catalogue.byId(id)!;
        final edition = catalogue.byId('$id-MWB')!;
        expect(original.licence!.permitsDistribution, isFalse);
        expect(edition.licence!.derivativeWorks.allows, isFalse);
        expect(edition.personalisation, PersonalisationAvailability.blockedByLicence);
        expect(catalogue.isSelectable(original), isFalse);
        expect(catalogue.isSelectable(edition), isFalse);
      }
    });

    test('an MWB edition cannot be selected even if marked installed when its source forbids derivatives', () {
      final forged = VersionCatalogue([
        const BibleVersionInfo(
          id: 'X',
          abbreviation: 'X',
          name: 'X',
          status: BibleVersionStatus.installed,
          note: '',
          licence: VersionLicence(
            copyrightHolder: 'Publisher',
            type: LicenceType.publisherLicence,
            status: LicensingStatus.obtained,
            offlineStorage: PermissionState.granted,
            distribution: PermissionState.granted,
            derivativeWorks: PermissionState.notGranted,
            attribution: 'a',
            quotationRestrictions: 'q',
          ),
        ),
        const BibleVersionInfo(
          id: 'X-MWB',
          abbreviation: 'X-MWB',
          name: 'X MWB',
          status: BibleVersionStatus.installed,
          note: '',
          kind: BibleVersionKind.personalised,
          sourceVersionId: 'X',
          personalisation: PersonalisationAvailability.available,
          reviewPolicy: ReviewPolicy.approvedRulesOnly,
          licence: VersionLicence(
            copyrightHolder: 'Publisher',
            type: LicenceType.derivedEdition,
            status: LicensingStatus.obtained,
            offlineStorage: PermissionState.granted,
            distribution: PermissionState.granted,
            derivativeWorks: PermissionState.granted,
            attribution: 'a',
            quotationRestrictions: 'q',
          ),
        ),
      ]);
      expect(forged.isSelectable(forged.byId('X')!), isTrue);
      expect(forged.isSelectable(forged.byId('X-MWB')!), isFalse);
    });

    test('KJV-MWB derives from KJV and is not yet available for reading', () {
      final mwb = catalogue.byId('KJV-MWB')!;
      expect(mwb.sourceVersionId, 'KJV');
      expect(mwb.status, BibleVersionStatus.inDevelopment);
      expect(mwb.licence!.derivativeWorks.allows, isTrue);
      expect(catalogue.isSelectable(mwb), isFalse);
    });
  });

  group('Saved reading preferences', () {
    test('a saved KJV preference is preserved', () {
      final store = onboardedStore()..writeJson(StorageKeys.readingPreferences, {'versionId': 'KJV'});
      expect(testContainer(store).read(activeVersionProvider).id, 'KJV');
    });

    test('an unavailable or unknown saved version falls back to KJV without crashing', () {
      for (final id in ['KJV-MWB', 'NIV', 'ESV', 'nonsense']) {
        final store = onboardedStore()..writeJson(StorageKeys.readingPreferences, {'versionId': id});
        expect(testContainer(store).read(activeVersionProvider).id, 'KJV', reason: id);
      }
    });
  });

  group('Shared version picker', () {
    Future<String?> pumpPicker(WidgetTester tester, Brightness brightness) async {
      String? picked;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppThemeBuilder.build(MwbThemeId.classicGold, brightness),
            home: Scaffold(
              body: SingleChildScrollView(
                child: BibleVersionPicker(catalogue: catalogue, selectedId: 'KJV', onSelected: (v) => picked = v.id),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return picked;
    }

    for (final brightness in Brightness.values) {
      testWidgets('lists each family with its MWB edition and the corrected notice (${brightness.name})', (
        tester,
      ) async {
        await pumpPicker(tester, brightness);
        for (final id in ['KJV', 'KJV-MWB', 'NKJV', 'NKJV-MWB', 'NIV', 'NIV-MWB', 'NLT', 'NLT-MWB']) {
          expect(find.byKey(ValueKey('version-$id')), findsOneWidget, reason: id);
        }
        // Each edition sits directly below its source.
        final kjvY = tester.getTopLeft(find.byKey(const ValueKey('version-KJV'))).dy;
        final kjvMwbY = tester.getTopLeft(find.byKey(const ValueKey('version-KJV-MWB'))).dy;
        final nkjvY = tester.getTopLeft(find.byKey(const ValueKey('version-NKJV'))).dy;
        expect(kjvY < kjvMwbY && kjvMwbY < nkjvY, isTrue);
        expect(find.text(mwbVersionExplanation), findsOneWidget);
        expect(find.textContaining('never alters the wording'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('only selectable versions respond to taps', (tester) async {
      String? picked;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemeBuilder.build(MwbThemeId.classicGold, Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(
              child: BibleVersionPicker(catalogue: catalogue, selectedId: 'KJV', onSelected: (v) => picked = v.id),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('version-KJV-MWB')));
      await tester.tap(find.byKey(const ValueKey('version-NIV')));
      expect(picked, isNull);
      await tester.tap(find.byKey(const ValueKey('version-KJV')));
      expect(picked, 'KJV');
    });
  });
}
