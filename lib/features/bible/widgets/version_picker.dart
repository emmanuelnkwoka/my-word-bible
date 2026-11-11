import 'package:flutter/material.dart';

import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/notices.dart';
import '../../../core/widgets/selection.dart';
import '../../../data/catalogue/version_catalogue.dart';
import '../../../data/models/bible.dart';

/// Explanation shown wherever a Bible version is chosen.
const mwbVersionExplanation =
    'An MWB edition is a personalised rendering derived from its original translation. '
    'The original translation is never changed, and you can always read it untouched.';

/// The one version picker used by the reader, onboarding and settings.
///
/// Each original translation is listed with its MY WORD BIBLE edition grouped
/// beneath it. Versions that cannot be selected yet (not installed, licence
/// required, in development) stay visible with an honest reason.
class BibleVersionPicker extends StatelessWidget {
  const BibleVersionPicker({
    super.key,
    required this.catalogue,
    required this.selectedId,
    required this.onSelected,
    this.showExplanation = true,
  });

  final VersionCatalogue catalogue;
  final String selectedId;
  final ValueChanged<BibleVersionInfo> onSelected;
  final bool showExplanation;

  @override
  Widget build(BuildContext context) {
    final families = catalogue.families;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < families.length; i++) ...[
          if (i > 0) const SizedBox(height: MwbSpace.md),
          _VersionTile(version: families[i].original, picker: this),
          for (final edition in families[i].editions) ...[
            const SizedBox(height: MwbSpace.xs),
            Padding(
              padding: const EdgeInsets.only(left: MwbSpace.lg),
              child: _VersionTile(version: edition, picker: this),
            ),
          ],
        ],
        if (showExplanation) ...[const SizedBox(height: MwbSpace.md), const MwbNotice(message: mwbVersionExplanation)],
      ],
    );
  }
}

class _VersionTile extends StatelessWidget {
  const _VersionTile({required this.version, required this.picker});

  final BibleVersionInfo version;
  final BibleVersionPicker picker;

  @override
  Widget build(BuildContext context) {
    final selectable = picker.catalogue.isSelectable(version);
    return MwbSelectionCard(
      key: ValueKey('version-${version.id}'),
      title: version.isPersonalised ? version.abbreviation : '${version.name} (${version.abbreviation})',
      subtitle: version.note,
      icon: version.isPersonalised ? Icons.subdirectory_arrow_right_rounded : null,
      selected: version.id == picker.selectedId,
      enabled: selectable,
      trailingNote: version.isPersonalised ? 'MWB' : null,
      dense: true,
      onTap: selectable ? () => picker.onSelected(version) : null,
    );
  }
}
