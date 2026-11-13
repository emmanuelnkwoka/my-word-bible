import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../data/models/bible.dart';
import '../../../data/models/scripture_reference.dart';
import '../../bible/application/bible_providers.dart';
import '../../profile/application/profile_controllers.dart';
import '../domain/personal_name.dart';
import '../domain/presentation_layer_resolver.dart';
import '../domain/rendered_verse.dart';
import 'mwb_reader_providers.dart';
import 'personalisation_providers.dart';

/// How a passage is presented to the reader.
enum ScriptureMode {
  /// Mode A: an approved rendering places the name inside the Scripture.
  nameInText,

  /// Mode B: the Scripture is unchanged; an approved title carries the name.
  nameInTitle,

  /// Mode C: the original Scripture, without forced personalisation.
  original,
}

/// The title shown when no personalised presentation applies (Mode C).
const dailyWordFallbackTitle = 'Daily Word – MWB';

/// A passage ready to display or share. The canonical verses are always
/// carried alongside, so the original stays recoverable.
@immutable
class ScripturePresentation {
  const ScripturePresentation({
    required this.reference,
    required this.mode,
    required this.verses,
    required this.source,
    required this.edition,
    required this.isPreview,
    this.title,
    this.titleName,
    this.editorialTitle,
    this.receptions = const [],
  });

  /// Mode B: the reader's name as it appears in [title] (for gold setting).
  final String? titleName;

  final ScriptureReference reference;
  final ScriptureMode mode;

  /// One rendering per canonical verse, in order.
  final List<RenderedVerse> verses;

  /// The source translation (e.g. KJV).
  final BibleVersionInfo source;

  /// The MWB edition used, when one applies.
  final BibleVersionInfo? edition;

  /// Rendered from proposals that are NOT approved (reviewer preview). Must
  /// be labelled wherever it is shown, and is never shared without a label.
  final bool isPreview;

  /// Mode A: the curated heading. Mode B: the personalised title. Mode C:
  /// whatever the caller supplies (Daily Word uses [dailyWordFallbackTitle]).
  final String? title;

  /// The approved personal title shown with this passage (r3 layer), when
  /// one of its verses has one. Editorial, never Scripture.
  final ResolvedEditorialLayer? editorialTitle;

  /// Approved personal receptions for the passage's verses, in verse order.
  final List<ResolvedEditorialLayer> receptions;

  bool get isPersonal => mode != ScriptureMode.original || receptions.isNotEmpty;

  /// Text as displayed (verses joined with a space).
  String get text => verses.where((v) => !v.source.isOmitted).map((v) => v.text).join(' ');

  /// The canonical text, character for character.
  String get originalText => verses.where((v) => !v.source.isOmitted).map((v) => v.source.text).join(' ');

  /// Translation label for references: "KJV" or "KJV-MWB" when the text
  /// itself is personalised.
  String get translationLabel =>
      mode == ScriptureMode.nameInText && edition != null ? edition!.abbreviation : source.abbreviation;
}

/// Inputs for [scripturePresentationProvider].
@immutable
class PresentationRequest {
  const PresentationRequest(this.reference, {this.heading, this.fallbackTitle});
  final ScriptureReference reference;

  /// Curated heading used as the Mode A title (editorial, not Scripture).
  final String? heading;

  /// Title for Mode C.
  final String? fallbackTitle;

  @override
  bool operator ==(Object other) =>
      other is PresentationRequest &&
      other.reference == reference &&
      other.heading == heading &&
      other.fallbackTitle == fallbackTitle;

  @override
  int get hashCode => Object.hash(reference, heading, fallbackTitle);
}

