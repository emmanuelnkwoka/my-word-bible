import 'package:flutter/foundation.dart';

import 'content.dart';

/// Gender preference. Used only for greeting tone and future presentation
/// choices — it never alters canonical Scripture text.
enum GenderPreference {
  male('Male'),
  female('Female'),
  preferNotToSay('Prefer not to say');

  const GenderPreference(this.label);
  final String label;
}

/// Which name an MWB edition uses when it personally addresses the reader.
enum NamePreference {
  fullName('Full name'),
  firstName('First name'),
  preferredName('Preferred name'),

  /// No name insertion: MWB editions show the source wording.
  none('No name');

  const NamePreference(this.label);
  final String label;
}

@immutable
class UserProfile {
  const UserProfile({
    required this.firstName,
    required this.gender,
    this.lastName = '',
    this.preferredName = '',
    this.namePreference = NamePreference.fullName,
  });

  final String firstName;
  final GenderPreference gender;

  /// Optional. Empty when the user has not provided it (never invented).
  final String lastName;

  /// Optional name the user chose for personal address.
  final String preferredName;
  final NamePreference namePreference;

  UserProfile copyWith({
    String? firstName,
    GenderPreference? gender,
    String? lastName,
    String? preferredName,
    NamePreference? namePreference,
  }) => UserProfile(
    firstName: firstName ?? this.firstName,
    gender: gender ?? this.gender,
    lastName: lastName ?? this.lastName,
    preferredName: preferredName ?? this.preferredName,
    namePreference: namePreference ?? this.namePreference,
  );

  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'gender': gender.name,
    'lastName': lastName,
    'preferredName': preferredName,
    'namePreference': namePreference.name,
  };

  /// Profiles saved before these fields existed load with empty optional
  /// names and the default (full name) preference.
  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    firstName: j['firstName'] as String? ?? '',
    gender: GenderPreference.values.asNameMap()[j['gender']] ?? GenderPreference.preferNotToSay,
    lastName: j['lastName'] as String? ?? '',
    preferredName: j['preferredName'] as String? ?? '',
    namePreference: NamePreference.values.asNameMap()[j['namePreference']] ?? NamePreference.fullName,
  );
}

/// Reading text size steps.
enum ReadingTextSize {
  small('Small', 16),
  medium('Medium', 18),
  large('Large', 21),
  extraLarge('Extra large', 24);

  const ReadingTextSize(this.label, this.fontSize);
  final String label;
  final double fontSize;
}

/// Background treatment for the Scripture reader.
enum ReadingSurface {
  theme('Theme'),
  paper('Paper'),
  sepia('Sepia'),
  night('Night');

  const ReadingSurface(this.label);
  final String label;
}

/// Daily chapter goal options.
enum DailyReadingGoal {
  oneChapter('1 chapter a day', 1),
  twoChapters('2 chapters a day', 2),
  threeChapters('3 chapters a day', 3),
  fiveChapters('5 chapters a day', 5);

  const DailyReadingGoal(this.label, this.chapters);
  final String label;
  final int chapters;
}

@immutable
class ReadingPreferences {
  const ReadingPreferences({
    this.versionId = 'KJV',
    this.textSize = ReadingTextSize.medium,
    this.dailyGoal = DailyReadingGoal.oneChapter,
    this.surface = ReadingSurface.theme,
    this.showVerseNumbers = true,
    this.preferredContentTypes = const {ContentType.scriptureReference, ContentType.audio, ContentType.video},
  });

  final String versionId;
  final ReadingTextSize textSize;
  final DailyReadingGoal dailyGoal;
  final ReadingSurface surface;
  final bool showVerseNumbers;
  final Set<ContentType> preferredContentTypes;

  ReadingPreferences copyWith({
    String? versionId,
    ReadingTextSize? textSize,
    DailyReadingGoal? dailyGoal,
    ReadingSurface? surface,
    bool? showVerseNumbers,
    Set<ContentType>? preferredContentTypes,
  }) => ReadingPreferences(
    versionId: versionId ?? this.versionId,
    textSize: textSize ?? this.textSize,
    dailyGoal: dailyGoal ?? this.dailyGoal,
    surface: surface ?? this.surface,
    showVerseNumbers: showVerseNumbers ?? this.showVerseNumbers,
    preferredContentTypes: preferredContentTypes ?? this.preferredContentTypes,
  );

  Map<String, dynamic> toJson() => {
    'versionId': versionId,
    'textSize': textSize.name,
    'dailyGoal': dailyGoal.name,
    'surface': surface.name,
    'showVerseNumbers': showVerseNumbers,
    'contentTypes': preferredContentTypes.map((t) => t.name).toList(),
  };

