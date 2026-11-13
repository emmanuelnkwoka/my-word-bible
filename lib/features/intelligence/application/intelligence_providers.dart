import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../data/models/intelligence.dart';
import '../../../data/models/scripture_reference.dart';
import '../../../data/repositories/intelligence_repository.dart';

/// The loaded intelligence corpus. Loaded once, on first use.
final intelligenceCorpusProvider = FutureProvider<IntelligenceCorpus>(
  (ref) => ref.watch(intelligenceRepositoryProvider).corpus(),
);

/// Everything the corpus knows about one passage: its context, related
/// Scripture and the records that cite it. Integration point for the Daily
/// Word, Search, Pray, Discover and Poster stages; no screen uses it yet.
@immutable
class PassageIntelligence {
  const PassageIntelligence({
    required this.reference,
    this.context,
    this.relationships = const [],
    this.citedBy = const [],
  });
  final ScriptureReference reference;
  final IntelContext? context;
  final List<RelationshipView> relationships;
  final List<IntelRecord> citedBy;

  bool get isEmpty => context == null && relationships.isEmpty && citedBy.isEmpty;
}

final passageIntelligenceProvider = FutureProvider.family<PassageIntelligence, ScriptureReference>((
  ref,
  reference,
) async {
  final corpus = await ref.watch(intelligenceCorpusProvider.future);
  return PassageIntelligence(
    reference: reference,
    context: corpus.contextsFor(reference).firstOrNull,
    relationships: corpus.relationshipsFor(reference),
    citedBy: corpus.recordsCiting(reference),
  );
});
