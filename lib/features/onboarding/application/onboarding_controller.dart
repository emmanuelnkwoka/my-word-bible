import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/content.dart';
import '../../../data/models/user_profile.dart';
import '../../profile/application/profile_controllers.dart';

/// Validation rules for onboarding, kept pure for testing.
abstract final class OnboardingValidation {
  static final _namePattern = RegExp(r"^[\p{L}][\p{L}\p{M}' \-]*$", unicode: true);

  static String? firstName(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Please enter your first name.';
    if (v.length < 2) return 'Your name should have at least 2 letters.';
    if (v.length > 30) return 'Please use 30 characters or fewer.';
    if (!_namePattern.hasMatch(v)) return 'Use letters only (hyphens and apostrophes are fine).';
    return null;
  }

  static String? gender(GenderPreference? value) => value == null ? 'Please choose an option.' : null;

  static String? interests(Set<String> value) => value.isEmpty ? 'Choose at least one interest, or skip.' : null;

  static String? contentTypes(Set<ContentType> value) => value.isEmpty ? 'Choose at least one type of content.' : null;
}

@immutable
class OnboardingDraft {
  const OnboardingDraft({
    this.step = 0,
    this.firstName = '',
    this.gender,
    this.interests = const {},
    this.reading = const ReadingPreferences(),
    this.daily = const DailyExperience(),
    this.showErrors = false,
  });

  static const stepCount = 4;

  final int step;
  final String firstName;
  final GenderPreference? gender;
  final Set<String> interests;
  final ReadingPreferences reading;
  final DailyExperience daily;

  /// Set after a failed "Continue" so errors appear only once relevant.
  final bool showErrors;

  bool get isLastStep => step == stepCount - 1;

  /// First error preventing the current step from continuing, if any.
  String? get currentStepError => switch (step) {
    0 => OnboardingValidation.firstName(firstName) ?? OnboardingValidation.gender(gender),
    1 => OnboardingValidation.interests(interests),
    2 => OnboardingValidation.contentTypes(reading.preferredContentTypes),
    _ => null,
  };

  OnboardingDraft copyWith({
    int? step,
    String? firstName,
    GenderPreference? gender,
    Set<String>? interests,
    ReadingPreferences? reading,
    DailyExperience? daily,
    bool? showErrors,
  }) => OnboardingDraft(
    step: step ?? this.step,
    firstName: firstName ?? this.firstName,
    gender: gender ?? this.gender,
    interests: interests ?? this.interests,
    reading: reading ?? this.reading,
    daily: daily ?? this.daily,
    showErrors: showErrors ?? this.showErrors,
  );
}

final onboardingControllerProvider = NotifierProvider.autoDispose<OnboardingController, OnboardingDraft>(
  OnboardingController.new,
);

class OnboardingController extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() {
    // Pre-fill from any existing profile (e.g. after a reset of onboarding).
    final profile = ref.read(userProfileProvider);
    return OnboardingDraft(
      firstName: profile?.firstName ?? '',
      gender: profile?.gender,
      interests: ref.read(interestsProvider),
      reading: ref.read(readingPreferencesProvider),
      daily: ref.read(dailyExperienceProvider),
    );
  }

  void setFirstName(String v) => state = state.copyWith(firstName: v);
  void setGender(GenderPreference g) => state = state.copyWith(gender: g);

  void toggleInterest(String id) {
    final next = {...state.interests};
    next.contains(id) ? next.remove(id) : next.add(id);
    state = state.copyWith(interests: next);
  }

  void updateReading(ReadingPreferences Function(ReadingPreferences) f) =>
      state = state.copyWith(reading: f(state.reading));

  void toggleContentType(ContentType t) {
    final next = {...state.reading.preferredContentTypes};
    next.contains(t) ? next.remove(t) : next.add(t);
    state = state.copyWith(reading: state.reading.copyWith(preferredContentTypes: next));
  }

  void updateDaily(DailyExperience Function(DailyExperience) f) => state = state.copyWith(daily: f(state.daily));

  /// Advances if the current step is valid. Returns false (and reveals
  /// errors) otherwise.
  bool next() {
    if (state.currentStepError != null) {
      state = state.copyWith(showErrors: true);
      return false;
    }
    if (!state.isLastStep) state = state.copyWith(step: state.step + 1, showErrors: false);
    return true;
  }

  void back() {
    if (state.step > 0) state = state.copyWith(step: state.step - 1, showErrors: false);
  }

  /// Skips an optional step (2–4), keeping sensible defaults.
  void skip() {
    switch (state.step) {
      case 1:
        state = state.copyWith(step: 2, interests: const {}, showErrors: false);
      case 2:
        state = state.copyWith(
          step: 3,
          reading: state.reading.copyWith(preferredContentTypes: const ReadingPreferences().preferredContentTypes),
          showErrors: false,
        );
      default:
        break;
    }
  }

  /// Persists everything and marks onboarding complete.
  Future<void> complete({bool skipDailyStep = false}) async {
    final s = state;
    if (OnboardingValidation.firstName(s.firstName) != null || s.gender == null) {
      state = s.copyWith(step: 0, showErrors: true);
      return;
    }
    final existing = ref.read(userProfileProvider);
    final name = s.firstName.trim();
    await ref
        .read(userProfileProvider.notifier)
        .save(existing?.copyWith(firstName: name, gender: s.gender) ?? UserProfile(firstName: name, gender: s.gender!));
    await ref.read(interestsProvider.notifier).save(s.interests);
    await ref.read(readingPreferencesProvider.notifier).save(s.reading);
    await ref
        .read(dailyExperienceProvider.notifier)
        .save(skipDailyStep ? s.daily.copyWith(reminderEnabled: false) : s.daily);
    await ref.read(onboardingCompleteProvider.notifier).set(true);
  }
}
