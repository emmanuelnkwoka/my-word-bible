import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../data/models/mwb_presentation_layer.dart';
import '../../../data/models/personalisation_catalogue.dart';
import '../../../data/models/scripture_reference.dart';
import '../../../data/repositories/mwb_presentation_repository.dart';
import '../../../data/repositories/mwb_ruleset_repository.dart';
import '../../../data/repositories/passage_context_repository.dart';
import '../../../data/repositories/theological_review_repository.dart';
import '../../bible/application/bible_providers.dart';
import '../../profile/application/profile_controllers.dart';
import '../domain/mwb_renderer.dart';
import '../domain/mwb_rendering_service.dart';
import '../domain/personal_name.dart';
import '../domain/personalisation_validator.dart';
import '../domain/presentation_layer_resolver.dart';
import '../domain/review_queue.dart';
import '../domain/ruleset_processor.dart';

/// Composition of the MWB personalisation engine. Every piece is a provider
/// so tests and a future API-backed implementation can replace it.

final personalisationCatalogueRepositoryProvider = Provider<PersonalisationCatalogueRepository>(
  (ref) => AssetPersonalisationCatalogueRepository(),
);

/// Hand-authored rules plus the generated catalogue proposals.
final mwbRulesetRepositoryProvider = Provider<MwbRulesetRepository>(
  (ref) => AssetMwbRulesetRepository(catalogue: ref.watch(personalisationCatalogueRepositoryProvider)),
);

/// The complete per-verse catalogue of an MWB edition.
final personalisationCatalogueProvider = FutureProvider.family<PersonalisationCatalogue, String>(
  (ref, edition) => ref.watch(personalisationCatalogueRepositoryProvider).catalogue(edition),
);

final passageContextRepositoryProvider = Provider<PassageContextRepository>((ref) => AssetPassageContextRepository());

final theologicalReviewRepositoryProvider = Provider<TheologicalReviewRepository>(
  (ref) => LocalTheologicalReviewRepository(ref.watch(keyValueStoreProvider)),
);

final personalisationValidatorProvider = Provider<PersonalisationValidator>(
  (ref) => PersonalisationValidator(ref.watch(versionCatalogueProvider)),
);

/// Renders MWB text shown as Scripture. Always approved-only, in every build:
/// a proposed rendering is never presented as an approved passage.
final mwbRendererProvider = Provider<MwbRenderer>(
  (ref) => MwbRenderer(
    catalogue: ref.watch(versionCatalogueProvider),
    validator: ref.watch(personalisationValidatorProvider),
  ),
);

/// Renders proposed (unapproved) rules for the reviewer preview only. Its
/// output is always shown labelled "PROPOSED — NOT APPROVED", beside the
/// original verse, never in place of it.
final mwbPreviewRendererProvider = Provider<MwbRenderer>(
  (ref) => MwbRenderer(
    catalogue: ref.watch(versionCatalogueProvider),
    validator: ref.watch(personalisationValidatorProvider),
    policy: PublicationPolicy.reviewPreview,
  ),
);

final reviewQueueServiceProvider = Provider<ReviewQueueService>(
  (ref) => ReviewQueueService(
    rulesets: ref.watch(mwbRulesetRepositoryProvider),
    bible: ref.watch(bibleRepositoryProvider),
    contexts: ref.watch(passageContextRepositoryProvider),
    reviews: ref.watch(theologicalReviewRepositoryProvider),
    processor: MwbRulesetProcessor(ref.watch(personalisationValidatorProvider)),
  ),
);

final mwbRenderingServiceProvider = Provider<MwbRenderingService>(
  (ref) => MwbRenderingService(
    catalogue: ref.watch(versionCatalogueProvider),
    renderer: ref.watch(mwbRendererProvider),
    reviewQueue: ref.watch(reviewQueueServiceProvider),
    contexts: ref.watch(passageContextRepositoryProvider),
  ),
);

/// The processed review queue for an MWB edition.
final reviewQueueProvider = FutureProvider.family<List<ProcessedRule>, String>(
  (ref, targetVersionId) => ref.watch(reviewQueueServiceProvider).queue(targetVersionId),
);

// ── Approved r3 presentation layers ─────────────────────────────────────
// One deterministic engine shared by the reader, Daily Word, Discover,
// Library, Search and Sharing.

final mwbPresentationRepositoryProvider = Provider<MwbPresentationRepository>(
  (ref) => AssetMwbPresentationRepository(),
);

/// The approved layers of an MWB edition (empty for editions without any).
final mwbPresentationCatalogueProvider = FutureProvider.family<MwbPresentationCatalogue, String>((ref, edition) {
  final source = ref.watch(versionCatalogueProvider).sourceOf(edition)?.id ?? edition;
  return ref.watch(mwbPresentationRepositoryProvider).catalogue(edition, sourceVersionId: source);
});

/// The reader's name for personal titles and receptions, from their profile
/// and name preference (full, first, preferred or none).
final editorialNameProvider = Provider<NameResolution>(
  (ref) => PersonalNameResolver.resolve(ref.watch(userProfileProvider)),
);

/// Editorial layers for the verses of [reference] in the active version,
/// keyed by verse number. Empty when reading an original translation
/// (KJV, WEB): there, Scripture is shown on its own.
final activeEditorialLayersProvider = FutureProvider.family<Map<int, VerseEditorialLayers>, ScriptureReference>((
  ref,
  reference,
) async {
  final active = ref.watch(activeVersionProvider);
  if (!active.isPersonalised || reference.verseStart == null) return const {};
  return editorialLayersFor(
    await ref.watch(mwbPresentationCatalogueProvider(active.id).future),
    reference,
    ref.watch(editorialNameProvider),
  );
});

/// Layers for each verse of a verse or range reference.
Map<int, VerseEditorialLayers> editorialLayersFor(
  MwbPresentationCatalogue catalogue,
  ScriptureReference reference,
  NameResolution name,
) {
  final start = reference.verseStart;
  if (start == null) return const {};
  final end = reference.verseEnd ?? start;
  return {
    for (var v = start; v <= end; v++)
      if (PresentationLayerResolver.resolve(catalogue, mwbVerseKey(reference.bookId, reference.chapter, v), name)
          case final l when l.isNotEmpty)
        v: l,
  };
}
