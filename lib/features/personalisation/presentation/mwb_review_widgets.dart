import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/selection.dart';
import '../../../core/widgets/sheets.dart';
import '../../../data/models/mwb_rule.dart';
import '../application/mwb_reader_providers.dart';

/// Label used on every unapproved rendering. Never shortened or softened.
const proposedLabel = 'PROPOSED — NOT APPROVED';
const rejectedLabel = 'REJECTED — NOT USED';

String _statusLabel(RuleStatus s) => s == RuleStatus.rejected ? rejectedLabel : proposedLabel;

/// Explains what the reader is looking at in an MWB edition.
class MwbEditionBanner extends StatelessWidget {
  const MwbEditionBanner({super.key, required this.view, required this.textColor});

  final MwbChapterView view;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final count = view.personalisedCount;
    final src = view.source.abbreviation;
    final layered = view.layers.length;
    final lines = <String>[
      if (count > 0)
        '$count personal ${count == 1 ? 'passage is' : 'passages are'} shown in gold. '
            'Every other verse reads exactly as the $src.'
      else
        'Every verse reads exactly as the $src.',
      if (layered > 0)
        layered == 1
            ? 'One verse in this chapter has a personal title or reception for you.'
            : '$layered verses in this chapter have a personal title or reception for you.',
      if (view.reviewerMode)
        view.proposals.isEmpty
            ? 'Reviewer mode: no proposed personalisations in this chapter.'
            : 'Reviewer mode: ${view.proposals.length} proposed '
                  '${view.proposals.length == 1 ? 'personalisation is' : 'personalisations are'} shown under '
                  '${view.proposals.length == 1 ? 'its verse' : 'their verses'}, marked "$proposedLabel".',
    ];
    return Container(
      key: const ValueKey('mwb-edition-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(MwbSpace.md),
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.08),
        borderRadius: MwbRadius.mdAll,
        border: Border.all(color: c.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${view.edition.abbreviation} · personalised edition of the $src',
            style: t.label.copyWith(fontWeight: FontWeight.w600, color: textColor),
          ),
          for (final l in lines) ...[
            const SizedBox(height: 4),
            Text(l, style: t.caption.copyWith(color: textColor.withValues(alpha: 0.8))),
          ],
        ],
      ),
    );
  }
}

/// A reviewer-only card under a verse showing a proposed rendering.
class MwbProposalCard extends StatelessWidget {
  const MwbProposalCard({super.key, required this.proposal, required this.view});

  final MwbProposal proposal;
  final MwbChapterView view;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final p = proposal.processed;
    final rejected = p.status == RuleStatus.rejected;
    final accent = rejected ? c.error : c.warning;
    return Semantics(
      button: true,
      label: '${_statusLabel(p.status)}. ${proposal.previewText ?? ''}. Open review details',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('proposal-${p.rule.id}'),
        borderRadius: MwbRadius.smAll,
        onTap: () => showProposalSheet(context, proposal: proposal, view: view),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(6, 0, 6, MwbSpace.sm),
          padding: const EdgeInsets.all(MwbSpace.sm),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: MwbRadius.smAll,
            border: Border.all(color: accent.withValues(alpha: 0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _statusLabel(p.status),
                style: t.overline.copyWith(color: accent, fontWeight: FontWeight.w700, letterSpacing: 0.8),
              ),
              const SizedBox(height: 4),
              if (p.rule.presentationMode == PresentationMode.nameInTitle) ...[
                Text(
                  p.rule.titleTemplate == null
                      ? 'Proposed title: (editorial title still needed)'
                      : 'Proposed title: ${p.rule.titleTemplate!.replaceAll(namePlaceholder, '[Name]')}',
                  style: t.cardTitle.copyWith(color: accent),
                ),
                Text('Scripture unchanged:', style: t.caption),
              ],
              Text(
                proposal.previewText ?? '(This rule cannot be applied to the current text. Open for details.)',
                style: t.scripture.copyWith(fontSize: 15, color: c.textPrimary, height: 1.5),
              ),
              const SizedBox(height: 6),
              Text(
                '${p.rule.edits.map((e) => e.operation.name).join(', ')} · ${p.risk.label} risk · ${p.status.label}',
                style: t.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full review details for one proposal.
Future<void> showProposalSheet(BuildContext context, {required MwbProposal proposal, required MwbChapterView view}) {
  final p = proposal.processed;
  final r = p.rule;
  return showMwbSheet<void>(
    context,
    title: _statusLabel(p.status),
    subtitle: '${r.reference.label} · ${view.edition.abbreviation} from ${view.source.abbreviation}',
    builder: (ctx) {
      final t = ctx.mwb.text;
      final c = ctx.mwb.colors;
      Widget field(String label, String value, {bool scripture = false}) => Padding(
        padding: const EdgeInsets.only(bottom: MwbSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: t.overline.copyWith(color: c.textSecondary)),
            const SizedBox(height: 4),
            Text(value, style: scripture ? t.scripture.copyWith(fontSize: 16) : t.body),
          ],
        ),
      );
      final approvals = r.reviews.where((h) => h.action == ReviewAction.approved && h.hasReviewer);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          field('Original ${view.source.abbreviation}', p.canonicalText ?? '(verse not found)', scripture: true),
          field(
            'Proposed ${view.edition.abbreviation}${proposal.usesPlaceholderName ? ' (no name set: showing [Name])' : ''}',
            proposal.previewText ?? '(cannot be rendered)',
            scripture: true,
          ),
          field('Operation', r.edits.map((e) => e.operation.name).join(', ')),
          field('Risk', '${p.risk.label}. ${{...r.riskReasons, ...p.report.risk.reasons}.join(' ')}'),
          field('Review status', p.status.label),
          field(
            'Approval',
            approvals.isEmpty
                ? 'No approval has been recorded. This rendering must not be read as approved Scripture.'
                : approvals.map((a) => '${a.reviewer} on ${a.at.toIso8601String().substring(0, 10)}').join('; '),
          ),
          if (r.grammaticalConditions.isNotEmpty) field('Grammar', r.grammaticalConditions.join(' ')),
          if (p.context != null)
            field(
              'Context',
              '${p.context!.author}. Speaker: ${p.context!.speaker.label}. Audience: ${p.context!.originalAudience}'
                  '${p.context!.conditionNote.isEmpty ? '' : ' ${p.context!.conditionNote}'}',
            ),
          field(
            'Automated validation',
            p.report.passed
                ? 'Passed (a technical check, not a theological approval).'
                : p.report.issues.where((i) => i.isError).map((i) => i.message).join(' '),
          ),
          if (r.reviewQuestion != null) field('Question for the reviewer', r.reviewQuestion!),
          if (r.rejectionReason != null) field('Rejection reason', r.rejectionReason!),
          field('Rule', '${r.id} (rule version ${r.ruleVersion})'),
        ],
      );
    },
  );
}

/// Switch for the reviewer preview. Renders nothing in builds that may not
/// offer reviewer tools.
class MwbReviewerModeTile extends ConsumerWidget {
  const MwbReviewerModeTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(reviewerToolsAvailableProvider)) return const SizedBox.shrink();
    return MwbSwitchTile(
      key: const ValueKey('mwb-reviewer-mode'),
      title: 'MWB reviewer preview',
      subtitle:
          'Shows proposed personalisations under their verses in MWB editions, marked "$proposedLabel". '
          'Scripture text itself still shows only approved passages.',
      value: ref.watch(mwbReviewerModeProvider),
      onChanged: (v) => ref.read(mwbReviewerModeProvider.notifier).set(v),
    );
  }
}
