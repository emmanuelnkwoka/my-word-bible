import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/passage_context.dart';
import '../models/scripture_reference.dart';
import 'bible_repository.dart' show AssetLoader;

/// Human-authored context for passages (author, audience, speaker...).
abstract interface class PassageContextRepository {
  /// The most specific recorded context covering [verse], or null.
  Future<PassageContext?> contextFor(ScriptureReference verse);
}

List<PassageContext> parsePassageContexts(String raw) {
  final j = jsonDecode(raw) as Map<String, dynamic>;
  final out = <PassageContext>[];
  for (final item in (j['contexts'] as List? ?? const [])) {
    try {
      out.add(PassageContext.fromJson(item as Map<String, dynamic>));
    } catch (_) {
      // Skip a malformed entry rather than lose all context.
    }
  }
  return out;
}

class AssetPassageContextRepository implements PassageContextRepository {
  AssetPassageContextRepository({AssetLoader? loader}) : _loader = loader ?? rootBundle.loadString;

  final AssetLoader _loader;
  Future<List<PassageContext>>? _contexts;

  static const asset = 'assets/mwb/passage_context.json';

  Future<List<PassageContext>> _load() => _contexts ??= _loader(asset).then(parsePassageContexts).catchError((_) {
    _contexts = null;
    return <PassageContext>[];
  });

  @override
  Future<PassageContext?> contextFor(ScriptureReference verse) async {
    final matches = (await _load()).where((c) => c.covers(verse)).toList()..sort((a, b) => a.span.compareTo(b.span));
    return matches.isEmpty ? null : matches.first;
  }
}
