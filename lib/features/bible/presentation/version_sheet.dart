import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/widgets/sheets.dart';
import '../../profile/application/profile_controllers.dart';
import '../application/bible_providers.dart';
import '../widgets/version_picker.dart';

/// Version selector sheet for the reader. Uses the shared [BibleVersionPicker].
Future<void> showVersionSheet(BuildContext context) {
  return showMwbSheet<void>(
    context,
    title: 'Bible version',
    subtitle: 'Choose an original translation or its My Word Bible edition.',
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        return BibleVersionPicker(
          catalogue: ref.watch(versionCatalogueProvider),
          selectedId: ref.watch(activeVersionProvider).id,
          onSelected: (v) {
            ref.read(readingPreferencesProvider.notifier).update((p) => p.copyWith(versionId: v.id));
            Navigator.of(ctx).pop();
          },
        );
      },
    ),
  );
}
