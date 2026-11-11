import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/notices.dart';
import '../../../core/widgets/selection.dart';
import '../../../core/widgets/sheets.dart';
import '../../../data/models/content.dart';
import '../../../data/models/creator.dart';
import '../../../data/models/library_items.dart';
import '../../library/application/library_controllers.dart';

String contentShareText(ContentItem item, Creator? creator) {
  final by = creator == null ? '' : ' — ${creator.displayName}';
  final refs = item.scriptureRefs.isEmpty ? '' : '\nScripture: ${item.scriptureRefs.map((r) => r.label).join(', ')}';
  return '${item.title}$by$refs\n\nShared from My Word Bible';
}

Future<void> shareContent(BuildContext context, ContentItem item, Creator? creator) async {
  await Clipboard.setData(ClipboardData(text: contentShareText(item, creator)));
  if (context.mounted) showMwbSnack(context, 'Details copied — ready to share');
}

String? validateCollectionName(String? value, List<ContentCollection> existing, {String? exceptId}) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Give your collection a name.';
  if (v.length > 40) return 'Use 40 characters or fewer.';
  if (existing.any((c) => c.id != exceptId && c.name.toLowerCase() == v.toLowerCase())) {
    return 'You already have a collection with this name.';
  }
  return null;
}

/// Create (or rename) a collection. Returns the name, or null if cancelled.
Future<String?> showCollectionNameSheet(BuildContext context, {String? initial, String? exceptId}) {
  return showMwbSheet<String>(
    context,
    title: initial == null ? 'New collection' : 'Rename collection',
    builder: (ctx) => _CollectionNameForm(initial: initial, exceptId: exceptId),
  );
}

class _CollectionNameForm extends ConsumerStatefulWidget {
  const _CollectionNameForm({this.initial, this.exceptId});
  final String? initial;
  final String? exceptId;

  @override
  ConsumerState<_CollectionNameForm> createState() => _CollectionNameFormState();
}

class _CollectionNameFormState extends ConsumerState<_CollectionNameForm> {
  late final _controller = TextEditingController(text: widget.initial ?? '');
  final _key = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_key.currentState!.validate()) Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final existing = ref.watch(collectionsProvider);
    return Form(
      key: _key,
      child: Column(
        children: [
          TextFormField(
            controller: _controller,
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => validateCollectionName(v, existing, exceptId: widget.exceptId),
            onFieldSubmitted: (_) => _submit(),
            decoration: const InputDecoration(hintText: 'e.g. Messages on prayer'),
          ),
          const SizedBox(height: MwbSpace.md),
          MwbPrimaryButton(label: widget.initial == null ? 'Create collection' : 'Save', onPressed: _submit),
        ],
      ),
    );
  }
}

/// Toggle an item's membership in personal collections.
Future<void> showAddToCollectionSheet(BuildContext context, ContentItem item) {
  return showMwbSheet<void>(
    context,
    title: 'Add to collection',
    subtitle: item.title,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final collections = ref.watch(collectionsProvider);
        final ctrl = ref.read(collectionsProvider.notifier);
        return Column(
          children: [
            if (collections.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: MwbSpace.md),
                child: Text('You have no collections yet.', style: ctx.mwb.text.supporting),
              ),
            for (final c in collections)
              MwbCheckbox(
                value: c.contentIds.contains(item.id),
                label: c.name,
                description: '${c.contentIds.length} ${c.contentIds.length == 1 ? 'item' : 'items'}',
                onChanged: (_) => ctrl.toggleItem(c.id, item.id),
              ),
            const SizedBox(height: MwbSpace.md),
            MwbSecondaryButton(
              label: 'New collection',
              icon: Icons.add_rounded,
              onPressed: () async {
                final name = await showCollectionNameSheet(ctx);
                if (name != null) await ctrl.create(name, contentIds: [item.id]);
              },
            ),
          ],
        );
      },
    ),
  );
}

/// Report content for review. Stored on the device until moderation
/// services exist.
Future<void> showReportSheet(BuildContext context, ContentItem item) {
  return showMwbSheet<void>(
    context,
    title: 'Report content',
    subtitle: 'Help keep MWB faithful, safe and edifying.',
    builder: (ctx) => _ReportForm(item: item),
  );
}

class _ReportForm extends ConsumerStatefulWidget {
  const _ReportForm({required this.item});
  final ContentItem item;

  @override
  ConsumerState<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends ConsumerState<_ReportForm> {
  ReportReason? _reason;
  final _details = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) {
      setState(() => _showError = true);
      return;
    }
    await ref
        .read(contentReportsProvider.notifier)
        .submit(
          ContentReport(
            contentId: widget.item.id,
            reason: _reason!,
            details: _details.text.trim(),
            createdAt: DateTime.now(),
          ),
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    showMwbSnack(context, 'Thank you. Your report has been recorded.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MwbRadioGroup<ReportReason>(
          options: ReportReason.values,
          value: _reason,
          labelOf: (r) => r.label,
          dense: true,
          onChanged: (r) => setState(() {
            _reason = r;
            _showError = false;
          }),
        ),
        if (_showError) ...[
          const SizedBox(height: 6),
          Text('Please choose a reason.', style: t.caption.copyWith(color: c.error)),
        ],
        const SizedBox(height: MwbSpace.md),
        TextField(
          controller: _details,
          maxLength: 500,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Anything else we should know? (optional)'),
        ),
        const MwbNotice(
          message:
              'Reports are saved on this device for now and will be sent to the MWB review team '
              'when moderation services launch.',
        ),
        const SizedBox(height: MwbSpace.md),
        MwbPrimaryButton(label: 'Submit report', onPressed: _submit),
      ],
    );
  }
}
