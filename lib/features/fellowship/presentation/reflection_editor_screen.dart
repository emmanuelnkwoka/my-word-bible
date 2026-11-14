import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/bible.dart';
import '../../../data/models/personal_rhythm.dart';
import '../../../data/models/scripture_reference.dart';
import '../../../data/repositories/personal_repositories.dart';
import '../../bible/application/bible_providers.dart';
import '../application/personal_providers.dart';
import 'personal_widgets.dart';

/// Canonical text of a linked passage, read from the installed translation.
final _linkedPassageProvider = FutureProvider.family<Passage, (String, ScriptureReference)>(
  (ref, key) => ref.watch(bibleRepositoryProvider).passage(key.$1, key.$2),
);

/// Create or edit a private reflection.
class ReflectionEditorScreen extends ConsumerStatefulWidget {
  const ReflectionEditorScreen({
    super.key,
    this.entryId,
    this.reference,
    this.versionId,
    this.source = PersonalOrigin.independent,
    this.dailyWordDate,
  });

  /// Null when creating.
  final String? entryId;
  final ScriptureReference? reference;
  final String? versionId;
  final PersonalOrigin source;
  final String? dailyWordDate;

  @override
  ConsumerState<ReflectionEditorScreen> createState() => _ReflectionEditorScreenState();
}

