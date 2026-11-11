import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/sheets.dart';
import '../../../data/models/library_items.dart';
import '../../../data/models/scripture_reference.dart';
import '../application/library_controllers.dart';

String? validateNote(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Write something before saving.';
  if (v.length > 2000) return 'Notes can be up to 2,000 characters.';
  return null;
}

/// Create or edit a personal note on a verse or passage.
Future<void> showNoteEditor(BuildContext context, {required ScriptureReference reference, VerseNote? existing}) {
  return showMwbSheet<void>(
    context,
    title: existing == null ? 'New note' : 'Edit note',
    subtitle: reference.label,
    builder: (ctx) => _NoteEditor(reference: reference, existing: existing),
  );
}

class _NoteEditor extends ConsumerStatefulWidget {
  const _NoteEditor({required this.reference, this.existing});
  final ScriptureReference reference;
  final VerseNote? existing;

  @override
  ConsumerState<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends ConsumerState<_NoteEditor> {
  late final _controller = TextEditingController(text: widget.existing?.text ?? '');
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final notes = ref.read(notesProvider.notifier);
    if (widget.existing == null) {
      await notes.addNote(widget.reference, _controller.text);
    } else {
      await notes.updateNote(widget.existing!.id, _controller.text);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    showMwbSnack(context, 'Note saved');
  }

  Future<void> _delete() async {
    final ok = await showMwbConfirmDialog(
      context,
      title: 'Delete this note?',
      message: 'This note will be permanently removed from this device.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await ref.read(notesProvider.notifier).deleteNote(widget.existing!.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    showMwbSnack(context, 'Note deleted');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _controller,
            autofocus: true,
            minLines: 4,
            maxLines: 10,
            maxLength: 2000,
            validator: validateNote,
            style: t.body,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'What is God showing you in this passage?'),
          ),
          const SizedBox(height: MwbSpace.md),
          MwbPrimaryButton(label: 'Save note', loading: _saving, onPressed: _save),
          if (widget.existing != null) ...[
            const SizedBox(height: MwbSpace.xs),
            TextButton(
              onPressed: _delete,
              style: TextButton.styleFrom(foregroundColor: context.mwb.colors.error, minimumSize: const Size(48, 48)),
              child: const Text('Delete note'),
            ),
          ],
        ],
      ),
    );
  }
}
