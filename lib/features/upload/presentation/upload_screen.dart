import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/notices.dart';
import '../../../core/widgets/selection.dart';
import '../../../core/widgets/sheets.dart';
import '../../../data/mock/mock_topics.dart';
import '../../../data/models/content.dart';
import '../../../data/models/library_items.dart';
import '../../../data/models/scripture_reference.dart';
import '../../bible/application/bible_providers.dart';
import '../../discovery/application/content_providers.dart';
import '../../library/application/library_controllers.dart';
import '../application/upload_validation.dart';

/// Contribution flow: details → review → saved as a draft on the device.
class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _attribution = TextEditingController();
  final _refInput = TextEditingController();
  UploadKind _kind = UploadKind.shortVideo;
  final Set<String> _topics = {};
  final List<ScriptureReference> _refs = [];
  bool _rights = false;
  bool _submitted = false;
  bool _reviewing = false;
  bool _saving = false;
  String? _refError;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _attribution.dispose();
    _refInput.dispose();
    super.dispose();
  }

  Future<void> _addReference() async {
    final (ref, error) = UploadValidation.parseReference(_refInput.text, _refs);
    if (ref == null) {
      setState(() => _refError = error);
      return;
    }
    // Confirm the verse exists in the installed translation.
    try {
      await this.ref.read(passageProvider(ref).future);
    } catch (_) {
      setState(() => _refError = '${ref.label} is not in the Bible text.');
      return;
    }
    setState(() {
      _refs.add(ref);
      _refInput.clear();
      _refError = null;
    });
  }

  bool get _isValid =>
      UploadValidation.topics(_topics) == null &&
      UploadValidation.references(_refs) == null &&
      UploadValidation.rights(_rights) == null;

  void _review() {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    final fieldsOk = _form.currentState!.validate();
    if (fieldsOk && _isValid) setState(() => _reviewing = true);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref
        .read(uploadDraftsProvider.notifier)
        .add(
          UploadDraft(
            id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
            kind: _kind,
            title: _title.text.trim(),
            description: _description.text.trim(),
            topicIds: _topics.toList(),
            scriptureRefs: List.of(_refs),
            attribution: _attribution.text.trim(),
            status: ModerationStatus.draft,
            createdAt: DateTime.now(),
          ),
        );
    if (!mounted) return;
    // Capture router and messenger before this screen is removed.
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    context.pop();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Draft saved on this device'),
        action: SnackBarAction(label: 'View', onPressed: () => router.go(AppRoutes.librarySection('drafts'))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_reviewing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _reviewing = false);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_reviewing ? 'Review' : 'Share a message')),
        body: AnimatedSwitcher(
          duration: MwbMotion.medium,
          child: _reviewing ? _buildReview(context) : _buildForm(context),
        ),
        bottomNavigationBar: SafeArea(
          child: MwbConstrained(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: MwbSpace.sm),
              child: _reviewing
                  ? MwbPrimaryButton(label: 'Save draft for review', loading: _saving, onPressed: _save)
                  : MwbPrimaryButton(key: const Key('upload.review'), label: 'Review submission', onPressed: _review),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final c = context.mwb.colors;
    final text = context.mwb.text;
    final topics = (ref.watch(topicsProvider).value ?? const []).where((x) => primaryTopicIds.contains(x.id)).toList();
    final topicsError = _submitted ? UploadValidation.topics(_topics) : null;
    final refsError = _submitted ? UploadValidation.references(_refs) : null;
    final rightsError = _submitted ? UploadValidation.rights(_rights) : null;

    Widget label(String s, {String? hint}) => Padding(
      padding: const EdgeInsets.only(top: MwbSpace.xl, bottom: MwbSpace.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(s, style: text.label.copyWith(fontWeight: FontWeight.w600)),
          ),
          if (hint != null) Text(hint, style: text.caption),
        ],
      ),
    );
    Widget error(String? e) => e == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(e, style: text.caption.copyWith(color: c.error)),
          );

    return Form(
      key: _form,
      child: ListView(
        key: const ValueKey('form'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: MwbLayout.pagePadding(context, bottom: MwbSpace.xxxl),
        children: [
          Text(
            'Share a short, valuable excerpt from a message that has blessed you, so other believers can benefit too.',
            style: text.body.copyWith(color: c.textSecondary),
          ),
          label('What are you sharing?'),
          MwbRadioGroup<UploadKind>(
            options: UploadKind.values,
            value: _kind,
            labelOf: (k) => k.label,
            subtitleOf: (k) => k.description,
            iconOf: (k) => switch (k) {
              UploadKind.shortVideo => Icons.videocam_outlined,
              UploadKind.audio => Icons.mic_none_rounded,
              UploadKind.audioFromVideo => Icons.graphic_eq_rounded,
            },
            onChanged: (k) => setState(() => _kind = k),
          ),
          label('Media file'),
          MwbCard(
            color: c.surface,
            child: Row(
              children: [
                Icon(Icons.cloud_upload_outlined, color: c.disabled),
                const SizedBox(width: MwbSpace.sm),
                Expanded(
                  child: Text(
                    'File selection and upload will be enabled with MWB media hosting. You can prepare the details now.',
                    style: text.caption,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MwbSpace.xl),
          MwbTextField(
            key: const Key('upload.title'),
            label: 'Title',
            controller: _title,
            maxLength: 80,
            validator: UploadValidation.title,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: MwbSpace.md),
          MwbTextField(
            key: const Key('upload.description'),
            label: 'Description',
            controller: _description,
            minLines: 3,
            maxLines: 6,
            maxLength: 600,
            validator: UploadValidation.description,
            hint: 'What is the message about, and why is it helpful?',
          ),
          const SizedBox(height: MwbSpace.md),
          MwbTextField(
            key: const Key('upload.attribution'),
            label: 'Speaker or ministry',
            controller: _attribution,
            maxLength: 60,
            validator: UploadValidation.attribution,
            textCapitalization: TextCapitalization.words,
            helper: 'Credit the person who delivered the message.',
          ),
          label('Topics', hint: '${_topics.length}/${UploadValidation.maxTopics}'),
          Wrap(
            spacing: MwbSpace.xs,
            runSpacing: MwbSpace.xs,
            children: [
              for (final topic in topics)
                MwbChip(
                  label: topic.name,
                  selected: _topics.contains(topic.id),
                  onTap: () => setState(() {
                    if (_topics.contains(topic.id)) {
                      _topics.remove(topic.id);
                    } else if (_topics.length < UploadValidation.maxTopics) {
                      _topics.add(topic.id);
                    } else {
                      showMwbSnack(context, 'Choose up to ${UploadValidation.maxTopics} topics');
                    }
                  }),
                ),
            ],
          ),
          error(topicsError),
          label('Scripture references'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('upload.reference'),
                  controller: _refInput,
                  onSubmitted: (_) => _addReference(),
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(hintText: 'e.g. Isaiah 41:10', errorText: _refError),
                ),
              ),
              const SizedBox(width: MwbSpace.xs),
              MwbIconButton(icon: Icons.add_rounded, tooltip: 'Add reference', filled: true, onPressed: _addReference),
            ],
          ),
          if (_refs.isNotEmpty) ...[
            const SizedBox(height: MwbSpace.sm),
            Wrap(
              spacing: MwbSpace.xs,
              runSpacing: MwbSpace.xs,
              children: [
                for (final r in _refs)
                  InputChip(
                    label: Text(r.label),
                    onDeleted: () => setState(() => _refs.remove(r)),
                    deleteButtonTooltipMessage: 'Remove ${r.label}',
                  ),
              ],
            ),
          ],
          error(refsError),
          const SizedBox(height: MwbSpace.xl),
          MwbCheckbox(
            value: _rights,
            onChanged: (v) => setState(() => _rights = v),
            label: 'I have permission to share this material',
            description: 'The excerpt is accurately attributed and does not misrepresent the speaker or Scripture.',
          ),
          error(rightsError),
          const SizedBox(height: MwbSpace.lg),
          const MwbNotice(
            message:
                'Every contribution will be reviewed before it is published. In Foundation V1, '
                'submissions are saved on your device as drafts until online review launches.',
          ),
        ],
      ),
    );
  }

  Widget _buildReview(BuildContext context) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final topicNames = {for (final topic in ref.read(topicsProvider).value ?? const []) topic.id: topic.name};
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: MwbSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: t.overline.copyWith(color: c.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: t.body),
        ],
      ),
    );
    return ListView(
      key: const ValueKey('review'),
      padding: MwbLayout.pagePadding(context, bottom: MwbSpace.xxxl),
      children: [
        Text(_title.text.trim(), style: t.pageHeading),
        const SizedBox(height: MwbSpace.lg),
        row('Type', _kind.label),
        row('Description', _description.text.trim()),
        row('Speaker or ministry', _attribution.text.trim()),
        row('Topics', _topics.map((id) => topicNames[id] ?? id).join(', ')),
        row('Scripture', _refs.map((r) => r.label).join(', ')),
        const MwbNotice(
          title: 'What happens next',
          message:
              'Your draft is saved in Library → Media → My contributions. When MWB online services '
              'launch, you will be able to attach the media file and submit it for review.',
        ),
        const SizedBox(height: MwbSpace.md),
        MwbTextButton(label: 'Edit details', onPressed: () => setState(() => _reviewing = false)),
      ],
    );
  }
}
