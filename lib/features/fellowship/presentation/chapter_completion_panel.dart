import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/sheets.dart';
import '../../../data/models/personal_rhythm.dart';
import '../../../data/models/scripture_reference.dart';
import '../../../data/repositories/personal_repositories.dart';
import '../application/personal_providers.dart';
import 'personal_widgets.dart';

/// End-of-chapter panel in the reader. Reading is recorded **only** when the
/// user chooses "Complete reading"; opening or scrolling a chapter records
/// nothing.
class ChapterCompletionPanel extends ConsumerWidget {
  const ChapterCompletionPanel({
    super.key,
    required this.chapter,
    required this.versionId,
    required this.openedAt,
    required this.textColor,
  });

  final ScriptureReference chapter;

  /// Canonical translation being read.
  final String versionId;

  /// When this chapter was opened in the reader (start time if no session).
  final DateTime openedAt;
  final Color textColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(rhythmRepositoryProvider) == null) return const SizedBox.shrink();
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final done = ref.watch(chapterCompletionProvider(chapter));
    final session = ref.watch(activeSessionProvider);
    final sessionHere = session != null && session.chapter == chapter.chapterOnly;

    if (done != null) {
      return Row(
        key: const Key('reader.readingCompleted'),
        children: [
          Icon(Icons.check_circle_rounded, color: c.primary, size: 20),
          const SizedBox(width: MwbSpace.xs),
          Expanded(
            child: Text(
              'Reading completed today · ${clockTime(done.occurredAt)}',
              style: t.label.copyWith(color: textColor),
            ),
          ),
          MwbTextButton(
            key: const Key('reader.undoCompletion'),
            label: 'Undo',
            onPressed: () {
              ref.read(personalActionsProvider).removeCompletion(done.id);
              showMwbSnack(context, 'Removed from your rhythm');
            },
          ),
        ],
      );
    }

    return Container(
      key: const Key('reader.completionPanel'),
      padding: const EdgeInsets.all(MwbSpace.md),
      decoration: BoxDecoration(
        borderRadius: MwbRadius.lgAll,
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sessionHere ? 'Reading session · started ${clockTime(session.startedAt)}' : 'Finished ${chapter.label}?',
            style: t.label.copyWith(color: textColor, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Recorded privately in your Word rhythm, on this device only.',
            style: t.caption.copyWith(color: textColor.withValues(alpha: 0.75)),
          ),
          const SizedBox(height: MwbSpace.sm),
          MwbSecondaryButton(
            key: const Key('reader.completeReading'),
            label: 'Complete reading',
            icon: Icons.check_rounded,
            onPressed: () => _complete(context, ref),
          ),
          if (sessionHere)
            Center(
              child: MwbTextButton(
                key: const Key('reader.endSession'),
                label: 'End session',
                onPressed: () {
                  ref.read(personalActionsProvider).endSession(session.id);
                  showMwbSnack(context, 'Reading session ended');
                },
              ),
            ),
        ],
      ),
    );
  }

  void _complete(BuildContext context, WidgetRef ref) {
    try {
      final r = ref
          .read(personalActionsProvider)
          .completeReading(chapter, versionId: versionId, origin: PersonalOrigin.reader, openedAt: openedAt);
      showMwbSnack(
        context,
        r is AlreadyCompletedToday ? 'Already recorded today' : 'Reading completed',
        actionLabel: 'Reflect',
        onAction: () => context.push(
          AppRoutes.newReflection(reference: chapter.chapterOnly, versionId: versionId, source: PersonalOrigin.reader),
        ),
      );
    } on PersonalDataException catch (e) {
      showMwbSnack(context, e.message);
    }
  }
}