class _ReflectionEditorScreenState extends ConsumerState<ReflectionEditorScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  ScriptureReference? _reference;
  String? _versionId;
  JournalEntry? _existing;
  bool _missing = false;
  bool _saving = false;
  String _savedTitle = '';
  String _savedBody = '';
  ScriptureReference? _savedReference;

  bool get _isNew => widget.entryId == null;
  bool get _dirty => _title.text != _savedTitle || _body.text != _savedBody || _reference != _savedReference;

  @override
  void initState() {
    super.initState();
    if (widget.entryId != null) {
      final e = ref.read(journalEntryProvider(widget.entryId!));
      if (e == null) {
        _missing = true;
      } else {
        _existing = e;
        _title.text = e.title;
        _body.text = e.body;
        _reference = e.reference;
        _versionId = e.versionId;
      }
    } else {
      _reference = widget.reference;
      _versionId = widget.reference == null
          ? null
          : ref.read(personalActionsProvider).canonicalVersion(widget.versionId ?? ref.read(textVersionProvider).id);
    }
    _savedTitle = _title.text;
    _savedBody = _body.text;
    _savedReference = _reference;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_body.text.trim().isEmpty) {
      showMwbSnack(context, 'Write something before saving');
      return;
    }
    setState(() => _saving = true);
    final actions = ref.read(personalActionsProvider);
    final draft = JournalDraft(
      title: _title.text,
      body: _body.text,
      reference: _reference,
      versionId: _versionId,
      source: _existing?.source ?? widget.source,
      dailyWordDate: _existing?.dailyWordDate ?? widget.dailyWordDate,
    );
    try {
      final saved = _isNew
          ? await actions.createReflection(draft)
          : await actions.updateReflection(widget.entryId!, draft);
      _savedTitle = _title.text;
      _savedBody = _body.text;
      _savedReference = _reference;
      if (!mounted) return;
      showMwbSnack(context, _isNew ? 'Reflection saved privately' : 'Reflection updated');
      if (_isNew) {
        context.pushReplacement(AppRoutes.journalEntry(saved.id));
      } else {
        setState(() => _existing = saved);
      }
    } on PersonalDataException catch (e) {
      if (mounted) showMwbSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showMwbConfirmDialog(
      context,
      title: 'Delete this reflection?',
      message: 'It will be permanently removed from this device. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    ref.read(personalActionsProvider).deleteReflection(widget.entryId!);
    _savedTitle = _title.text;
    _savedBody = _body.text;
    _savedReference = _reference;
    showMwbSnack(context, 'Reflection deleted');
    context.pop();
  }

  Future<void> _linkScripture() async {
    final result = await showMwbSheet<ScriptureReference>(
      context,
      title: 'Link a Scripture passage',
      subtitle: 'For example: John 3:16, Psalm 23, Romans 8:37-39',
      builder: (_) => _ReferenceInput(initial: _reference?.label ?? ''),
    );
    if (result == null || !mounted) return;
    setState(() {
      _reference = result;
      _versionId = ref.read(textVersionProvider).id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    if (_missing) {
      return Scaffold(
        appBar: AppBar(),
        body: const MwbEmptyState(
          title: 'Reflection not found',
          message: 'It may have been deleted.',
          icon: Icons.edit_off_outlined,
        ),
      );
    }
    final ready = ref.watch(journalRepositoryProvider) != null;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await showMwbConfirmDialog(
          context,
          title: 'Discard changes?',
          message: 'Your unsaved words will be lost.',
          confirmLabel: 'Discard',
          destructive: true,
        );
        if (discard && context.mounted) {
          _title.text = _savedTitle;
          _body.text = _savedBody;
          _reference = _savedReference;
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            if (!_isNew)
              MwbIconButton(
                key: const Key('reflection.delete'),
                icon: Icons.delete_outline_rounded,
                tooltip: 'Delete reflection',
                onPressed: _delete,
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: ListView(
          padding: MwbLayout.pagePadding(context, bottom: MwbSpace.xxxl),
          children: [
            Text(_isNew ? 'NEW REFLECTION' : 'REFLECTION', style: t.overline),
            if (_existing != null)
              Text(
                'Written ${longDate(_existing!.createdAt.toLocal())}'
                '${_existing!.updatedAt.isAfter(_existing!.createdAt) ? ' · edited' : ''}',
                style: t.caption.copyWith(color: c.textSecondary),
              ),
            const SizedBox(height: MwbSpace.md),
            const PersonalStoreNotice(),
            if (_reference != null) ...[
              _LinkedScripture(reference: _reference!, versionId: _versionId ?? ref.watch(textVersionProvider).id),
              Wrap(
                children: [
                  MwbTextButton(
                    key: const Key('reflection.changeLink'),
                    label: 'Change passage',
                    onPressed: _linkScripture,
                  ),
                  MwbTextButton(
                    key: const Key('reflection.removeLink'),
                    label: 'Remove link',
                    onPressed: () => setState(() => _reference = null),
                  ),
                ],
              ),
            ] else
              Align(
                alignment: Alignment.centerLeft,
                child: MwbTextButton(
                  key: const Key('reflection.link'),
                  label: 'Link a passage',
                  icon: Icons.link_rounded,
                  onPressed: _linkScripture,
                ),
              ),
            const SizedBox(height: MwbSpace.lg),
            const ReflectionLabel(),
            const SizedBox(height: MwbSpace.xs),
            MwbTextField(
              key: const Key('reflection.title'),
              label: 'Title (optional)',
              controller: _title,
              maxLength: SqlJournalRepository.maxTitleLength,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: MwbSpace.sm),
            MwbTextField(
              key: const Key('reflection.body'),
              label: 'What is on your heart?',
              controller: _body,
              hint: 'Write freely. Only you can read this.',
              minLines: 8,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: MwbSpace.sm),
            Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 14, color: c.textSecondary),
                const SizedBox(width: 4),
                Expanded(child: Text('Encrypted on this device. Not synced, not shared.', style: t.caption)),
              ],
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: MwbConstrained(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: MwbSpace.sm),
              child: MwbPrimaryButton(
                key: const Key('reflection.save'),
                label: _isNew ? 'Save reflection' : 'Save changes',
                loading: _saving,
                onPressed: ready && (_isNew || _dirty) ? _save : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The linked passage, shown as Scripture (canonical text, reference and
/// translation) and kept visually separate from the user's words.
class _LinkedScripture extends ConsumerWidget {
  const _LinkedScripture({required this.reference, required this.versionId});
  final ScriptureReference reference;
  final String versionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final abbreviation = ref.watch(versionCatalogueProvider).byId(versionId)?.abbreviation ?? versionId;
    final verseCount = reference.verseStart == null
        ? null
        : (reference.verseEnd ?? reference.verseStart!) - reference.verseStart! + 1;
    final showText = verseCount != null && verseCount <= 12;
    final passage = showText ? ref.watch(_linkedPassageProvider((versionId, reference))) : null;
    return Container(
      key: const Key('reflection.scripture'),
      padding: const EdgeInsets.all(MwbSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: MwbRadius.lgAll,
        border: Border(left: BorderSide(color: c.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SCRIPTURE', style: t.overline),
          const SizedBox(height: 4),
          if (passage != null)
            passage.when(
              loading: () => const SizedBox(height: 24),
              error: (_, _) => Text('The passage could not be loaded.', style: t.caption),
              data: (p) => Text(p.verses.where((v) => !v.isOmitted).map((v) => v.text).join(' '), style: t.scripture),
            ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () =>
                context.push(AppRoutes.reader(reference.bookId, reference.chapter, verse: reference.verseStart)),
            child: Text(
              '${reference.label} ($abbreviation)${showText ? '' : ' · open in the reader'}',
              style: t.scriptureReference,
            ),
          ),
        ],
      ),
    );
  }
}

/// Passage entry for linking; owns its controller for the sheet's lifetime.
class _ReferenceInput extends StatefulWidget {
  const _ReferenceInput({required this.initial});
  final String initial;

  @override
  State<_ReferenceInput> createState() => _ReferenceInputState();
}

class _ReferenceInputState extends State<_ReferenceInput> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MwbTextField(
        key: const Key('reflection.referenceInput'),
        label: 'Passage',
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
      ),
      const SizedBox(height: MwbSpace.md),
      MwbPrimaryButton(
        key: const Key('reflection.referenceApply'),
        label: 'Link',
        onPressed: () {
          final parsed = ScriptureReference.tryParse(_controller.text);
          if (parsed == null) {
            showMwbSnack(context, 'That is not a passage we recognise');
            return;
          }
          Navigator.of(context).pop(parsed);
        },
      ),
    ],
  );
}
