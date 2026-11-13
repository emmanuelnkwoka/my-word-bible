import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/sheets.dart';
import '../../library/application/library_controllers.dart';
import '../../personalisation/application/scripture_presentation.dart';
import '../../personalisation/presentation/presented_scripture.dart';
import '../../share/scripture_share_sheet.dart';
import '../application/daily_word_providers.dart';

IconData categoryIcon(String category) => switch (category.toLowerCase()) {
  'hope' => Icons.wb_sunny_rounded,
  'peace' => Icons.spa_rounded,
  'strength' => Icons.bolt_rounded,
  'courage' => Icons.shield_rounded,
  'provision' => Icons.volunteer_activism_rounded,
  'comfort' => Icons.favorite_rounded,
  'wisdom' => Icons.lightbulb_rounded,
  'healing' => Icons.healing_rounded,
  'rest' => Icons.nightlight_round,
  'gratitude' => Icons.celebration_rounded,
  'identity' => Icons.workspace_premium_rounded,
  'protection' => Icons.security_rounded,
  'guidance' => Icons.explore_rounded,
  'purpose' => Icons.flag_rounded,
  'faith' => Icons.local_fire_department_rounded,
  'family' => Icons.diversity_1_rounded,
  _ => Icons.auto_awesome_rounded,
};

/// The Daily Word as the reference "verse card": category and date, the
/// title for the presentation mode, the Scripture (with the reader's name in
/// gold where an approved rendering applies), the reference, and one clear
/// Share action.
class DailyWordHero extends ConsumerWidget {
  const DailyWordHero({super.key, required this.detail, this.onOpen, this.showQuickActions = true});

  final DailyWordDetail detail;

  /// Opens the full Daily Word (Home only).
  final VoidCallback? onOpen;
  final bool showQuickActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final p = detail.presentation;
    final e = detail.entry;
    final saved = ref.watch(savedScriptureProvider).any((s) => s.reference == e.reference);
    final title = p.title ?? dailyWordFallbackTitle;
    final long = p.text.length > 320;

    return DecoratedBox(
      key: const Key('dailyWord.scripture'),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), boxShadow: c.softShadow),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Material(
          color: c.surfaceElevated,
          child: InkWell(
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(height: 4, decoration: BoxDecoration(gradient: c.brandGradient)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: c.selected, borderRadius: BorderRadius.circular(MwbRadius.pill)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(categoryIcon(e.category), size: 14, color: c.primaryStrong),
                                const SizedBox(width: 5),
                                Text(
                                  e.category,
                                  style: t.label.copyWith(fontWeight: FontWeight.w600, color: c.textPrimary, fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: MwbSpace.xs),
                          Expanded(
                            child: Text(
                              DateFormat('EEEE, d MMM').format(e.date),
                              key: const Key('dailyWord.date'),
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.caption.copyWith(fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: MwbSpace.lg),
                      Semantics(
                        header: true,
                        child: NamedTitle(
                          key: const Key('dailyWord.title'),
                          text: title,
                          name: p.mode == ScriptureMode.nameInTitle ? p.titleName : null,
                          style: t.sectionHeading.copyWith(fontSize: 21, color: c.textPrimary),
                        ),
                      ),
                      const SizedBox(height: MwbSpace.md),
                      PresentedScriptureText(
                        key: const Key('dailyWord.text'),
                        presentation: p,
                        textAlign: long ? TextAlign.left : TextAlign.center,
                        style: t.scripture.copyWith(fontSize: long ? 18 : 21.5, height: 1.55, color: c.textPrimary),
                      ),
                      const SizedBox(height: MwbSpace.lg),
                      Center(child: Container(width: 120, height: 1, color: c.primary.withValues(alpha: 0.35))),
                      const SizedBox(height: MwbSpace.md),
                      Text(
                        '— ${e.reference.label}',
                        textAlign: TextAlign.center,
                        style: t.scripture.copyWith(
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                          color: c.primaryStrong,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.translationLabel,
                        textAlign: TextAlign.center,
                        style: t.caption.copyWith(letterSpacing: 1.6, fontWeight: FontWeight.w600, fontSize: 11.5),
                      ),
                      if (p.isPreview) ...[
                        const SizedBox(height: MwbSpace.sm),
                        const Center(child: PreviewBadge()),
                      ],
                      for (final (i, reception) in p.receptions.indexed) ...[
                        const SizedBox(height: MwbSpace.md),
                        EditorialReception(
                          key: Key('dailyWord.reception.$i'),
                          layer: reception,
                          fontSize: 15,
                        ),
                      ],
                      const SizedBox(height: MwbSpace.lg),
                      MwbPrimaryButton(
                        key: const Key('dailyWord.share'),
                        label: 'Share this verse',
                        icon: Icons.ios_share_rounded,
                        onPressed: () => showScriptureShareSheet(context, shareScriptureFromPresentation(p)),
                      ),
                      if (showQuickActions) ...[
                        const SizedBox(height: MwbSpace.sm),
                        Row(
                          children: [
                            _QuickAction(
                              key: const Key('dailyWord.quickSave'),
                              icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                              label: saved ? 'Saved' : 'Save',
                              active: saved,
                              onTap: () async {
                                final now = await ref
                                    .read(savedScriptureProvider.notifier)
                                    .toggle(e.reference, versionId: detail.version.id);
                                if (context.mounted) showMwbSnack(context, now ? 'Saved to your Library' : 'Removed from your Library');
                              },
                            ),
                            _QuickAction(
                              icon: Icons.auto_awesome_rounded,
                              label: 'Reflect',
                              active: true,
                              onTap: onOpen ?? () => context.push(AppRoutes.dailyWord(e.dateKey)),
                            ),
                            _QuickAction(
                              icon: Icons.menu_book_rounded,
                              label: 'Read',
                              onTap: () => context.push(
                                AppRoutes.reader(e.reference.bookId, e.reference.chapter, verse: e.reference.verseStart),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({super.key, required this.icon, required this.label, required this.onTap, this.active = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final color = active ? c.primaryStrong : c.textSecondary;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: MwbRadius.mdAll,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Icon(icon, color: color, size: 23),
                const SizedBox(height: 4),
                Text(label, style: t.caption.copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 12.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
