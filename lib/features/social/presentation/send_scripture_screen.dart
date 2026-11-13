import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/segmented.dart';
import '../../../core/widgets/sheets.dart';
import '../../../data/models/social.dart';
import '../../../data/repositories/social_repositories.dart';
import '../../share/scripture_image_composer.dart';
import '../application/social_providers.dart';
import 'social_widgets.dart';

/// Direct Scripture sharing: find a person, add an optional word, send.
///
/// The recipient is re-verified when sending (blocks and their sharing
/// settings), and the canonical text is re-read from the installed Bible.
class SendScriptureScreen extends ConsumerStatefulWidget {
  const SendScriptureScreen({super.key, required this.scripture, this.templateId = 'classic', this.recipient});

  final ShareScripture scripture;
  final String templateId;
  final PublicProfile? recipient;

  static Route<void> route(ShareScripture s, {String templateId = 'classic', PublicProfile? recipient}) =>
      MaterialPageRoute(builder: (_) => SendScriptureScreen(scripture: s, templateId: templateId, recipient: recipient));

  @override
  ConsumerState<SendScriptureScreen> createState() => _SendScriptureScreenState();
}

class _SendScriptureScreenState extends ConsumerState<SendScriptureScreen> {
  PublicProfile? _recipient;
  final _query = TextEditingController();
  final _message = TextEditingController();
  Future<List<PublicProfile>>? _results;
  Timer? _debounce;
  CareIntent? _care;
  SharePrivacy _privacy = SharePrivacy.private;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _recipient = widget.recipient;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _message.dispose();
    super.dispose();
  }

  void _search(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final next = q.trim().isEmpty ? null : ref.read(socialActionsProvider).search(q);
      setState(() { _results = next; });
    });
  }

  Future<void> _send() async {
    final recipient = _recipient;
    if (recipient == null || _sending) return;
    setState(() => _sending = true);
    try {
      final share = await ref
          .read(socialActionsProvider)
          .sendScripture(
            scripture: widget.scripture,
            recipient: recipient,
            message: _message.text,
            careIntent: _care,
            templateId: widget.templateId,
            privacy: _privacy,
          );
      if (!mounted) return;
      await _showResult(share, recipient);
      if (mounted) Navigator.of(context).pop();
    } on SocialFailure catch (e) {
      if (mounted) showMwbSnack(context, e.message);
    } catch (_) {
      if (mounted) showMwbSnack(context, 'This Scripture could not be prepared. Please try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showResult(ScriptureShare share, PublicProfile recipient) {
    final first = recipient.displayName.split(' ').first;
    final (title, message) = switch (share.status) {
      DeliveryStatus.simulated => (
        'Sent in the demo',
        '$first is a sample person on this device, so this was a simulation: no one else received it. '
            'It is saved in your share history.',
      ),
      DeliveryStatus.awaitingServer => (
        'Saved on this device',
        'It will be delivered to $first when My Word Bible accounts are live. It is in your share history.',
      ),
      DeliveryStatus.delivered || DeliveryStatus.sent => ('Sent', '$first will see it in their inbox.'),
      _ => ('Not sent', 'This Scripture could not be sent to $first.'),
    };
    return showMwbInfoSheet(
      context,
      icon: share.status == DeliveryStatus.failed ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
      title: title,
      message: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_recipient == null ? 'Send to someone' : 'Send Scripture')),
      body: SafeArea(child: _recipient == null ? _picker(context) : _compose(context, _recipient!)),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1: choose a person
  // ---------------------------------------------------------------------------

  Widget _picker(BuildContext context) {
    final t = context.mwb.text;
    final live = ref.watch(userDirectoryProvider).isLive;
    final recent = ref.watch(profilesProvider(ref.watch(recentRecipientIdsProvider))).value ?? const [];
    final following = ref.watch(profilesProvider(ref.watch(followingProvider).toList())).value ?? const [];
    final me = ref.watch(socialIdentityProvider).userId;
    final blocked = ref.watch(blockedUsersProvider);
    final suggested = live
        ? const <PublicProfile>[]
        : DemoUserDirectory.people.where((p) => !p.isRestricted && !blocked.contains(p.userId) && p.userId != me).toList();

    Widget section(String title, List<PublicProfile> people) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: MwbSpace.md),
        Text(title.toUpperCase(), style: t.overline),
        for (final p in people)
          PersonTile(key: Key('send.person.${p.userId}'), person: p, onTap: () => setState(() => _recipient = p)),
      ],
    );

    return ListView(
      padding: MwbLayout.pagePadding(context, top: MwbSpace.sm, bottom: MwbSpace.xxl),
      children: [
        if (!live)
          const SocialNotice(
            icon: Icons.science_outlined,
            message:
                'My Word Bible accounts are not live yet. The people here are a sample community on this phone so '
                'you can try sharing. Nothing you send leaves your device.',
          ),
        const SizedBox(height: MwbSpace.md),
        TextField(
          key: const Key('send.search'),
          controller: _query,
          autofocus: false,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: '@username, MWB ID or name',
          ),
          onChanged: _search,
        ),
        if (_results != null)
          FutureBuilder<List<PublicProfile>>(
            future: _results,
            builder: (context, snap) {
              final list = snap.data;
              if (list == null) return const Padding(padding: EdgeInsets.all(MwbSpace.lg), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: MwbSpace.lg),
                  child: Text('No one found. Check the username or ID.', style: t.supporting, key: const Key('send.noResults')),
                );
              }
              return section('Results', list);
            },
          )
        else ...[
          if (recent.isNotEmpty) section('Recent', recent),
          if (following.isNotEmpty) section('Following', following),
          if (suggested.isNotEmpty) section(live ? 'Suggested' : 'Sample community', suggested),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2: compose
  // ---------------------------------------------------------------------------

  Widget _compose(BuildContext context, PublicProfile recipient) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final s = widget.scripture;
    final first = recipient.displayName.split(' ').first;
    return ListView(
      padding: MwbLayout.pagePadding(context, top: MwbSpace.sm, bottom: MwbSpace.xxl),
      children: [
        PersonTile(
          person: recipient,
          trailing: TextButton(
            key: const Key('send.change'),
            onPressed: () => setState(() => _recipient = widget.recipient == null ? null : _recipient),
            child: const Text('Change'),
          ),
        ),
        const SizedBox(height: MwbSpace.md),
        _CanonicalPreview(scripture: s),
        if (s.personalised) ...[
          const SizedBox(height: MwbSpace.xs),
          SocialNotice(
            message:
                'Your personalised wording stays with you. $first receives the ${s.sourceVersionId} text, '
                'and can read it in their own personal edition if they choose.',
          ),
        ],
        const SizedBox(height: MwbSpace.lg),
        Text('Add a word (optional)', style: t.label.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: MwbSpace.xs),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final care in CareIntent.values)
              ChoiceChip(
                key: Key('send.care.${care.name}'),
                label: Text(care.label),
                selected: _care == care,
                showCheckmark: false,
                labelStyle: t.label.copyWith(
                  color: _care == care ? c.primaryStrong : c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                selectedColor: c.selected,
                backgroundColor: c.surfaceElevated,
                side: BorderSide(color: _care == care ? c.primary.withValues(alpha: 0.5) : c.border),
                shape: const StadiumBorder(),
                onSelected: (_) => setState(() {
                  _care = _care == care ? null : care;
                  _message.text = _care?.suggestion ?? '';
                }),
              ),
          ],
        ),
        const SizedBox(height: MwbSpace.sm),
        TextField(
          key: const Key('send.message'),
          controller: _message,
          maxLength: 280,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: 'A personal message for $first'),
        ),
        Text('Only $first can read your message. It is never shown in public link previews.', style: t.caption),
        const SizedBox(height: MwbSpace.lg),
        Text('Who can see it', style: t.label.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: MwbSpace.xs),
        MwbSegmentedControl<SharePrivacy>(
          options: SharePrivacy.values,
          value: _privacy,
          labelOf: (p) => p == SharePrivacy.private ? 'Private' : 'May pass it on',
          onChanged: (p) => setState(() => _privacy = p),
        ),
        const SizedBox(height: 4),
        Text(_privacy.description, style: t.caption),
        const SizedBox(height: MwbSpace.lg),
        MwbPrimaryButton(
          key: const Key('send.go'),
          label: 'Send to $first',
          icon: Icons.send_rounded,
          loading: _sending,
          onPressed: _sending ? null : _send,
        ),
      ],
    );
  }
}

