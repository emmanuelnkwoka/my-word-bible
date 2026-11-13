import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/errors/app_failure.dart';
import '../../../data/models/bible.dart';
import '../../../data/models/mwb_rule.dart';
import '../../../data/models/scripture_reference.dart';
import '../../bible/application/bible_providers.dart';
import '../../profile/application/profile_controllers.dart';
import '../domain/personal_name.dart';
import '../domain/presentation_layer_resolver.dart';
import '../domain/rendered_verse.dart';
import '../domain/ruleset_processor.dart';
import 'personalisation_providers.dart';

// ── Reviewer mode ───────────────────────────────────────────────────────

/// Whether this build offers the editorial review tools (review centre,
/// reviewer preview). Only dedicated reviewer builds
/// (`--dart-define=MWB_REVIEW_MODE=true`) do. Ordinary builds, including
/// debug builds used for device testing, never show review workflow,
/// proposals or approval status to readers.
final reviewerToolsAvailableProvider = Provider<bool>((ref) => ref.watch(appConfigProvider).mwbReviewMode);

/// The reviewer's on/off switch, saved on the device. A reviewer build
/// starts with it on.
final mwbReviewerModeProvider = NotifierProvider<MwbReviewerModeController, bool>(MwbReviewerModeController.new);

class MwbReviewerModeController extends Notifier<bool> {
  @override
  bool build() {
    if (!ref.watch(reviewerToolsAvailableProvider)) return false;
    return ref.watch(keyValueStoreProvider).getBool(StorageKeys.mwbReviewerMode) ??
        ref.watch(appConfigProvider).mwbReviewMode;
  }

  Future<void> set(bool value) async {
    if (!ref.read(reviewerToolsAvailableProvider)) return;
    state = value;
    await ref.read(keyValueStoreProvider).setBool(StorageKeys.mwbReviewerMode, value);
  }
}

// ── Chapter view ────────────────────────────────────────────────────────

/// A personalisation rule shown to a reviewer next to its verse. It is never
/// displayed in place of the verse.
@immutable
class MwbProposal {
  const MwbProposal({required this.processed, required this.previewText, required this.usesPlaceholderName});

  final ProcessedRule processed;

  /// The proposed rendering (with the reader's name when available).
  final String? previewText;

  /// True when [previewText] shows `[Name]` because no usable name is set.
  final bool usesPlaceholderName;

  MwbRule get rule => processed.rule;
}

/// Everything the reader needs to show a chapter in an MWB edition.
@immutable
class MwbChapterView {
  const MwbChapterView({
    required this.edition,
    required this.source,
    required this.verses,
    required this.proposals,
    required this.reviewerMode,
    this.layers = const {},
  });

  final BibleVersionInfo edition;
  final BibleVersionInfo source;

  /// Approved-only renderings, one per canonical verse, in order.
  final List<RenderedVerse> verses;

  /// Reviewer mode only: proposals keyed by verse number.
  final Map<int, MwbProposal> proposals;
  final bool reviewerMode;

  /// Approved personal titles and receptions, keyed by verse number. The
  /// verse itself is never changed by them.
  final Map<int, VerseEditorialLayers> layers;

  int get personalisedCount => verses.where((v) => v.isPersonalised).length;
}

/// The MWB view of a chapter, or null when the active version is an
/// original translation (the reader then shows canonical verses directly).
final mwbChapterProvider = FutureProvider.family<MwbChapterView?, ScriptureReference>((ref, chapter) async {
  final edition = ref.watch(activeVersionProvider);
  if (!edition.isPersonalised) return null;
  final source = ref.watch(textVersionProvider);
  final verses = await ref.watch(chapterVersesProvider(chapter).future);
  final profile = ref.watch(userProfileProvider);
  final reviewerMode = ref.watch(mwbReviewerModeProvider);

  final rendered = await ref
      .watch(mwbRenderingServiceProvider)
      .renderVerses(targetVersionId: edition.id, sourceVerses: verses, profile: profile);

  final proposals = <int, MwbProposal>{};
  if (reviewerMode) {
    List<ProcessedRule> queue;
    try {
      queue = await ref.watch(reviewQueueProvider(edition.id).future);
    } on AppFailure {
      queue = const [];
    }
    MwbRuleset? ruleset;
    try {
      ruleset = await ref.watch(reviewQueueServiceProvider).effectiveRuleset(edition.id);
    } on AppFailure {
      ruleset = null;
    }
    final preview = ref.watch(mwbPreviewRendererProvider);
    final name = PersonalNameResolver.resolve(profile);
    for (final p in queue) {
      final r = p.rule.reference;
      if (r.bookId != chapter.bookId || r.chapter != chapter.chapter || r.verseStart == null) continue;
      if (p.status == RuleStatus.approved || p.status == RuleStatus.retired) continue;
      final n = r.verseStart!;
      if (n < 1 || n > verses.length) continue;
      String? text;
      if (ruleset != null && !p.status.isClosed) {
        final single = MwbRuleset(
          sourceVersionId: ruleset.sourceVersionId,
          targetVersionId: ruleset.targetVersionId,
          rulesetVersion: ruleset.rulesetVersion,
          style: ruleset.style,
          rules: [p.rule],
        );
        final out = preview.render(
          source: verses[n - 1],
          sourceVersionId: source.id,
          targetVersionId: edition.id,
          ruleset: single,
          name: name,
          context: p.context,
        );
        if (out.isPersonalised) text = out.text;
      }
      // Several rules can exist for one verse (e.g. a rejected one and its
      // replacement); show the open one.
      final existing = proposals[n];
      if (existing != null && !existing.processed.status.isClosed) continue;
      proposals[n] = MwbProposal(processed: p, previewText: text ?? p.previewText, usesPlaceholderName: text == null);
    }
  }
  return MwbChapterView(
    edition: edition,
    source: source,
    verses: rendered,
    proposals: proposals,
    reviewerMode: reviewerMode,
    layers: editorialLayersFor(
      await ref.watch(mwbPresentationCatalogueProvider(edition.id).future),
      ScriptureReference(bookId: chapter.bookId, chapter: chapter.chapter, verseStart: 1, verseEnd: verses.length),
      ref.watch(editorialNameProvider),
    ),
  );
});
