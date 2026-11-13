import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../data/mock/mock_daily.dart';
import '../../../data/models/bible.dart';
import '../../../data/models/scripture_reference.dart';
import '../../profile/application/profile_controllers.dart';

/// The version used for reading. Falls back to the first selectable version
/// if the stored preference refers to one that is not available (not
/// installed, not licensed, or an MWB edition still in development).
final activeVersionProvider = Provider<BibleVersionInfo>((ref) {
  final catalogue = ref.watch(versionCatalogueProvider);
  final preferred = ref.watch(readingPreferencesProvider.select((p) => p.versionId));
  final selectable = catalogue.versions.where(catalogue.isSelectable).toList();
  return selectable.firstWhere((v) => v.id == preferred, orElse: () => selectable.first);
});

/// The original translation whose canonical text is read for the active
/// version. For an MWB edition (e.g. KJV-MWB) this is its source (KJV): MWB
/// editions never have stored text of their own. Use this to label text that
/// is shown unrendered (cards, search results, copied verses).
final textVersionProvider = Provider<BibleVersionInfo>((ref) {
  final active = ref.watch(activeVersionProvider);
  return ref.watch(versionCatalogueProvider).sourceOf(active.id) ?? active;
});

final bibleBooksProvider = FutureProvider<List<BibleBookInfo>>((ref) {
  final version = ref.watch(textVersionProvider);
  return ref.watch(bibleRepositoryProvider).books(version.id);
});

/// Verses for a chapter reference (verse numbers on the key are ignored).
final chapterVersesProvider = FutureProvider.family<List<Verse>, ScriptureReference>((ref, chapter) {
  final version = ref.watch(textVersionProvider);
  return ref.watch(bibleRepositoryProvider).chapter(version.id, chapter.bookId, chapter.chapter);
});

final passageProvider = FutureProvider.family<Passage, ScriptureReference>((ref, reference) {
  final version = ref.watch(textVersionProvider);
  return ref.watch(bibleRepositoryProvider).passage(version.id, reference);
});

/// Today's date, overridable in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final dailyScriptureProvider = FutureProvider<Passage>((ref) {
  final now = ref.watch(clockProvider)();
  final reference = dailyScriptureRefs[dayIndex(now, dailyScriptureRefs.length)];
  return ref.watch(passageProvider(reference).future);
});

final dailyPromiseProvider = FutureProvider<(DailyPromise, Passage)>((ref) async {
  final now = ref.watch(clockProvider)();
  final promise = dailyPromises[dayIndex(now, dailyPromises.length)];
  final passage = await ref.watch(passageProvider(promise.reference).future);
  return (promise, passage);
});
