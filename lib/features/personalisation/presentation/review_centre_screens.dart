import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/bible_canon.dart';
import '../../../data/models/mwb_rule.dart';
import '../../../data/models/personalisation_catalogue.dart';
import '../../../data/models/scripture_reference.dart';
import '../../bible/application/bible_providers.dart';
import '../../daily_word/application/daily_word_providers.dart';
import '../application/mwb_reader_providers.dart';
import '../application/personalisation_providers.dart';
import '../application/scripture_presentation.dart';
import '../domain/personalisation_validator.dart';
import '../domain/review_queue.dart';
import '../domain/ruleset_processor.dart';

// ── State ────────────────────────────────────────────────────────────────

/// The reviewer's own name and role, typed by the reviewer and stored on
/// this device. Never pre-filled; designation is not approval.
@immutable
class ReviewerIdentity {
  const ReviewerIdentity({this.name = '', this.role = ''});
  final String name;
  final String role;
  bool get isSet => name.trim().isNotEmpty;
}

final reviewerIdentityProvider = NotifierProvider<ReviewerIdentityController, ReviewerIdentity>(
  ReviewerIdentityController.new,
);

class ReviewerIdentityController extends Notifier<ReviewerIdentity> {
  static const key = 'mwb.v1.reviewer_identity';

  @override
  ReviewerIdentity build() {
    final j = ref.watch(keyValueStoreProvider).readJson(key);
    if (j is! Map) return const ReviewerIdentity();
    return ReviewerIdentity(name: '${j['name'] ?? ''}', role: '${j['role'] ?? ''}');
  }

  Future<void> set(String name, String role) async {
    state = ReviewerIdentity(name: name.trim(), role: role.trim());
    await ref.read(keyValueStoreProvider).writeJson(key, {'name': state.name, 'role': state.role});
  }
}

final reviewEditionProvider = NotifierProvider<_EditionController, String>(_EditionController.new);

class _EditionController extends Notifier<String> {
  @override
  String build() => 'KJV-MWB';
  void set(String v) => state = v;
}

enum ReviewFilter {
  all('All'),
  pending('Pending'),
  approved('Approved'),
  corrected('Corrected'),
  rejected('Rejected'),
  flagged('Flagged');

  const ReviewFilter(this.label);
  final String label;

  bool matches(ProcessedRule p) => switch (this) {
    all => true,
    pending => const {
      RuleStatus.proposed,
      RuleStatus.automatedValidated,
      RuleStatus.underReview,
      RuleStatus.corrected,
    }.contains(p.status),
    approved => p.status == RuleStatus.approved,
    corrected => p.status == RuleStatus.corrected,
    rejected => p.status == RuleStatus.rejected,
    flagged =>
      !p.report.passed ||
          p.risk == RiskLevel.critical ||
          (p.rule.reviews.isNotEmpty && p.rule.reviews.last.action == ReviewAction.flagged),
  };
}

final reviewFilterProvider = NotifierProvider<_FilterController, ReviewFilter>(_FilterController.new);

class _FilterController extends Notifier<ReviewFilter> {
  @override
  ReviewFilter build() => ReviewFilter.pending;
  void set(ReviewFilter v) => state = v;
}

/// Proposals grouped by book, then chapter, then verse.
@immutable
class ReviewIndex {
  const ReviewIndex(this.all);
  final List<ProcessedRule> all;

  Iterable<ProcessedRule> forBook(String b) => all.where((p) => p.rule.reference.bookId == b);
  Iterable<ProcessedRule> forChapter(String b, int c) => forBook(b).where((p) => p.rule.reference.chapter == c);
}

final reviewIndexProvider = FutureProvider.family<ReviewIndex, String>((ref, edition) async {
  final q = await ref.watch(reviewQueueProvider(edition).future);
  return ReviewIndex(q);
});

Future<void> _refreshAfterDecision(WidgetRef ref) async {
  ref.invalidate(reviewQueueProvider);
  ref.invalidate(mwbChapterProvider);
  ref.invalidate(scripturePresentationProvider);
  ref.invalidate(dailyWordDetailProvider);
}

// ── Widgets shared by the review screens ───────────────────────────────────

