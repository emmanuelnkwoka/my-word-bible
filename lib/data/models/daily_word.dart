import 'package:flutter/foundation.dart';

import 'intelligence.dart' show EditorialStatus, IntelFormatException, ProvenanceOrigin;
import 'scripture_reference.dart';

/// Daily Spoken Word: candidates, the annual schedule, and what was delivered.
///
/// Candidates point at Scripture by canonical reference only; verse text is
/// always read from the installed translation.

/// Calendar date without time, as `yyyy-mm-dd`.
String dateKeyOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime dateFromKey(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

/// `mm-dd` used by the annual schedule.
String monthDayOf(DateTime d) => '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

@immutable
class DailyWordCandidate {
  const DailyWordCandidate({
    required this.id,
    required this.reference,
    required this.contextId,
    required this.category,
    required this.theme,
    required this.rationale,
    required this.origin,
    required this.reviewStatus,
    this.title,
    this.leapReserved = false,
    this.seedId,
    this.reviewFlags = const [],
  });

  final String id;
  final ScriptureReference reference;

  /// The Stage C context record for this passage.
  final String contextId;
  final String category;
  final String theme;

  /// Short heading; null when no curated title exists.
  final String? title;

  /// Why the passage is in the pool (editorial, factual).
  final String rationale;
  final bool leapReserved;
  final ProvenanceOrigin origin;
  final String? seedId;
  final EditorialStatus reviewStatus;
  final List<String> reviewFlags;

  String get heading => title ?? theme;
}

@immutable
class ScheduleDay {
  const ScheduleDay({required this.day, required this.monthDay, required this.candidateId, required this.occurrence});
  final int day;
  final String monthDay;
  final String candidateId;

  /// 1 for the first use of this passage in the year, 2 for its first reuse…
  final int occurrence;
}

/// The bundled annual schedule and candidate pool.
@immutable
class DailyWordCatalogue {
  DailyWordCatalogue({
    required this.scheduleVersion,
    required this.corpusVersion,
    required this.cycleLength,
    required this.categories,
    required this.candidates,
    required this.days,
    required this.leapCandidateId,
  }) : _byId = {for (final c in candidates) c.id: c},
       _byMonthDay = {for (final d in days) d.monthDay: d};

  static const supportedSchema = 1;
  static const leapMonthDay = '02-29';

  final String scheduleVersion;
  final String corpusVersion;
  final int cycleLength;
  final List<String> categories;
  final List<DailyWordCandidate> candidates;
  final List<ScheduleDay> days;
  final String leapCandidateId;
  final Map<String, DailyWordCandidate> _byId;
  final Map<String, ScheduleDay> _byMonthDay;

  DailyWordCandidate? candidate(String id) => _byId[id];

  /// Candidates available for adaptive selection (the leap passage is
  /// reserved for February 29).
  Iterable<DailyWordCandidate> get pool => candidates.where((c) => !c.leapReserved);

  /// The scheduled candidate for a calendar date. February 29 always maps to
  /// the reserved leap candidate; every other date maps by month and day, so
  /// a leap year never shifts or repeats the 28 Feb / 1 Mar assignments.
  DailyWordCandidate scheduledFor(DateTime date) {
    final md = monthDayOf(date);
    final id = md == leapMonthDay ? leapCandidateId : _byMonthDay[md]!.candidateId;
    return _byId[id]!;
  }

  ScheduleDay? scheduleDay(DateTime date) => _byMonthDay[monthDayOf(date)];
}

/// Why a Daily Word was chosen. Plain, factual phrases only.
@immutable
class SelectionReason {
  const SelectionReason(this.code, this.text, [this.points = 0]);
  final String code;
  final String text;
  final int points;

  Map<String, dynamic> toJson() => {'code': code, 'text': text, if (points != 0) 'points': points};
  factory SelectionReason.fromJson(Map<String, dynamic> j) =>
      SelectionReason(j['code'] as String? ?? '', j['text'] as String? ?? '', j['points'] as int? ?? 0);
}

/// A delivered Daily Word. Written once per calendar date and never
/// recomputed, so later schedules or signals cannot change it.
@immutable
class DailyWordHistoryEntry {
  const DailyWordHistoryEntry({
    required this.dateKey,
    required this.candidateId,
    required this.reference,
    required this.versionId,
    required this.category,
    required this.heading,
    required this.summary,
    required this.reasons,
    required this.adaptive,
    required this.scheduleVersion,
    required this.scheduledCandidateId,
    required this.deliveredAt,
    this.favourite = false,
    this.openedAt,
  });

  final String dateKey;
  final String candidateId;
  final ScriptureReference reference;

  /// Translation active when the word was delivered.
  final String versionId;
  final String category;
  final String heading;

  /// One-sentence explanation shown to the reader.
  final String summary;
  final List<SelectionReason> reasons;

  /// True when local signals chose a different passage from the schedule.
  final bool adaptive;
  final String scheduleVersion;
  final String scheduledCandidateId;
  final DateTime deliveredAt;
  final bool favourite;
  final DateTime? openedAt;

  DateTime get date => dateFromKey(dateKey);

  DailyWordHistoryEntry copyWith({bool? favourite, DateTime? openedAt}) => DailyWordHistoryEntry(
    dateKey: dateKey,
    candidateId: candidateId,
    reference: reference,
    versionId: versionId,
    category: category,
    heading: heading,
    summary: summary,
    reasons: reasons,
    adaptive: adaptive,
    scheduleVersion: scheduleVersion,
    scheduledCandidateId: scheduledCandidateId,
    deliveredAt: deliveredAt,
    favourite: favourite ?? this.favourite,
    openedAt: openedAt ?? this.openedAt,
  );

  Map<String, dynamic> toJson() => {
    'date': dateKey,
    'cid': candidateId,
    'ref': reference.toJson(),
    'v': versionId,
    'cat': category,
    'h': heading,
    'sum': summary,
    'why': [for (final r in reasons) r.toJson()],
    'ad': adaptive,
    'sv': scheduleVersion,
    'sch': scheduledCandidateId,
    'at': deliveredAt.toIso8601String(),
    if (favourite) 'fav': true,
    if (openedAt != null) 'open': openedAt!.toIso8601String(),
  };

  factory DailyWordHistoryEntry.fromJson(Map<String, dynamic> j) => DailyWordHistoryEntry(
    dateKey: j['date'] as String,
    candidateId: j['cid'] as String,
    reference: ScriptureReference.fromJson(j['ref'] as Map<String, dynamic>),
    versionId: j['v'] as String? ?? 'KJV',
    category: j['cat'] as String? ?? '',
    heading: j['h'] as String? ?? '',
    summary: j['sum'] as String? ?? '',
    reasons: [
      for (final r in (j['why'] as List? ?? const [])) SelectionReason.fromJson((r as Map).cast<String, dynamic>()),
    ],
    adaptive: j['ad'] as bool? ?? false,
    scheduleVersion: j['sv'] as String? ?? '',
    scheduledCandidateId: j['sch'] as String? ?? j['cid'] as String,
    deliveredAt: DateTime.tryParse('${j['at']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
    favourite: j['fav'] as bool? ?? false,
    openedAt: j['open'] == null ? null : DateTime.tryParse('${j['open']}'),
  );
}

@immutable
class DailyWordSettings {
  const DailyWordSettings({this.adaptiveEnabled = true, this.signalsClearedAt});

  /// When false, the annual schedule is used unchanged.
  final bool adaptiveEnabled;

  /// Signals recorded before this moment are ignored.
  final DateTime? signalsClearedAt;

  DailyWordSettings copyWith({bool? adaptiveEnabled, DateTime? signalsClearedAt}) => DailyWordSettings(
    adaptiveEnabled: adaptiveEnabled ?? this.adaptiveEnabled,
    signalsClearedAt: signalsClearedAt ?? this.signalsClearedAt,
  );

  Map<String, dynamic> toJson() => {
    'adaptive': adaptiveEnabled,
    if (signalsClearedAt != null) 'cleared': signalsClearedAt!.toIso8601String(),
  };

  factory DailyWordSettings.fromJson(Map<String, dynamic> j) => DailyWordSettings(
    adaptiveEnabled: j['adaptive'] as bool? ?? true,
    signalsClearedAt: j['cleared'] == null ? null : DateTime.tryParse('${j['cleared']}'),
  );
}

/// Signals the app records itself. Reading, saves, highlights and notes are
/// read from the library, which already timestamps them.
enum SignalKind { search }

/// One local engagement signal. Never leaves the device.
@immutable
class RelevanceSignal {
  const RelevanceSignal({required this.kind, required this.value, required this.at});
  final SignalKind kind;

  /// A search query, or a canonical reference key.
  final String value;
  final DateTime at;

  Map<String, dynamic> toJson() => {'k': kind.name, 'v': value, 'at': at.toIso8601String()};
  static RelevanceSignal? fromJson(Map<String, dynamic> j) {
    final kind = SignalKind.values.asNameMap()[j['k']];
    final at = DateTime.tryParse('${j['at']}');
    if (kind == null || at == null || j['v'] is! String) return null;
    return RelevanceSignal(kind: kind, value: j['v'] as String, at: at);
  }
}

// ── Asset decoding ──────────────────────────────────────────────────────

/// Decodes `assets/daily/candidates.json` and `schedule.json`.
DailyWordCatalogue decodeDailyWordCatalogue(Map<String, dynamic> candidatesJson, Map<String, dynamic> scheduleJson) {
  T need<T>(Map<String, dynamic> m, String key, String where) {
    final v = m[key];
    if (v is! T) throw IntelFormatException('$where: "$key" is missing or has the wrong type');
    return v;
  }

  for (final (j, f) in [(candidatesJson, 'candidates.json'), (scheduleJson, 'schedule.json')]) {
    if (j['schemaVersion'] != DailyWordCatalogue.supportedSchema) {
      throw IntelFormatException('$f: schema ${j['schemaVersion']} is not supported');
    }
  }
  final version = need<String>(scheduleJson, 'scheduleVersion', 'schedule.json');
  if (candidatesJson['scheduleVersion'] != version) {
    throw const IntelFormatException('candidates.json and schedule.json have different schedule versions');
  }
  final candidates = [
    for (final raw in need<List>(candidatesJson, 'candidates', 'candidates.json'))
      () {
        final c = (raw as Map).cast<String, dynamic>();
        final where = 'candidates.json › ${c['id']}';
        final prov = need<Map>(c, 'provenance', where).cast<String, dynamic>();
        final review = need<Map>(c, 'review', where).cast<String, dynamic>();
        final ref = need<String>(c, 'reference', where);
        final ScriptureReference parsed;
        try {
          parsed = ScriptureReference.parseCompact(ref);
        } on FormatException {
          throw IntelFormatException('$where: "$ref" is not a canonical reference');
        }
        return DailyWordCandidate(
          id: need<String>(c, 'id', where),
          reference: parsed,
          contextId: need<String>(c, 'contextId', where),
          category: need<String>(c, 'category', where),
          theme: need<String>(c, 'theme', where),
          title: c['title'] as String?,
          rationale: need<String>(c, 'rationale', where),
          leapReserved: c['leapReserved'] as bool? ?? false,
          origin: ProvenanceOrigin.values.byName(need<String>(prov, 'origin', where)),
          seedId: prov['seedId'] as String?,
          reviewStatus: EditorialStatus.values.byName(need<String>(review, 'status', where)),
          reviewFlags: [for (final f in (review['flags'] as List? ?? const [])) '$f'],
        );
      }(),
  ];
  final days = [
    for (final raw in need<List>(scheduleJson, 'days', 'schedule.json'))
      () {
        final d = (raw as Map).cast<String, dynamic>();
        return ScheduleDay(
          day: need<int>(d, 'day', 'schedule.json'),
          monthDay: need<String>(d, 'date', 'schedule.json'),
          candidateId: need<String>(d, 'candidateId', 'schedule.json'),
          occurrence: need<int>(d, 'occurrence', 'schedule.json'),
        );
      }(),
  ];
  final leap = need<Map>(scheduleJson, 'leapDay', 'schedule.json').cast<String, dynamic>();
  return DailyWordCatalogue(
    scheduleVersion: version,
    corpusVersion: need<String>(scheduleJson, 'corpusVersion', 'schedule.json'),
    cycleLength: need<int>(scheduleJson, 'cycleLength', 'schedule.json'),
    categories: [for (final c in need<List>(candidatesJson, 'categories', 'candidates.json')) '$c'],
    candidates: List.unmodifiable(candidates),
    days: List.unmodifiable(days),
    leapCandidateId: need<String>(leap, 'candidateId', 'schedule.json'),
  );
}
