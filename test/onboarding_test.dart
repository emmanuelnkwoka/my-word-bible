import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/core/constants/storage_keys.dart';
import 'package:my_word_bible/core/storage/key_value_store.dart';
import 'package:my_word_bible/data/models/content.dart';
import 'package:my_word_bible/data/models/user_profile.dart';
import 'package:my_word_bible/features/onboarding/application/onboarding_controller.dart';
import 'package:my_word_bible/features/profile/application/profile_controllers.dart';

import 'helpers/test_app.dart';

void main() {
  group('Onboarding validation', () {
    test('first name rules', () {
      expect(OnboardingValidation.firstName(''), isNotNull);
      expect(OnboardingValidation.firstName('   '), isNotNull);
      expect(OnboardingValidation.firstName('A'), isNotNull);
      expect(OnboardingValidation.firstName('Grace1'), isNotNull);
      expect(OnboardingValidation.firstName('x' * 31), isNotNull);
      expect(OnboardingValidation.firstName('Grace'), isNull);
      expect(OnboardingValidation.firstName("O'Neil"), isNull);
      expect(OnboardingValidation.firstName('Anne-Marie'), isNull);
      expect(OnboardingValidation.firstName('Chukwuemeka'), isNull);
      expect(OnboardingValidation.firstName('Zoë'), isNull);
    });

    test('gender, interests and content types are required', () {
      expect(OnboardingValidation.gender(null), isNotNull);
      expect(OnboardingValidation.gender(GenderPreference.preferNotToSay), isNull);
      expect(OnboardingValidation.interests({}), isNotNull);
      expect(OnboardingValidation.interests({'faith'}), isNull);
      expect(OnboardingValidation.contentTypes({}), isNotNull);
      expect(OnboardingValidation.contentTypes({ContentType.audio}), isNull);
    });
  });

  group('Onboarding controller', () {
    test('cannot continue from step 1 without a valid name and gender', () {
      final c = testContainer(InMemoryKeyValueStore());
      final ctrl = c.read(onboardingControllerProvider.notifier);
      final sub = c.listen(onboardingControllerProvider, (_, _) {});
      addTearDown(sub.close);

      expect(ctrl.next(), isFalse);
      expect(c.read(onboardingControllerProvider).showErrors, isTrue);
      expect(c.read(onboardingControllerProvider).step, 0);

      ctrl.setFirstName('Grace');
      expect(ctrl.next(), isFalse, reason: 'gender still missing');

      ctrl.setGender(GenderPreference.female);
      expect(ctrl.next(), isTrue);
      expect(c.read(onboardingControllerProvider).step, 1);
    });

    test('step 2 requires an interest but can be skipped; back works', () {
      final c = testContainer(InMemoryKeyValueStore());
      final sub = c.listen(onboardingControllerProvider, (_, _) {});
      addTearDown(sub.close);
      final ctrl = c.read(onboardingControllerProvider.notifier)
        ..setFirstName('Grace')
        ..setGender(GenderPreference.female)
        ..next();

      expect(ctrl.next(), isFalse);
      ctrl.skip();
      expect(c.read(onboardingControllerProvider).step, 2);
      ctrl.back();
      expect(c.read(onboardingControllerProvider).step, 1);
      ctrl.toggleInterest('prayer');
      expect(ctrl.next(), isTrue);

      // Step 3: deselecting all content types blocks progress.
      for (final t in [...c.read(onboardingControllerProvider).reading.preferredContentTypes]) {
        ctrl.toggleContentType(t);
      }
      expect(ctrl.next(), isFalse);
      ctrl.toggleContentType(ContentType.video);
      expect(ctrl.next(), isTrue);
      expect(c.read(onboardingControllerProvider).isLastStep, isTrue);
    });

    test('completion persists every answer and survives a restart', () async {
      final store = InMemoryKeyValueStore();
      final c = testContainer(store);
      final sub = c.listen(onboardingControllerProvider, (_, _) {});
      addTearDown(sub.close);
      final ctrl = c.read(onboardingControllerProvider.notifier)
        ..setFirstName('  Grace ')
        ..setGender(GenderPreference.preferNotToSay)
        ..next()
        ..toggleInterest('faith')
        ..toggleInterest('wisdom')
        ..next()
        ..updateReading((r) => r.copyWith(textSize: ReadingTextSize.large, dailyGoal: DailyReadingGoal.threeChapters))
        ..next()
        ..updateDaily((d) => d.copyWith(reminderEnabled: true, reminderTime: const ReminderTime(6, 45)));
      await ctrl.complete();

      expect(c.read(onboardingCompleteProvider), isTrue);
      expect(store.getBool(StorageKeys.onboardingComplete), isTrue);

      final restarted = testContainer(store);
      expect(restarted.read(onboardingCompleteProvider), isTrue);
      expect(restarted.read(userProfileProvider)!.firstName, 'Grace');
      expect(restarted.read(userProfileProvider)!.gender, GenderPreference.preferNotToSay);
      expect(restarted.read(interestsProvider), {'faith', 'wisdom'});
      expect(restarted.read(readingPreferencesProvider).textSize, ReadingTextSize.large);
      expect(restarted.read(readingPreferencesProvider).dailyGoal, DailyReadingGoal.threeChapters);
      expect(restarted.read(dailyExperienceProvider).reminderEnabled, isTrue);
      expect(restarted.read(dailyExperienceProvider).reminderTime, const ReminderTime(6, 45));
    });

    test('reset onboarding clears profile but keeps appearance', () async {
      final store = onboardedStore();
      await store.setString(StorageKeys.themeId, 'forest_green');
      final c = testContainer(store);
      await c.read(profileActionsProvider).resetOnboarding();
      expect(c.read(onboardingCompleteProvider), isFalse);
      expect(c.read(userProfileProvider), isNull);
      expect(store.getString(StorageKeys.themeId), 'forest_green');
    });
  });

  group('Onboarding UI', () {
    testWidgets('full four-step flow validates, completes and lands on Home', (tester) async {
      final store = InMemoryKeyValueStore();
      await pumpMwbApp(tester, store);

      expect(find.text('Let’s start with you'), findsOneWidget);
      expect(find.text('STEP 1 OF 4'), findsOneWidget);

      // Validation: continue with nothing entered.
      await tester.tapText('Continue');
      expect(find.text('Please enter your first name.'), findsOneWidget);
      expect(find.text('Please choose an option.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('onboarding.firstName')), 'Grace');
      await tester.tapText('Female');
      await tester.tapText('Continue');
      expect(find.text('STEP 2 OF 4'), findsOneWidget);

      await tester.tap(find.byKey(const Key('interest.faith')));
      await settle(tester);
      await tester.tapText('Continue');
      expect(find.text('STEP 3 OF 4'), findsOneWidget);
      expect(find.text('How do you like to read?'), findsOneWidget);
      // Sample translations that are not installed are clearly labelled.
      expect(find.textContaining('Requires a publisher licence'), findsWidgets);

      await tester.tapText('Continue');
      expect(find.text('STEP 4 OF 4'), findsOneWidget);
      await tester.tapText('Begin my journey');

      expect(store.getBool(StorageKeys.onboardingComplete), isTrue);
      expect(find.textContaining('Grace'), findsWidgets);
      expect(find.text('DAILY SCRIPTURE'), findsOneWidget);
    });

    testWidgets('onboarding is not shown again once completed', (tester) async {
      await pumpMwbApp(tester, onboardedStore());
      expect(find.text('Let’s start with you'), findsNothing);
      expect(find.text('DAILY SCRIPTURE'), findsOneWidget);
    });
  });
}
