import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/mwb_presentation_layer.dart';
import 'bible_repository.dart';

/// Offline source of the approved presentation layers for MWB editions.
abstract interface class MwbPresentationRepository {
  /// Layers for [edition] (e.g. "KJV-MWB"). Editions without a layer asset
  /// get an empty catalogue: every verse then reads as the original.
  Future<MwbPresentationCatalogue> catalogue(String edition, {required String sourceVersionId});
}

/// Reads `assets/mwb/presentation/<edition>.layers.json` (bundled; no network).
class AssetMwbPresentationRepository implements MwbPresentationRepository {
  AssetMwbPresentationRepository({AssetLoader? loader}) : _loader = loader ?? rootBundle.loadString;

  static const assets = {
    'KJV-MWB': 'assets/mwb/presentation/kjv-mwb.layers.json',
    'WEB-MWB': 'assets/mwb/presentation/web-mwb.layers.json',
  };

  final AssetLoader _loader;
  final _cache = <String, Future<MwbPresentationCatalogue>>{};

  @override
  Future<MwbPresentationCatalogue> catalogue(String edition, {required String sourceVersionId}) {
    final path = assets[edition];
    if (path == null) return Future.value(MwbPresentationCatalogue.empty(edition, sourceVersionId));
    return _cache.putIfAbsent(edition, () async {
      final json = jsonDecode(await _loader(path)) as Map<String, dynamic>;
      final c = MwbPresentationCatalogue.fromJson(json);
      // A layer file for another edition or source is never used.
      if (c.edition != edition || c.sourceVersionId != sourceVersionId) {
        return MwbPresentationCatalogue.empty(edition, sourceVersionId);
      }
      return c;
    });
  }
}
