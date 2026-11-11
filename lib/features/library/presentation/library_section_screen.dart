import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/state_views.dart';
import '../application/library_controllers.dart';
import 'library_sections.dart';

/// Full list for one library section.
class LibrarySectionScreen extends ConsumerWidget {
  const LibrarySectionScreen({super.key, required this.section});

  final String section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = LibrarySection.fromSlug(section);
    if (s == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const MwbEmptyState(title: 'Not found', message: 'This part of the library does not exist.'),
      );
    }
    final items = librarySectionItems(context, ref, s);
    final clearable = s == LibrarySection.history || s == LibrarySection.viewed;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.title),
        actions: [
          if (clearable && items.isNotEmpty)
            TextButton(
              onPressed: () async {
                final ok = await showMwbConfirmDialog(
                  context,
                  title: 'Clear ${s.title.toLowerCase()}?',
                  message: 'This removes the list from this device. Your saved items are not affected.',
                  confirmLabel: 'Clear',
                  destructive: true,
                );
                if (!ok) return;
                if (s == LibrarySection.history) {
                  await ref.read(readingHistoryProvider.notifier).clear();
                } else {
                  await ref.read(recentlyViewedProvider.notifier).clear();
                }
                if (context.mounted) showMwbSnack(context, '${s.title} cleared');
              },
              style: TextButton.styleFrom(foregroundColor: context.mwb.colors.error),
              child: const Text('Clear'),
            ),
        ],
      ),
      body: items.isEmpty
          ? MwbEmptyState(icon: s.icon, title: 'Nothing here yet', message: s.emptyHint)
          : ListView(
              padding: MwbLayout.pagePadding(context, top: MwbSpace.sm, bottom: MwbSpace.xxxl),
              children: items,
            ),
    );
  }
}
