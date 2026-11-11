import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../data/repositories/mwb_ruleset_repository.dart';
import '../../../data/repositories/passage_context_repository.dart';
import '../../../data/repositories/theological_review_repository.dart';
import '../domain/mwb_renderer.dart';
import '../domain/mwb_rendering_service.dart';
import '../domain/personalisation_validator.dart';
import '../domain/review_queue.dart';
import '../domain/ruleset_processor.dart';

/// Composition of the MWB personalisation engine. Every piece is a provider
/// so tests and a future API-backed implementation can replace it.

final mwbRulesetRepositoryProvider = Provider<MwbRulesetRepository>((ref) => AssetMwbRulesetRepository());

final passageContextRepositoryProvider = Provider<PassageContextRepository>((ref) => AssetPassageContextRepository());

final theologicalReviewRepositoryProvider = Provider<TheologicalReviewRepository>(
  (ref) => LocalTheologicalReviewRepository(ref.watch(keyValueStoreProvider)),
);

final personalisationValidatorProvider = Provider<PersonalisationValidator>(
  (ref) => PersonalisationValidator(ref.watch(versionCatalogueProvider)),
);

final mwbRendererProvider = Provider<MwbRenderer>(
  (ref) => MwbRenderer(
    catalogue: ref.watch(versionCatalogueProvider),
    validator: ref.watch(personalisationValidatorProvider),
    policy: ref.watch(appConfigProvider).mwbReviewMode
        ? PublicationPolicy.reviewPreview
        : PublicationPolicy.approvedOnly,
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