/// Presents a passage in the reader's translation using the same controlled
/// personalisation as the reader: approved rules only, or (in reviewer
/// builds with the review preview on) proposals, marked as previews.
///
/// Mode is decided from the rules, never from the text: an approved Mode A
/// rule wins, then an approved Mode B rule, otherwise the original.
final scripturePresentationProvider = FutureProvider.family<ScripturePresentation, PresentationRequest>((
  ref,
  request,
) async {
  final source = ref.watch(textVersionProvider);
  final catalogue = ref.watch(versionCatalogueProvider);
  final edition = catalogue.editionsOf(source.id).where(catalogue.isSelectable).firstOrNull;
  final passage = await ref.watch(bibleRepositoryProvider).passage(source.id, request.reference);
  final verses = passage.verses;
  final profile = ref.watch(userProfileProvider);
  final service = ref.watch(mwbRenderingServiceProvider);

  List<RenderedVerse> rendered = [
    for (final v in verses)
      RenderedVerse.original(
        v,
        sourceVersionId: source.id,
        targetVersionId: edition?.id ?? source.id,
        outcome: RenderOutcome.noRule,
      ),
  ];
  var preview = false;
  if (edition != null) {
    rendered = await service.renderVerses(targetVersionId: edition.id, sourceVerses: verses, profile: profile);
    final approvedAny = rendered.any((r) => r.isPersonalised || r.isTitled);
    if (!approvedAny && ref.watch(mwbReviewerModeProvider)) {
      final proposed = await service.renderVerses(
        targetVersionId: edition.id,
        sourceVerses: verses,
        profile: profile,
        rendererOverride: ref.watch(mwbPreviewRendererProvider),
      );
      if (proposed.any((r) => r.isPersonalised || r.isTitled)) {
        rendered = proposed;
        preview = true;
      }
    }
  }

  // Approved r3 layers for the passage's verses (titles and receptions,
  // each independent; name-in-text and unresolved layers never appear).
  final layers = edition == null
      ? const <int, VerseEditorialLayers>{}
      : editorialLayersFor(
          await ref.watch(mwbPresentationCatalogueProvider(edition.id).future),
          ScriptureReference(
            bookId: request.reference.bookId,
            chapter: request.reference.chapter,
            verseStart: verses.isEmpty ? 1 : verses.first.number,
            verseEnd: verses.isEmpty ? 1 : verses.last.number,
          ),
          ref.watch(editorialNameProvider),
        );
  final ordered = [for (final v in verses) ?layers[v.number]];
  final editorialTitle = ordered.map((l) => l.title).nonNulls.firstOrNull;
  final receptions = ordered.map((l) => l.reception).nonNulls.toList();

  final ScriptureMode mode;
  String? title;
  String? titleName;
  if (rendered.any((r) => r.isPersonalised)) {
    mode = ScriptureMode.nameInText;
    title = request.heading;
  } else if (editorialTitle != null) {
    // An approved personal title above the unchanged Scripture.
    mode = ScriptureMode.nameInTitle;
    title = editorialTitle.text;
    titleName = editorialTitle.name;
    rendered = [for (final r in rendered) _canonical(r)];
    preview = false;
  } else if (rendered.any((r) => r.isTitled)) {
    mode = ScriptureMode.nameInTitle;
    title = rendered.firstWhere((r) => r.isTitled).title;
    titleName = PersonalNameResolver.resolveTitle(profile).name;
    // A Mode B passage shows the canonical text everywhere.
    rendered = [for (final r in rendered) _canonical(r)];
  } else {
    mode = ScriptureMode.original;
    title = request.fallbackTitle;
  }
  return ScripturePresentation(
    reference: request.reference,
    mode: mode,
    verses: rendered,
    source: source,
    edition: edition,
    isPreview: preview && mode != ScriptureMode.original,
    title: title,
    titleName: titleName,
    editorialTitle: editorialTitle,
    receptions: receptions,
  );
});

/// [r] shown as its unchanged canonical text.
RenderedVerse _canonical(RenderedVerse r) => RenderedVerse(
  source: r.source,
  sourceVersionId: r.sourceVersionId,
  targetVersionId: r.targetVersionId,
  segments: [RenderSegment.source(r.source.text)],
  outcome: r.outcome,
  ruleId: r.ruleId,
  isPreview: r.isPreview,
  title: r.title,
);
