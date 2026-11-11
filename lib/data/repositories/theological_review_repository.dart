import '../../core/storage/key_value_store.dart';
import '../models/mwb_rule.dart';

/// Review decisions recorded on this device, layered over the review history
/// shipped with each ruleset. A future implementation can sync decisions with
/// the MWB (Laravel) API so a reviewer's decisions reach every device.
///
/// This repository only stores records. Rules about who may approve what are
/// enforced by `ReviewQueueService` before anything is recorded.
abstract interface class TheologicalReviewRepository {
  /// Locally recorded review history for a rule, oldest first.
  List<ReviewRecord> decisionsFor(String ruleId);

  Map<String, List<ReviewRecord>> allDecisions();

  Future<void> append(String ruleId, ReviewRecord record);
}

class LocalTheologicalReviewRepository implements TheologicalReviewRepository {
  LocalTheologicalReviewRepository(this._store);

  final KeyValueStore _store;

  static const storageKey = 'mwb.v1.mwb_review_decisions';

  @override
  Map<String, List<ReviewRecord>> allDecisions() {
    final data = _store.readJson(storageKey);
    if (data is! Map<String, dynamic>) return const {};
    final out = <String, List<ReviewRecord>>{};
    data.forEach((ruleId, list) {
      if (list is! List) return;
      final records = <ReviewRecord>[];
      for (final item in list) {
        try {
          records.add(ReviewRecord.fromJson(item as Map<String, dynamic>));
        } catch (_) {
          // Skip a malformed record; never invent a status.
        }
      }
      out[ruleId] = records;
    });
    return out;
  }

  @override
  List<ReviewRecord> decisionsFor(String ruleId) => allDecisions()[ruleId] ?? const [];

  @override
  Future<void> append(String ruleId, ReviewRecord record) async {
    final all = {for (final e in allDecisions().entries) e.key: e.value.map((r) => r.toJson()).toList()};
    (all[ruleId] ??= []).add(record.toJson());
    await _store.writeJson(storageKey, all);
  }
}
