import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../app/app_providers.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../data/models/daily_word.dart';
import '../../bible/application/bible_providers.dart';

/// Local engagement signals recorded by the app itself (searches). Stored on
/// this device only; never sent anywhere. Kept free of Daily Word screen
/// dependencies so the search feature can record without importing them.
final relevanceSignalsProvider = NotifierProvider<RelevanceSignalsController, List<RelevanceSignal>>(
  RelevanceSignalsController.new,
);

class RelevanceSignalsController extends Notifier<List<RelevanceSignal>> {
  static const retention = Duration(days: 90);
  static const maxSignals = 400;

  @override
  List<RelevanceSignal> build() {
    final j = ref.watch(keyValueStoreProvider).readJson(StorageKeys.dailyWordSignals);
    if (j is! List) return const [];
    return List.unmodifiable([
      for (final e in j)
        if (e is Map<String, dynamic>) ?RelevanceSignal.fromJson(e),
    ]);
  }

  Future<void> recordSearch(String query) async {
    final q = query.trim();
    if (q.length < 3) return;
    final now = ref.read(clockProvider)();
    final kept = [
      ...state.where((s) => now.difference(s.at) <= retention),
      RelevanceSignal(kind: SignalKind.search, value: q, at: now),
    ];
    state = List.unmodifiable(kept.length > maxSignals ? kept.sublist(kept.length - maxSignals) : kept);
    await ref.read(keyValueStoreProvider).writeJson(StorageKeys.dailyWordSignals, [for (final s in state) s.toJson()]);
  }

  Future<void> clear() async {
    state = const [];
    await ref.read(keyValueStoreProvider).remove(StorageKeys.dailyWordSignals);
  }
}