  factory ReadingPreferences.fromJson(Map<String, dynamic> j) {
    const d = ReadingPreferences();
    final types = (j['contentTypes'] as List?)?.whereType<String>().map(ContentType.fromName).toSet();
    return ReadingPreferences(
      versionId: j['versionId'] as String? ?? d.versionId,
      textSize: ReadingTextSize.values.asNameMap()[j['textSize']] ?? d.textSize,
      dailyGoal: DailyReadingGoal.values.asNameMap()[j['dailyGoal']] ?? d.dailyGoal,
      surface: ReadingSurface.values.asNameMap()[j['surface']] ?? d.surface,
      showVerseNumbers: j['showVerseNumbers'] as bool? ?? true,
      preferredContentTypes: types == null || types.isEmpty ? d.preferredContentTypes : types,
    );
  }
}

/// Minutes of daily devotion the user is aiming for.
enum DevotionGoal {
  five('5 minutes', 5),
  ten('10 minutes', 10),
  fifteen('15 minutes', 15),
  thirty('30 minutes', 30);

  const DevotionGoal(this.label, this.minutes);
  final String label;
  final int minutes;
}

@immutable
class ReminderTime {
  const ReminderTime(this.hour, this.minute);
  final int hour;
  final int minute;

  Map<String, dynamic> toJson() => {'h': hour, 'm': minute};
  factory ReminderTime.fromJson(Map<String, dynamic> j) => ReminderTime(j['h'] as int? ?? 7, j['m'] as int? ?? 0);

  @override
  bool operator ==(Object other) => other is ReminderTime && other.hour == hour && other.minute == minute;
  @override
  int get hashCode => Object.hash(hour, minute);
}

@immutable
class DailyExperience {
  const DailyExperience({
    this.reminderEnabled = false,
    this.reminderTime = const ReminderTime(7, 0),
    this.devotionGoal = DevotionGoal.ten,
    this.personalisedDiscovery = true,
    this.includeAudioInDiscovery = true,
    this.includeVideoInDiscovery = true,
  });

  final bool reminderEnabled;
  final ReminderTime reminderTime;
  final DevotionGoal devotionGoal;
  final bool personalisedDiscovery;
  final bool includeAudioInDiscovery;
  final bool includeVideoInDiscovery;

  DailyExperience copyWith({
    bool? reminderEnabled,
    ReminderTime? reminderTime,
    DevotionGoal? devotionGoal,
    bool? personalisedDiscovery,
    bool? includeAudioInDiscovery,
    bool? includeVideoInDiscovery,
  }) => DailyExperience(
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderTime: reminderTime ?? this.reminderTime,
    devotionGoal: devotionGoal ?? this.devotionGoal,
    personalisedDiscovery: personalisedDiscovery ?? this.personalisedDiscovery,
    includeAudioInDiscovery: includeAudioInDiscovery ?? this.includeAudioInDiscovery,
    includeVideoInDiscovery: includeVideoInDiscovery ?? this.includeVideoInDiscovery,
  );

  Map<String, dynamic> toJson() => {
    'reminderEnabled': reminderEnabled,
    'reminderTime': reminderTime.toJson(),
    'devotionGoal': devotionGoal.name,
    'personalisedDiscovery': personalisedDiscovery,
    'includeAudio': includeAudioInDiscovery,
    'includeVideo': includeVideoInDiscovery,
  };

  factory DailyExperience.fromJson(Map<String, dynamic> j) => DailyExperience(
    reminderEnabled: j['reminderEnabled'] as bool? ?? false,
    reminderTime: j['reminderTime'] is Map<String, dynamic>
        ? ReminderTime.fromJson(j['reminderTime'] as Map<String, dynamic>)
        : const ReminderTime(7, 0),
    devotionGoal: DevotionGoal.values.asNameMap()[j['devotionGoal']] ?? DevotionGoal.ten,
    personalisedDiscovery: j['personalisedDiscovery'] as bool? ?? true,
    includeAudioInDiscovery: j['includeAudio'] as bool? ?? true,
    includeVideoInDiscovery: j['includeVideo'] as bool? ?? true,
  );
}

@immutable
class NotificationPreferences {
  const NotificationPreferences({
    this.newContentInInterests = false,
    this.creatorUpdates = false,
    this.readingGoalNudges = false,
  });

  final bool newContentInInterests;
  final bool creatorUpdates;
  final bool readingGoalNudges;

  NotificationPreferences copyWith({bool? newContentInInterests, bool? creatorUpdates, bool? readingGoalNudges}) =>
      NotificationPreferences(
        newContentInInterests: newContentInInterests ?? this.newContentInInterests,
        creatorUpdates: creatorUpdates ?? this.creatorUpdates,
        readingGoalNudges: readingGoalNudges ?? this.readingGoalNudges,
      );

  Map<String, dynamic> toJson() => {
    'newContent': newContentInInterests,
    'creatorUpdates': creatorUpdates,
    'goalNudges': readingGoalNudges,
  };

  factory NotificationPreferences.fromJson(Map<String, dynamic> j) => NotificationPreferences(
    newContentInInterests: j['newContent'] as bool? ?? false,
    creatorUpdates: j['creatorUpdates'] as bool? ?? false,
    readingGoalNudges: j['goalNudges'] as bool? ?? false,
  );
}
