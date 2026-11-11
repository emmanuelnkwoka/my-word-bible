import 'package:flutter/foundation.dart';

import '../../../data/models/mwb_rule.dart';
import '../../../data/models/passage_context.dart';

@immutable
class RiskAssessment {
  const RiskAssessment(this.level, this.reasons);
  final RiskLevel level;
  final List<String> reasons;
}

/// Derives the minimum risk a rule should carry from its passage context and
/// operations. A rule's declared risk can be higher, never effectively lower.
///
/// Representative address (e.g. "my son" in wisdom instruction) does not
/// raise risk by itself; specific relationships, collective audiences,
/// conditional promises and divine speech do.
abstract final class RiskAssessor {
  static RiskAssessment assess(MwbRule rule, PassageContext? context) {
    var level = RiskLevel.low;
    final reasons = <String>[];
    void raise(RiskLevel to, String reason) {
      level = level.max(to);
      reasons.add(reason);
    }

    if (context == null) {
      raise(RiskLevel.medium, 'No passage context recorded.');
    } else {
      if (context.speaker == SpeakerVoice.divine) raise(RiskLevel.critical, 'Direct divine speech.');
      switch (context.addressee) {
        case AddresseeType.collective:
          raise(RiskLevel.high, 'Collective audience: ${context.originalAudience}');
        case AddresseeType.specificIndividual:
          raise(RiskLevel.high, 'Addressed to a specific person: ${context.originalAudience}');
        case AddresseeType.god:
          raise(RiskLevel.high, 'The passage is addressed to God.');
        case AddresseeType.unspecified:
          raise(RiskLevel.medium, 'Addressee not recorded.');
        case AddresseeType.representative:
          break;
      }
      if (context.isConditionalPromise) {
        raise(RiskLevel.high, 'Conditional promise. ${context.conditionNote}'.trim());
      }
      for (final r in context.relationships.where((r) => r.kind == RelationshipKind.specific)) {
        raise(RiskLevel.high, 'Specific relationship: ${r.term}.');
      }
    }
    if (rule.edits.any((e) => e.operation == PersonalisationOperation.approvedMinimalGrammaticalAdjustment)) {
      raise(RiskLevel.medium, 'Changes source wording (minimal grammatical adjustment).');
    }
    return RiskAssessment(level, reasons);
  }
}