/// Shows the canonical text that will actually be sent.
class _CanonicalPreview extends ConsumerStatefulWidget {
  const _CanonicalPreview({required this.scripture});
  final ShareScripture scripture;

  @override
  ConsumerState<_CanonicalPreview> createState() => _CanonicalPreviewState();
}

class _CanonicalPreviewState extends ConsumerState<_CanonicalPreview> {
  late final Future<String> _text;
  late final String _abbreviation;

  @override
  void initState() {
    super.initState();
    final bible = ref.read(bibleRepositoryProvider);
    final versionId = widget.scripture.sourceVersionId!;
    _abbreviation = bible.versions.where((v) => v.id == versionId).firstOrNull?.abbreviation ?? versionId;
    _text = Future.wait([
      for (final r in widget.scripture.sources) bible.passage(versionId, r),
    ]).then((ps) => ps.expand((p) => p.verses).where((v) => !v.isOmitted).map((v) => v.text).join(' '));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    return Container(
      padding: const EdgeInsets.all(MwbSpace.md),
      decoration: BoxDecoration(color: c.surface, borderRadius: MwbRadius.lgAll, border: Border.all(color: c.border)),
      child: FutureBuilder<String>(
        future: _text,
        builder: (context, snap) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              snap.data ?? '…',
              key: const Key('send.preview'),
              style: t.scripture.copyWith(fontSize: 17, height: 1.55),
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: MwbSpace.xs),
            Text(
              '— ${widget.scripture.reference} · $_abbreviation',
              style: t.scriptureReference.copyWith(color: c.primaryStrong),
            ),
          ],
        ),
      ),
    );
  }
}
