import 'package:flutter/foundation.dart';

import '../../../data/models/mwb_presentation_layer.dart';
import 'personal_name.dart';

/// An approved editorial layer, ready to display: the wording exactly as
/// approved, with the reader's name resolved. Never Scripture.
@immutable
class ResolvedEditorialLayer {
  const ResolvedEditorialLayer({required this.layerId, required this.type, required this.text, this.name});

  final String layerId;
  final MwbLayerType type;

  /// Display text.
  final String text;

  /// The name as it appears in [text] (for gold setting); null when the
  /// reader chose no name or none is available.
  final String? name;

  @override
  bool operator ==(Object other) =>
      other is ResolvedEditorialLayer && other.layerId == layerId && other.text == text && other.name == name;

  @override
  int get hashCode => Object.hash(layerId, text, name);
}

/// The editorial layers shown with one canonical verse. Title and reception
/// are independent: either, both or neither may be present.
@immutable
class VerseEditorialLayers {
  const VerseEditorialLayers({this.title, this.reception});

  static const none = VerseEditorialLayers();

  /// Shown above the unchanged verse.
  final ResolvedEditorialLayer? title;

  /// Shown below the unchanged verse.
  final ResolvedEditorialLayer? reception;

  bool get isEmpty => title == null && reception == null;
  bool get isNotEmpty => !isEmpty;
}

/// Deterministic presentation of r3 layers: exact `(edition, verse_key)`
/// lookup, the publication policy applied per layer, and the reader's name
/// placed into the approved template. Nothing is generated or paraphrased.
abstract final class PresentationLayerResolver {
  /// Every approved template begins with exactly one name placeholder
  /// followed by ", " (verified when the asset is built).
  static final _leading = RegExp(r'^(\{name\}|\[Name\]), ');
  static final _anyPlaceholder = RegExp(r'\{name\}|\[Name\]');

  /// The layers to show for a verse in [catalogue].
  static VerseEditorialLayers resolve(MwbPresentationCatalogue catalogue, String verseKey, NameResolution name) {
    if (catalogue.nonRenderable.contains(verseKey)) return VerseEditorialLayers.none;
    return VerseEditorialLayers(
      title: _layer(catalogue.layerOf(verseKey, MwbLayerType.personalTitle), name),
      reception: _layer(catalogue.layerOf(verseKey, MwbLayerType.personalReception), name),
    );
  }

  static ResolvedEditorialLayer? _layer(MwbPresentationLayer? layer, NameResolution name) {
    if (layer == null || !layer.isDisplayable) return null;
    final text = fill(layer.content!, name);
    if (text == null) return null;
    return ResolvedEditorialLayer(
      layerId: layer.id,
      type: layer.type,
      text: text,
      name: name.canInsert ? name.name : null,
    );
  }

  /// Places [name] into an approved template. With no name (the reader chose
  /// "No name", or none is set) the template's leading address is removed
  /// and the sentence begins with a capital, the template's nameless form.
  /// Returns null when the template cannot be resolved safely (then the
  /// layer is simply omitted and the verse still shows).
  static String? fill(String template, NameResolution name) {
    final m = _leading.firstMatch(template);
    if (m == null) return null;
    final rest = template.substring(m.end);
    if (rest.isEmpty || _anyPlaceholder.hasMatch(rest)) return null;
    if (name.canInsert) return '${name.name}, $rest';
    return rest[0].toUpperCase() + rest.substring(1);
  }
}