Color _statusColor(BuildContext context, RuleStatus s) {
  final c = context.mwb.colors;
  return switch (s) {
    RuleStatus.approved => c.success,
    RuleStatus.rejected || RuleStatus.retired => c.error,
    RuleStatus.corrected || RuleStatus.underReview => c.warning,
    _ => c.textSecondary,
  };
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final RuleStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(MwbRadius.pill)),
      child: Text(
        status.label,
        style: context.mwb.text.caption.copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final k = color ?? c.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: k.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(MwbRadius.pill),
      ),
      child: Text(label, style: context.mwb.text.caption.copyWith(color: k, fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }
}

String _preview(ProcessedRule p) {
  final r = p.rule;
  if (r.presentationMode == PresentationMode.nameInTitle) {
    return r.titleTemplate == null ? 'Title still needed' : 'Title: ${r.titleTemplate!.replaceAll(namePlaceholder, reviewNamePlaceholder)}';
  }
  return p.previewText ?? 'Cannot be rendered — see validation';
}

class _EditionAndFilters extends ConsumerWidget {
  const _EditionAndFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edition = ref.watch(reviewEditionProvider);
    final filter = ref.watch(reviewFilterProvider);
    final c = context.mwb.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'KJV-MWB', label: Text('KJV-MWB')),
            ButtonSegment(value: 'WEB-MWB', label: Text('WEB-MWB')),
          ],
          selected: {edition},
          showSelectedIcon: false,
          onSelectionChanged: (s) => ref.read(reviewEditionProvider.notifier).set(s.first),
        ),
        const SizedBox(height: MwbSpace.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in ReviewFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    key: Key('review.filter.${f.name}'),
                    label: Text(f.label),
                    selected: f == filter,
                    showCheckmark: false,
                    selectedColor: c.selected,
                    labelStyle: context.mwb.text.label.copyWith(
                      color: f == filter ? c.primaryStrong : c.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: const StadiumBorder(),
                    onSelected: (_) => ref.read(reviewFilterProvider.notifier).set(f),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Review Centre (books) ───────────────────────────────────────────────────

class ReviewCentreScreen extends ConsumerWidget {
  const ReviewCentreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edition = ref.watch(reviewEditionProvider);
    final catalogue = ref.watch(personalisationCatalogueProvider(edition));
    final index = ref.watch(reviewIndexProvider(edition));
    final filter = ref.watch(reviewFilterProvider);
    final t = context.mwb.text;
    final c = context.mwb.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Personalisation review')),
      body: ListView(
        key: const Key('review.centre'),
        padding: MwbLayout.pagePadding(context, top: MwbSpace.sm, bottom: MwbSpace.xxxl),
        children: [
          const _ReviewerCard(),
          const SizedBox(height: MwbSpace.md),
          const _EditionAndFilters(),
          const SizedBox(height: MwbSpace.md),
          AsyncValueView<PersonalisationCatalogue>(
            value: catalogue,
            compact: true,
            data: (cat) => AsyncValueView<ReviewIndex>(
              value: index,
              compact: true,
              loadingMessage: 'Validating every proposal…',
              data: (ix) {
                final counts = cat.classCounts();
                int st(Set<RuleStatus> s) => ix.all.where((p) => s.contains(p.status)).length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MwbCard(
                      key: const Key('review.coverage'),
                      padding: const EdgeInsets.all(MwbSpace.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('COVERAGE · ${cat.sourceVersionId} · catalogue ${cat.catalogueVersion}', style: t.overline),
                          const SizedBox(height: MwbSpace.sm),
                          Wrap(
                            spacing: MwbSpace.md,
                            runSpacing: MwbSpace.sm,
                            children: [
                              _Stat('Verses processed', cat.verseCount),
                              _Stat('Proposals', ix.all.length),
                              _Stat('Name in text', ix.all.where((p) => p.rule.presentationMode == PresentationMode.nameInText).length),
                              _Stat('Name in title', ix.all.where((p) => p.rule.presentationMode == PresentationMode.nameInTitle).length),
                              _Stat('Pending', st(const {RuleStatus.proposed, RuleStatus.automatedValidated, RuleStatus.underReview, RuleStatus.corrected})),
                              _Stat('Approved', st(const {RuleStatus.approved})),
                              _Stat('Rejected', st(const {RuleStatus.rejected})),
                              _Stat('Original only', counts[VerseClass.originalOnly]!),
                              _Stat('Excluded', counts[VerseClass.excluded]!),
                              _Stat('Flagged verses', counts[VerseClass.contextualReview]!),
                            ],
                          ),
                          const SizedBox(height: MwbSpace.sm),
                          Text(
                            'Automated checks are technical results, never theological approval. Only proposals with a '
                            'recorded approval by a named reviewer appear in the app as personalised Scripture.',
                            style: t.caption,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: MwbSpace.lg),
                    Text('Books', style: t.sectionHeading),
                    const SizedBox(height: MwbSpace.xs),
                    for (final b in cat.books)
                      Builder(
                        builder: (context) {
                          final ps = ix.forBook(b.id).where(filter.matches).length;
                          final total = ix.forBook(b.id).length;
                          final bc = cat.classCounts(bookId: b.id);
                          return ListTile(
                            key: Key('review.book.${b.id}'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(b.name, style: t.cardTitle),
                            subtitle: Text(
                              '$total proposal${total == 1 ? '' : 's'} · ${bc[VerseClass.excluded]} excluded · '
                              '${bc[VerseClass.contextualReview]} flagged',
                              style: t.caption,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (ps > 0) _Chip('${filter.label} $ps', color: c.primaryStrong),
                                Icon(Icons.chevron_right_rounded, color: c.textSecondary),
                              ],
                            ),
                            onTap: () => context.push(AppRoutes.reviewBook(edition, b.id)),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    return SizedBox(
      width: 98,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: t.sectionHeading.copyWith(fontSize: 20)),
          Text(label, style: t.caption),
        ],
      ),
    );
  }
}

class _ReviewerCard extends ConsumerWidget {
  const _ReviewerCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(reviewerIdentityProvider);
    final t = context.mwb.text;
    return MwbCard(
      onTap: () => showReviewerIdentitySheet(context),
      child: Row(
        children: [
          Icon(Icons.badge_outlined, color: context.mwb.colors.primary),
          const SizedBox(width: MwbSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(id.isSet ? id.name : 'Set your reviewer name', style: t.cardTitle),
                Text(
                  id.isSet ? (id.role.isEmpty ? 'Reviewer' : id.role) : 'Decisions are recorded under the name you enter.',
                  style: t.caption,
                ),
              ],
            ),
          ),
          const Icon(Icons.edit_outlined, size: 18),
        ],
      ),
    );
  }
}

Future<void> showReviewerIdentitySheet(BuildContext context) => showMwbSheet<void>(
  context,
  title: 'Reviewer',
  subtitle: 'Enter your own name. Every decision you record carries it and the date.',
  builder: (ctx) => const _ReviewerForm(),
);

class _ReviewerForm extends ConsumerStatefulWidget {
  const _ReviewerForm();
  @override
  ConsumerState<_ReviewerForm> createState() => _ReviewerFormState();
}

class _ReviewerFormState extends ConsumerState<_ReviewerForm> {
  late final _name = TextEditingController(text: ref.read(reviewerIdentityProvider).name);
  late final _role = TextEditingController(text: ref.read(reviewerIdentityProvider).role);

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Your name')),
        const SizedBox(height: MwbSpace.sm),
        TextField(controller: _role, decoration: const InputDecoration(labelText: 'Role (e.g. Theological supervisor)')),
        const SizedBox(height: MwbSpace.md),
        MwbPrimaryButton(
          label: 'Save',
          onPressed: () async {
            await ref.read(reviewerIdentityProvider.notifier).set(_name.text, _role.text);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
        SizedBox(height: MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom),
      ],
    );
  }
}

// ── Book (chapters) ──────────────────────────────────────────────────────

class ReviewBookScreen extends ConsumerWidget {
  const ReviewBookScreen({super.key, required this.edition, required this.bookId});
  final String edition;
  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cat = ref.watch(personalisationCatalogueProvider(edition));
    final index = ref.watch(reviewIndexProvider(edition));
    final filter = ref.watch(reviewFilterProvider);
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final name = BibleCanon.byId(bookId)?.name ?? bookId;
    return Scaffold(
      appBar: AppBar(title: Text('$name · $edition')),
      body: AsyncValueView<PersonalisationCatalogue>(
        value: cat,
        data: (cat) => AsyncValueView<ReviewIndex>(
          value: index,
          data: (ix) {
            final book = cat.book(bookId)!;
            return ListView(
              padding: MwbLayout.pagePadding(context, top: MwbSpace.sm, bottom: MwbSpace.xxxl),
              children: [
                Text('${book.author} · ${book.form}', style: t.supporting),
                Text('First audience: ${book.audience}', style: t.caption),
                const SizedBox(height: MwbSpace.md),
                for (var ch = 1; ch <= book.chapters.length; ch++)
                  Builder(
                    builder: (context) {
                      final cc = cat.classCounts(bookId: bookId, chapter: ch);
                      final ps = ix.forChapter(bookId, ch).toList();
                      final shown = ps.where(filter.matches).length;
                      return ListTile(
                        key: Key('review.chapter.$ch'),
                        contentPadding: EdgeInsets.zero,
                        title: Text('Chapter $ch', style: t.cardTitle),
                        subtitle: Text(
                          '${book.chapters[ch - 1].length} verses · ${ps.length} proposals · '
                          '${cc[VerseClass.excluded]} excluded · ${cc[VerseClass.contextualReview]} flagged',
                          style: t.caption,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (shown > 0) _Chip('${filter.label} $shown', color: c.primaryStrong),
                            Icon(Icons.chevron_right_rounded, color: c.textSecondary),
                          ],
                        ),
                        onTap: () => context.push(AppRoutes.reviewChapter(edition, bookId, ch)),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Chapter (verses) ─────────────────────────────────────────────────────

class ReviewChapterScreen extends ConsumerWidget {
  const ReviewChapterScreen({super.key, required this.edition, required this.bookId, required this.chapter});
  final String edition;
  final String bookId;
  final int chapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cat = ref.watch(personalisationCatalogueProvider(edition));
    final index = ref.watch(reviewIndexProvider(edition));
    final source = edition.startsWith('WEB') ? 'WEB' : 'KJV';
    final verses = ref.watch(_chapterTextProvider((source, bookId, chapter)));
    final filter = ref.watch(reviewFilterProvider);
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final name = BibleCanon.byId(bookId)?.name ?? bookId;
    return Scaffold(
      appBar: AppBar(title: Text('$name $chapter · $edition')),
      body: AsyncValueView<PersonalisationCatalogue>(
        value: cat,
        data: (cat) => AsyncValueView<ReviewIndex>(
          value: index,
          data: (ix) => AsyncValueView<List<String>>(
            value: verses,
            data: (texts) => ListView.builder(
              padding: MwbLayout.pagePadding(context, top: MwbSpace.sm, bottom: MwbSpace.xxxl),
              itemCount: texts.length,
              itemBuilder: (context, i) {
                final v = i + 1;
                final k = cat.classify(bookId, chapter, v)!;
                final ps = ix.forChapter(bookId, chapter).where((p) => p.rule.reference.verseStart == v).toList();
                return Padding(
                  padding: const EdgeInsets.only(bottom: MwbSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('$v', style: t.cardTitle.copyWith(color: c.primary)),
                          const SizedBox(width: MwbSpace.xs),
                          Flexible(child: _Chip(k.verseClass.label)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(texts[i], style: t.scripture.copyWith(fontSize: 16)),
                      Text('${k.reason.label}: ${k.reason.explanation}', style: t.caption),
                      for (final p in ps.where(filter.matches))
                        Padding(
                          padding: const EdgeInsets.only(top: MwbSpace.xs),
                          child: MwbCard(
                            key: Key('review.proposal.${p.rule.id}'),
                            elevated: false,
                            color: c.selected.withValues(alpha: 0.5),
                            onTap: () => context.push(AppRoutes.reviewProposal(edition, p.rule.id)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(p.rule.presentationMode.label, style: t.overline.copyWith(fontSize: 10.5))),
                                    _StatusPill(p.status),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(_preview(p), style: t.scripture.copyWith(fontSize: 15.5)),
                                const SizedBox(height: 4),
                                Text(
                                  '${p.rule.id} · v${p.rule.ruleVersion} · ${p.risk.label} risk · '
                                  '${p.report.passed ? 'checks passed' : 'checks failed'}',
                                  style: t.caption,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

final _chapterTextProvider = FutureProvider.family<List<String>, (String, String, int)>((ref, k) async {
  final verses = await ref.watch(bibleRepositoryProvider).chapter(k.$1, k.$2, k.$3);
  return [for (final v in verses) v.isOmitted ? '(not in this translation)' : v.text];
});

// ── Proposal detail and decisions ────────────────────────────────────────

class ReviewProposalScreen extends ConsumerWidget {
  const ReviewProposalScreen({super.key, required this.edition, required this.ruleId});
  final String edition;
  final String ruleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(reviewIndexProvider(edition));
    final t = context.mwb.text;
    final c = context.mwb.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Proposal')),
      body: AsyncValueView<ReviewIndex>(
        value: index,
        data: (ix) {
          final p = ix.all.where((x) => x.rule.id == ruleId).firstOrNull;
          if (p == null) return const MwbEmptyState(title: 'Not found', message: 'This proposal no longer exists.');
          final r = p.rule;
          final ctx = p.context;
          Widget fact(String k, String v) => v.trim().isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(k.toUpperCase(), style: t.overline.copyWith(fontSize: 10.5)),
                      Text(v, style: t.body.copyWith(fontSize: 14)),
                    ],
                  ),
                );
          final original = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ORIGINAL ${r.sourceVersionId}', style: t.overline),
              const SizedBox(height: 4),
              Text(p.canonicalText ?? '(verse not found)', style: t.scripture.copyWith(fontSize: 17)),
            ],
          );
          final proposed = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PROPOSED ${r.targetVersionId}', style: t.overline.copyWith(color: c.primaryStrong)),
              const SizedBox(height: 4),
              if (r.presentationMode == PresentationMode.nameInTitle)
                Text(
                  r.titleTemplate == null
                      ? 'Title: (still needed)'
                      : 'Title: ${r.titleTemplate!.replaceAll(namePlaceholder, reviewNamePlaceholder)}',
                  style: t.cardTitle.copyWith(color: c.primaryStrong),
                ),
              Text(
                r.presentationMode == PresentationMode.nameInTitle
                    ? (p.canonicalText ?? '')
                    : (p.previewText ?? '(cannot be rendered — see validation)'),
                style: t.scripture.copyWith(fontSize: 17),
              ),
            ],
          );
          final wide = MediaQuery.sizeOf(context).width > 640;
          return ListView(
            key: const Key('review.proposal'),
            padding: MwbLayout.pagePadding(context, top: MwbSpace.sm, bottom: MwbSpace.xxxl),
            children: [
              Row(
                children: [
                  Expanded(child: Text(r.reference.label, style: t.pageHeading)),
                  _StatusPill(p.status),
                ],
              ),
              Text('${r.id} · rule version ${r.ruleVersion} · ${r.presentationMode.label}', style: t.caption),
              const SizedBox(height: MwbSpace.md),
              MwbCard(
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Expanded(child: original), const SizedBox(width: MwbSpace.md), Expanded(child: proposed)],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [original, Divider(height: MwbSpace.xl, color: c.divider), proposed],
                      ),
              ),
              const SizedBox(height: MwbSpace.md),
              _Decisions(edition: edition, processed: p),
              const SizedBox(height: MwbSpace.lg),
              Text('Transformation', style: t.sectionHeading),
              const SizedBox(height: MwbSpace.xs),
              if (r.edits.isEmpty) Text('None — the Scripture text is unchanged.', style: t.body),
              for (final e in r.edits)
                Text('• ${e.operation.name}, ${e.position.name} “${e.anchor}” → “${e.text}”', style: t.body.copyWith(fontSize: 14)),
              for (final g in r.grammaticalConditions) Text('• $g', style: t.supporting),
              const SizedBox(height: MwbSpace.lg),
              Text('Context', style: t.sectionHeading),
              const SizedBox(height: MwbSpace.xs),
              fact('Author', r.meta.author.isNotEmpty ? r.meta.author : (ctx?.author ?? '')),
              fact('Speaker', r.meta.speaker.isNotEmpty ? r.meta.speaker : (ctx?.speaker.label ?? '')),
              fact('Original audience', r.meta.audience.isNotEmpty ? r.meta.audience : (ctx?.originalAudience ?? '')),
              fact('Literary form', r.meta.literaryForm),
              fact('Classification', [r.meta.classification, r.meta.reason].where((x) => x.isNotEmpty).join(' — ')),
              fact('Eligibility rationale', r.meta.rationale.isNotEmpty ? r.meta.rationale : r.riskReasons.join(' ')),
              fact('Context source', r.meta.contextSource),
              fact('Pronoun number source', r.meta.numberSource),
              fact('Confidence', r.meta.confidence),
              fact('Uncertainty', r.meta.uncertainty),
              fact('Question for the reviewer', r.reviewQuestion ?? ''),
              fact('Title source', r.meta.titleSource ?? ''),
              fact('Notes', r.notes),
              fact(
                'Provenance',
                r.meta.isGenerated
                    ? 'Generated (catalogue ${r.meta.catalogueVersion}, generator rule v${r.meta.generatorRuleVersion})'
                    : 'Hand-authored ruleset',
              ),
              const SizedBox(height: MwbSpace.lg),
              Text('Automated validation', style: t.sectionHeading),
              const SizedBox(height: MwbSpace.xs),
              Text(
                p.report.passed ? 'Passed (technical checks only — not an approval)' : 'Failed',
                style: t.cardTitle.copyWith(color: p.report.passed ? c.success : c.error),
              ),
              Text('Risk: ${p.risk.label}', style: t.supporting),
              for (final i in p.report.issues)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${i.severity == IssueSeverity.error ? 'Error' : 'Warning'}: ${i.message}',
                    style: t.supporting.copyWith(color: i.isError ? c.error : c.warning),
                  ),
                ),
              const SizedBox(height: MwbSpace.lg),
              Text('Review history', style: t.sectionHeading),
              const SizedBox(height: MwbSpace.xs),
              if (r.reviews.isEmpty) Text('No decisions recorded.', style: t.supporting),
              for (final h in r.reviews)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${h.at.toIso8601String().substring(0, 10)} · ${h.action.name} by ${h.reviewer ?? 'unnamed'}'
                    '${h.reviewerRole == null ? '' : ' (${h.reviewerRole})'} · v${h.ruleVersion}'
                    '${h.rejectionReason != null ? ' · ${h.rejectionReason}' : h.comments.isEmpty ? '' : ' · ${h.comments}'}'
                    '${h.correctedText != null ? '\nCorrected: ${h.correctedText}' : ''}'
                    '${h.correctedTitle != null ? '\nCorrected title: ${h.correctedTitle}' : ''}',
                    style: t.supporting,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Decisions extends ConsumerWidget {
  const _Decisions({required this.edition, required this.processed});
  final String edition;
  final ProcessedRule processed;

  Future<void> _record(BuildContext context, WidgetRef ref, ReviewAction action) async {
    final id = ref.read(reviewerIdentityProvider);
    if (!id.isSet && action != ReviewAction.comment && action != ReviewAction.flagged) {
      await showReviewerIdentitySheet(context);
      if (!ref.read(reviewerIdentityProvider).isSet) return;
    }
    if (!context.mounted) return;
    final input = await showMwbSheet<_DecisionInput>(
      context,
      title: switch (action) {
        ReviewAction.approved => 'Approve version ${processed.rule.ruleVersion}',
        ReviewAction.rejected => 'Reject',
        ReviewAction.corrected => 'Submit corrected wording',
        ReviewAction.flagged => 'Flag as uncertain',
        ReviewAction.reopened => 'Reopen decision',
        _ => 'Comment',
      },
      subtitle: action == ReviewAction.approved
          ? 'Recorded as your approval, with your name and today’s date, for this exact version.'
          : null,
      builder: (ctx) => _DecisionForm(action: action, processed: processed),
    );
    if (input == null || !context.mounted) return;
    final who = ref.read(reviewerIdentityProvider);
    try {
      await ref
          .read(reviewQueueServiceProvider)
          .recordDecision(
            edition,
            processed.rule.id,
            ReviewDecision(
              action: action,
              at: ref.read(clockProvider)(),
              reviewer: who.isSet ? who.name : null,
              reviewerRole: who.role.isEmpty ? null : who.role,
              comments: input.comments,
              rejectionReason: action == ReviewAction.rejected ? input.comments : null,
              correctedText: input.text,
              correctedTitle: input.title,
            ),
          );
      await _refreshAfterDecision(ref);
      if (context.mounted) showMwbSnack(context, 'Decision recorded');
    } on AppFailure catch (e) {
      if (context.mounted) showMwbSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = processed.status;
    final decided = const {RuleStatus.approved, RuleStatus.rejected, RuleStatus.retired, RuleStatus.corrected}.contains(s);
    final canApprove = processed.report.passed && s != RuleStatus.approved && !s.isClosed;
    final buttons = <(String, IconData, ReviewAction, bool)>[
      ('Approve', Icons.check_circle_outline_rounded, ReviewAction.approved, canApprove),
      ('Reject', Icons.block_rounded, ReviewAction.rejected, !s.isClosed),
      ('Correct', Icons.edit_note_rounded, ReviewAction.corrected, !s.isClosed),
      ('Flag', Icons.flag_outlined, ReviewAction.flagged, !s.isClosed),
      ('Comment', Icons.chat_bubble_outline_rounded, ReviewAction.comment, true),
      if (decided) ('Reopen', Icons.restart_alt_rounded, ReviewAction.reopened, true),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final b in buttons)
              OutlinedButton.icon(
                key: Key('review.action.${b.$3.name}'),
                onPressed: b.$4 ? () => _record(context, ref, b.$3) : null,
                icon: Icon(b.$2, size: 18),
                label: Text(b.$1),
                style: OutlinedButton.styleFrom(shape: const StadiumBorder(), minimumSize: const Size(0, 44)),
              ),
          ],
        ),
        if (!processed.report.passed)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Approval is unavailable while automated validation fails. Correct the wording or reject it.',
              style: context.mwb.text.caption,
            ),
          ),
      ],
    );
  }
}

@immutable
class _DecisionInput {
  const _DecisionInput({this.comments = '', this.text, this.title});
  final String comments;
  final String? text;
  final String? title;
}

class _DecisionForm extends StatefulWidget {
  const _DecisionForm({required this.action, required this.processed});
  final ReviewAction action;
  final ProcessedRule processed;

  @override
  State<_DecisionForm> createState() => _DecisionFormState();
}

class _DecisionFormState extends State<_DecisionForm> {
  final _comments = TextEditingController();
  late final _text = TextEditingController(
    text: widget.processed.rule.presentationMode == PresentationMode.nameInText
        ? (widget.processed.previewText ?? widget.processed.canonicalText ?? '').replaceAll(reviewNamePlaceholder, namePlaceholder)
        : '',
  );
  late final _title = TextEditingController(text: widget.processed.rule.titleTemplate ?? '{name}, ');

  @override
  void dispose() {
    _comments.dispose();
    _text.dispose();
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final correcting = widget.action == ReviewAction.corrected;
    final titleMode = widget.processed.rule.presentationMode == PresentationMode.nameInTitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (correcting && !titleMode) ...[
          TextField(
            controller: _text,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Corrected verse (write {name} where the name goes)'),
          ),
          const SizedBox(height: MwbSpace.sm),
        ],
        if (correcting && titleMode) ...[
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Corrected title (use {name} once)')),
          const SizedBox(height: MwbSpace.sm),
        ],
        TextField(
          controller: _comments,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: switch (widget.action) {
              ReviewAction.rejected => 'Reason (required)',
              ReviewAction.flagged => 'Why is this uncertain? (required)',
              ReviewAction.reopened => 'Reason for reopening (required)',
              _ => 'Comments',
            },
          ),
        ),
        const SizedBox(height: MwbSpace.md),
        MwbPrimaryButton(
          key: const Key('review.confirm'),
          label: 'Record decision',
          onPressed: () => Navigator.of(context).pop(
            _DecisionInput(
              comments: _comments.text.trim(),
              text: correcting && !titleMode ? _text.text.trim() : null,
              title: correcting && titleMode ? _title.text.trim() : null,
            ),
          ),
        ),
        SizedBox(height: MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom),
      ],
    );
  }
}

/// Convenience used by the Profile entry.
ScriptureReference reviewReference(String bookId, int chapter) => ScriptureReference(bookId: bookId, chapter: chapter);
