import 'package:flutter/foundation.dart';

/// Approved r3 presentation layers (package `2026.11-revised-r3`), generated
/// from the immutable editorial package by
/// `tool/build_r3_presentation_layers.js`.
///
/// The canonical verse is never part of a layer: it always comes from the
/// installed Bible. A layer is editorial content shown beside it.

/// `verse_key = BOOK_ID.chapter.verse` (e.g. `PSA.30.5`, `3JN.1.2`). This is
/// the only identity used to find layers: never a display string such as
/// "Psalm"/"Psalms", never fuzzy matching.
String mwbVerseKey(String bookId, int chapter, int verse) => '$bookId.$chapter.$verse';

enum MwbLayerType {
  /// A title carrying the reader's name above the unchanged verse.
  personalTitle,

  /// A separate editorial reception beside the unchanged verse.
  personalReception,

  /// The name inside the verse text (an altered rendering).
  directPersonalisation,
}

/// Per-layer production visibility (MWB_PUBLICATION_POLICY.md).
enum PublicationDisposition {
  alwaysCanonical('always_canonical'),
  editorialEligible('editorial_eligible'),
  requiresHumanRatification('requires_human_ratification'),
  unresolvedWithhold('unresolved_withhold'),

  /// Any value the app does not recognise: never displayed.
  unknown('unknown');

  const PublicationDisposition(this.code);
  final String code;

  static PublicationDisposition parse(String? code) =>
      values.firstWhere((d) => d.code == code, orElse: () => PublicationDisposition.unknown);
}

@immutable
class MwbPresentationLayer {
  const MwbPresentationLayer({
    required this.id,
    required this.verseKey,
    required this.type,
    required this.disposition,
    required this.content,
    required this.proposalId,
  });

  factory MwbPresentationLayer.fromJson(Map<String, dynamic> j) => MwbPresentationLayer(
    id: j['id'] as String,
    verseKey: j['key'] as String,
    type: MwbLayerType.values.asNameMap()[j['type']] ?? MwbLayerType.directPersonalisation,
    disposition: PublicationDisposition.parse(j['disposition'] as String?),
    content: j['content'] as String?,
    proposalId: j['proposal'] as String? ?? '',
  );

  /// `<edition>:<verse_key>:<title|reception|direct>`.
  final String id;
  final String verseKey;
  final MwbLayerType type;
  final PublicationDisposition disposition;

  /// Approved wording with a single leading name placeholder; null for a
  /// withheld layer (its wording is not shipped).
  final String? content;
  final String proposalId;

  /// May this layer appear in the app? Only editorial titles and receptions
  /// marked `editorial_eligible`. A name inside the verse is never shown
  /// without human ratification, and unresolved layers never appear.
  bool get isDisplayable =>
      disposition == PublicationDisposition.editorialEligible &&
      type != MwbLayerType.directPersonalisation &&
      content != null &&
      content!.isNotEmpty;
}

/// All layers of one MWB edition, indexed by verse key.
@immutable
class MwbPresentationCatalogue {
  MwbPresentationCatalogue({
    required this.edition,
    required this.sourceVersionId,
    required this.package,
    required this.nonRenderable,
    required List<MwbPresentationLayer> layers,
  }) : _byKey = _index(layers),
       layerCount = layers.length;

  factory MwbPresentationCatalogue.fromJson(Map<String, dynamic> j) => MwbPresentationCatalogue(
    edition: j['edition'] as String,
    sourceVersionId: j['sourceVersionId'] as String,
    package: j['package'] as String,
    nonRenderable: {...(j['nonRenderable'] as List? ?? const []).whereType<String>()},
    layers: [
      for (final l in (j['layers'] as List? ?? const []))
        if (l is Map<String, dynamic>) MwbPresentationLayer.fromJson(l),
    ],
  );

  /// An edition with no layers (every verse reads as the original).
  factory MwbPresentationCatalogue.empty(String edition, String sourceVersionId) => MwbPresentationCatalogue(
    edition: edition,
    sourceVersionId: sourceVersionId,
    package: '',
    nonRenderable: const {},
    layers: const [],
  );

  static Map<String, List<MwbPresentationLayer>> _index(List<MwbPresentationLayer> layers) {
    final m = <String, List<MwbPresentationLayer>>{};
    for (final l in layers) {
      (m[l.verseKey] ??= []).add(l);
    }
    return m;
  }

  final String edition;
  final String sourceVersionId;
  final String package;

  /// Verse keys with no text in the source translation (e.g. WEB Luke
  /// 17:36). They carry no layer and are never rendered as verses.
  final Set<String> nonRenderable;
  final int layerCount;
  final Map<String, List<MwbPresentationLayer>> _byKey;

  /// Every layer recorded for a verse (displayable or not).
  List<MwbPresentationLayer> layersFor(String verseKey) => _byKey[verseKey] ?? const [];

  /// The single layer of [type] for a verse, or null. Exact key lookup only.
  MwbPresentationLayer? layerOf(String verseKey, MwbLayerType type) {
    final matches = layersFor(verseKey).where((l) => l.type == type).toList();
    return matches.length == 1 ? matches.single : null;
  }

  Iterable<MwbPresentationLayer> get allLayers => _byKey.values.expand((l) => l);
}
