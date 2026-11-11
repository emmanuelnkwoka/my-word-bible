import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/errors/app_failure.dart';
import '../models/mwb_rule.dart';
import 'bible_repository.dart' show AssetLoader;

/// Personalisation rules for MWB editions. Local assets today; a future
/// implementation can fetch reviewed rules from the MWB (Laravel) API behind
/// the same interface.
abstract interface class MwbRulesetRepository {
  /// MWB edition ids that have a ruleset.
  Set<String> get editions;

  /// The ruleset for an MWB edition. Throws [FeatureUnavailableFailure] if
  /// the edition has none.
  Future<MwbRuleset> ruleset(String targetVersionId);
}

/// Parses a ruleset document. Malformed rules are skipped and reported in
/// [MwbRuleset.loadIssues] so one bad rule never blocks the others.
MwbRuleset parseMwbRuleset(String raw) {
  final j = jsonDecode(raw) as Map<String, dynamic>;
  final source = j['sourceVersionId'] as String;
  final target = j['targetVersionId'] as String;
  final rules = <MwbRule>[];
  final issues = <String>[];
  final list = (j['rules'] as List?) ?? const [];
  for (var i = 0; i < list.length; i++) {
    final item = list[i];
    try {
      rules.add(MwbRule.fromJson(item as Map<String, dynamic>, sourceVersionId: source, targetVersionId: target));
    } catch (e) {
      final id = item is Map ? item['id'] : null;
      issues.add('Rule ${id ?? '#$i'} could not be read: $e');
    }
  }
  final sup = j['theologicalSupervisor'] as Map<String, dynamic>?;
  return MwbRuleset(
    sourceVersionId: source,
    targetVersionId: target,
    rulesetVersion: j['rulesetVersion'] as int? ?? 1,
    style: VersionStyleProfile.fromJson(source, j['style'] as Map<String, dynamic>?),
    rules: rules,
    supervisor: sup == null ? null : TheologicalSupervisor(name: sup['name'] as String, role: sup['role'] as String),
    loadIssues: issues,
  );
}

class AssetMwbRulesetRepository implements MwbRulesetRepository {
  AssetMwbRulesetRepository({AssetLoader? loader}) : _loader = loader ?? rootBundle.loadString;

  final AssetLoader _loader;
  final Map<String, Future<MwbRuleset>> _cache = {};

  static const _assets = {'KJV-MWB': 'assets/mwb/rulesets/kjv-mwb.json'};

  @override
  Set<String> get editions => _assets.keys.toSet();

  @override
  Future<MwbRuleset> ruleset(String targetVersionId) {
    final asset = _assets[targetVersionId];
    if (asset == null) {
      return Future.error(FeatureUnavailableFailure('No personalisation rules exist for $targetVersionId.'));
    }
    return _cache.putIfAbsent(targetVersionId, () async {
      try {
        return parseMwbRuleset(await _loader(asset));
      } catch (_) {
        _cache.remove(targetVersionId);
        throw const UnknownFailure('The personalisation rules could not be opened.');
      }
    });
  }
}
