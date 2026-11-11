import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/content.dart';
import '../../content/presentation/content_actions.dart';
import '../../content/widgets/content_cards.dart';
import '../../discovery/application/content_providers.dart';
import '../application/library_controllers.dart';

class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key, required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(collectionsProvider).where((c) => c.id == collectionId).firstOrNull;
    final contentMap = ref.watch(contentMapProvider).value ?? const <String, ContentItem>{};
    final t = context.mwb.text;

    if (collection == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const MwbEmptyState(title: 'Collection not found', message: 'It may have been deleted.'),
      );
    }
    final ctrl = ref.read(collectionsProvider.notifier);
    final items = collection.contentIds.map((id) => contentMap[id]).whereType<ContentItem>().toList();

    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Collection options',
            onSelected: (v) async {
              if (v == 'rename') {
                final name = await showCollectionNameSheet(context, initial: collection.name, exceptId: collection.id);
                if (name != null) await ctrl.rename(collection.id, name);
              } else if (v == 'delete') {
                final ok = await showMwbConfirmDialog(
                  context,
                  title: 'Delete “${collection.name}”?',
                  message: 'The collection will be removed. The messages themselves stay saved where they are.',
                  confirmLabel: 'Delete',
                  destructive: true,
                );
                if (ok) {
                  await ctrl.delete(collection.id);
                  if (context.mounted) {
                    context.pop();
                    showMwbSnack(context, 'Collection deleted');
                  }
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete collection')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: MwbLayout.pagePadding(context, bottom: MwbSpace.xxxl),
        children: [
          Text('COLLECTION', style: t.overline),
          const SizedBox(height: 4),
          Text(collection.name, style: t.pageHeading),
          const SizedBox(height: 4),
          Text('${items.length} ${items.length == 1 ? 'item' : 'items'}', style: t.supporting),
          const SizedBox(height: MwbSpace.lg),
          if (items.isEmpty)
            const MwbEmptyState(
              title: 'This collection is empty',
              message: 'Open any message and choose “Add to collection” from the menu.',
            )
          else
            for (final item in items)
              ContentListTile(
                item: item,
                trailing: MwbIconButton(
                  icon: Icons.remove_circle_outline_rounded,
                  tooltip: 'Remove from collection',
                  onPressed: () => ctrl.toggleItem(collection.id, item.id),
                ),
              ),
        ],
      ),
    );
  }
}
