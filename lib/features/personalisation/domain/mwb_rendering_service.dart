import '../../../core/errors/app_failure.dart';
import '../../../data/catalogue/version_catalogue.dart';
import '../../../data/models/bible.dart';
import '../../../data/models/mwb_rule.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/passage_context_repository.dart';
import 'mwb_renderer.dart';
import 'personal_name.dart';
import 'rendered_verse.dart';
import 'review_queue.dart';

/// Renders canonical verses in an MWB edition for a reader.
///
/// Canonical verses come in unchanged from the Bible repository; this service
/// only layers renderings over them. Each verse is rendered independently, so
/// a problem with one verse never affects another.
class MwbRenderingService {
  MwbRenderingService({
    required this.catalogue,
    required this.renderer,
    required this.reviewQueue,
    required this.contexts,
  });

  final VersionCatalogue catalogue;
  final MwbRenderer renderer;
  final ReviewQueueService reviewQueue;
  final PassageContextRepository contexts;

  Future<List<RenderedVerse>> renderVerses({
    required String targetVersionId,
    required List<Verse> sourceVerses,
    required UserProfile? profile,
  }) async {
    final sourceId = catalogue.byId(targetVersionId)?.sourceVersionId ?? '';
    MwbRuleset? ruleset;
    try {
      ruleset = await reviewQueue.effectiveRuleset(targetVersionId);
    } on AppFailure {
      ruleset = null; // No rules: every verse shows the source.
    }
    final name = PersonalNameResolver.resolve(profile);
    final out = <RenderedVerse>[];
    for (final verse in sourceVerses) {
      try {
        final hasRule = ruleset != null && ruleset.rulesForVerse(verse.reference).isNotEmpty;
        out.add(
          renderer.render(
            source: verse,
            sourceVersionId: sourceId,
            targetVersionId: targetVersionId,
            ruleset: ruleset,
            name: name,
            context: hasRule ? await contexts.contextFor(verse.reference) : null,
          ),
        );
      } catch (_) {
        out.add(
          RenderedVerse.original(
            verse,
            sourceVersionId: sourceId,
            targetVersionId: targetVersionId,
            outcome: RenderOutcome.renderError,
          ),
        );
      }
    }
    return out;
  }
}
