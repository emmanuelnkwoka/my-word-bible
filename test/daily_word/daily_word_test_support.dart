import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:my_word_bible/data/models/daily_word.dart';
import 'package:my_word_bible/data/repositories/intelligence_repository.dart';
import 'package:my_word_bible/features/daily_word/domain/adaptive_relevance_scorer.dart';
import 'package:my_word_bible/features/daily_word/domain/daily_word_engine.dart';
import 'package:my_word_bible/features/share/share_service.dart';

import '../intel/intel_test_support.dart';

DailyWordCatalogue shippedCatalogue() => decodeDailyWordCatalogue(
  jsonDecode(File('assets/daily/candidates.json').readAsStringSync()) as Map<String, dynamic>,
  jsonDecode(File('assets/daily/schedule.json').readAsStringSync()) as Map<String, dynamic>,
);

IntelligenceCorpus? _corpus;
IntelligenceCorpus corpus() => _corpus ??= shippedCorpus();

DailyWordEngine engine() {
  final c = shippedCatalogue();
  return DailyWordEngine(catalogue: c, facts: CandidateFacts.build(c, corpus()));
}

/// A delivered entry for [date] with [candidate], as the provider records it.
DailyWordHistoryEntry entryFor(DateTime date, DailyWordCandidate candidate, {bool favourite = false}) =>
    DailyWordHistoryEntry(
      dateKey: dateKeyOf(date),
      candidateId: candidate.id,
      reference: candidate.reference,
      versionId: 'KJV',
      category: candidate.category,
      heading: candidate.heading,
      summary: 'test',
      reasons: const [],
      adaptive: false,
      scheduleVersion: '2026.1',
      scheduledCandidateId: candidate.id,
      deliveredAt: date,
      favourite: favourite,
    );

/// Records shares instead of opening the Android share sheet.
class FakeShareService implements ShareService {
  final texts = <SharePayload>[];
  final images = <({Uint8List png, String fileName, SharePayload payload})>[];

  @override
  Future<ShareOutcome> shareText(SharePayload payload) async {
    texts.add(payload);
    return ShareOutcome.shared;
  }

  @override
  Future<ShareOutcome> shareImage(Uint8List png, {required String fileName, required SharePayload payload}) async {
    images.add((png: png, fileName: fileName, payload: payload));
    return ShareOutcome.shared;
  }

  @override
  Future<ShareOutcome> shareImages(
    List<Uint8List> pngs, {
    required List<String> fileNames,
    required SharePayload payload,
  }) async {
    for (var i = 0; i < pngs.length; i++) {
      images.add((png: pngs[i], fileName: fileNames[i], payload: payload));
    }
    return ShareOutcome.shared;
  }
}
