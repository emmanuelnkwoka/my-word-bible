import 'package:flutter/foundation.dart';

import '../../../data/models/mwb_rule.dart';
import 'rendered_verse.dart';

/// An edit located at exact character offsets in the source verse.
@immutable
class LocatedEdit {
  const LocatedEdit(this.edit, this.start, this.end);
  final RuleEdit edit;

  /// For insertions `start == end` (the insertion point).
  final int start;
  final int end;

  bool get isInsertion => start == end && edit.position != EditPosition.replace;
}

/// Why an edit could not be located.
enum LocateError { emptyAnchor, notFound, ambiguous, overlapping }

@immutable
class LocateResult {
  const LocateResult(this.edits, this.errors);
  final List<LocatedEdit> edits;
  final Map<LocateError, String> errors;
  bool get ok => errors.isEmpty;
}

/// Pure functions that locate and apply rule edits. Shared by the validator
/// and the renderer so both see exactly the same transformation.
abstract final class EditEngine {
  static List<int> _occurrences(String text, String anchor) {
    final out = <int>[];
    var i = text.indexOf(anchor);
    while (i >= 0) {
      out.add(i);
      i = text.indexOf(anchor, i + 1);
    }
    return out;
  }

  static LocateResult locate(List<RuleEdit> edits, String source) {
    final located = <LocatedEdit>[];
    final errors = <LocateError, String>{};
    for (final e in edits) {
      if (e.anchor.isEmpty) {
        errors[LocateError.emptyAnchor] = 'An edit has an empty anchor.';
        continue;
      }
      final hits = _occurrences(source, e.anchor);
      if (hits.isEmpty) {
        errors[LocateError.notFound] = 'Anchor "${e.anchor}" is not in the source verse.';
        continue;
      }
      if (e.occurrence == null && hits.length > 1) {
        errors[LocateError.ambiguous] =
            'Anchor "${e.anchor}" occurs ${hits.length} times; the rule must say which occurrence.';
        continue;
      }
      final n = e.occurrence ?? 1;
      if (n < 1 || n > hits.length) {
        errors[LocateError.notFound] = 'Occurrence $n of anchor "${e.anchor}" does not exist.';
        continue;
      }
      final at = hits[n - 1];
      located.add(switch (e.position) {
        EditPosition.before => LocatedEdit(e, at, at),
        EditPosition.after => LocatedEdit(e, at + e.anchor.length, at + e.anchor.length),
        EditPosition.replace => LocatedEdit(e, at, at + e.anchor.length),
      });
    }
    located.sort((a, b) => a.start != b.start ? a.start.compareTo(b.start) : a.end.compareTo(b.end));
    for (var i = 1; i < located.length; i++) {
      final prev = located[i - 1];
      final cur = located[i];
      final sameInsertionPoint = prev.isInsertion && cur.isInsertion && prev.start == cur.start;
      if (sameInsertionPoint || cur.start < prev.end) {
        errors[LocateError.overlapping] = 'Two edits overlap or share an insertion point.';
      }
    }
    return LocateResult(located, errors);
  }

  /// Builds source-linked segments. [name] replaces [namePlaceholder].
  static List<RenderSegment> apply(String source, List<LocatedEdit> edits, String name, {required String ruleId}) {
    final segments = <RenderSegment>[];
    var cursor = 0;
    for (final e in edits) {
      if (e.start > cursor) segments.add(RenderSegment.source(source.substring(cursor, e.start)));
      final text = e.edit.text.replaceAll(namePlaceholder, name);
      if (e.isInsertion) {
        segments.add(RenderSegment.personalisation(text, ruleId: ruleId));
      } else {
        segments.add(RenderSegment.adjustment(text, original: source.substring(e.start, e.end), ruleId: ruleId));
      }
      cursor = e.end > cursor ? e.end : cursor;
    }
    if (cursor < source.length) segments.add(RenderSegment.source(source.substring(cursor)));
    return segments;
  }
}
