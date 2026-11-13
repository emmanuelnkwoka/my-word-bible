import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/segmented.dart';
import '../../../core/widgets/sheets.dart';
import '../../../data/models/social.dart';
import '../../social/application/social_providers.dart';
import '../../social/presentation/send_scripture_screen.dart';
import '../export/card_export.dart';
import '../export/card_export_flow.dart';
import '../scripture_image_composer.dart';
import '../scripture_share_sheet.dart';
import 'card_design.dart';
import 'card_studio_renderer.dart';

enum _Panel {
  design('Design'),
  text('Text'),
  personal('Personal'),
  save('Save');

  const _Panel(this.label);
  final String label;
}

/// Premium card creation. The preview is the exported PNG itself, so what
/// you see is exactly what is saved or sent.
class CardStudioScreen extends ConsumerStatefulWidget {
  const CardStudioScreen({super.key, required this.scripture, this.initialFormat, this.encouragement = false});

  final ShareScripture scripture;
  final ShareFormat? initialFormat;

  /// Opened from "With encouragement": starts on the Personal panel.
  final bool encouragement;

  static Route<void> route(ShareScripture s, {ShareFormat? format, bool encouragement = false}) =>
      MaterialPageRoute(builder: (_) => CardStudioScreen(scripture: s, initialFormat: format, encouragement: encouragement));

  @override
  ConsumerState<CardStudioScreen> createState() => _CardStudioScreenState();
}

class _CardStudioScreenState extends ConsumerState<CardStudioScreen> {
  late CardDesign _design;
  ShareDestination _destination = ShareDestination.anyApp;
  CardFileType _type = CardFileType.png;
  int _quality = CardEncoder.defaultJpgQuality;
  bool _withCaption = true;
  CareIntent? _care;
  late _Panel _panel;
  late final TextEditingController _message;
  late final String _myName;

  List<ShareImagePage>? _pages;
  Object? _error;
  bool _busy = false;
  int _generation = 0;
  int _page = 0;
  Timer? _debounce;
  final _controller = PageController(viewportFraction: 0.9);

  @override
  void initState() {
    super.initState();
    final store = ref.read(keyValueStoreProvider);
    final saved = store.readJson(StorageKeys.cardStudioLast);
    var design = saved is Map<String, dynamic> ? CardDesign.fromJson(saved) : const CardDesign();
    if (widget.initialFormat != null) design = design.copyWith(format: widget.initialFormat);
    final identity = ref.read(socialIdentityProvider);
    _myName = identity.displayName.split(' ').first;
    final showName = ref.read(socialPrivacyProvider).showNameOnCards;
    _design = design.copyWith(senderName: showName && _myName.isNotEmpty ? _myName : null);
    _panel = widget.encouragement ? _Panel.personal : _Panel.design;
    _message = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _render());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _message.dispose();
    super.dispose();
  }

  void _update(CardDesign d, {bool immediate = false}) {
    setState(() => _design = d);
    _debounce?.cancel();
    _debounce = Timer(immediate ? Duration.zero : const Duration(milliseconds: 260), _render);
    ref.read(keyValueStoreProvider).writeJson(StorageKeys.cardStudioLast, d.toJson());
  }

  Future<void> _render() async {
    if (!mounted) return;
    final gen = ++_generation;
    setState(() => _error = null);
    try {
      final pages = await const CardStudioRenderer().compose(
        widget.scripture,
        _design,
        classicStyle: ShareStyle.fromPalette(context.mwb.colors),
      );
      if (!mounted || gen != _generation) return;
      setState(() {
        _pages = pages;
        if (_page >= pages.length) _page = 0;
      });
    } catch (e) {
      if (mounted && gen == _generation) setState(() => _error = e);
    }
  }

  Future<void> _run(Future<void> Function(List<ShareImagePage>) action) async {
    final pages = _pages;
    if (pages == null || _busy) return;
    setState(() => _busy = true);
    try {
      await action(pages);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _send() => _run(
    (pages) => CardExportFlow.send(
      context,
      ref,
      pages: pages,
      scripture: widget.scripture,
      destination: _destination,
      type: _type,
      quality: _quality,
      withText: _withCaption,
    ),
  );

  void _save({bool chooseLocation = false}) => _run(
    (pages) => CardExportFlow.save(
      context,
      ref,
      pages: pages,
      scripture: widget.scripture,
      type: _type,
      quality: _quality,
      chooseLocation: chooseLocation,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final pages = _pages;
    final previewHeight = (MediaQuery.sizeOf(context).height * 0.44).clamp(220.0, 520.0);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Card Studio', style: t.cardTitle),
            Text('${widget.scripture.reference} · ${widget.scripture.translation}', style: t.caption),
          ],
        ),
      ),
      body: ListView(
        key: const Key('studio.scroll'),
        padding: const EdgeInsets.only(bottom: MwbSpace.xl),
        children: [
          SizedBox(
            height: previewHeight,
            child: _error != null
                ? Center(child: Text('The card could not be created.', style: t.supporting))
                : pages == null
                ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: c.primary))
                : PageView.builder(
                    key: const Key('studio.preview'),
                    controller: _controller,
                    itemCount: pages.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: MwbSpace.xs),
                      child: Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(borderRadius: MwbRadius.mdAll, boxShadow: c.softShadow),
                          child: ClipRRect(
                            borderRadius: MwbRadius.mdAll,
                            child: AspectRatio(
                              aspectRatio: pages[i].width / pages[i].height,
                              child: Semantics(
                                image: true,
                                label: 'Card preview, ${widget.scripture.reference}, image ${i + 1} of ${pages.length}',
                                child: Image.memory(pages[i].png, fit: BoxFit.contain, gaplessPlayback: true),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: MwbSpace.xs),
            child: Text(
              pages == null
                  ? ' '
                  : '${_design.format.label} · ${_design.format.width}×${_design.format.height}'
                        '${pages.length > 1 ? ' · image ${_page + 1} of ${pages.length}, whole passage included' : ''}',
              key: const Key('studio.pageInfo'),
              textAlign: TextAlign.center,
              style: t.caption,
            ),
          ),
          const SizedBox(height: MwbSpace.md),
          _SectionLabel('Where is it going?'),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: MwbSpace.gutter),
              children: [
                for (final d in ShareDestination.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _Chip(
                      key: Key('studio.dest.${d.name}'),
                      label: d.label,
                      selected: _destination == d,
                      onTap: () {
                        setState(() => _destination = d);
                        if (_design.format != d.format) _update(_design.copyWith(format: d.format), immediate: true);
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: MwbSpace.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MwbSpace.gutter),
            child: MwbSegmentedControl<_Panel>(
              options: _Panel.values,
              value: _panel,
              labelOf: (p) => p.label,
              onChanged: (p) => setState(() => _panel = p),
            ),
          ),
          const SizedBox(height: MwbSpace.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MwbSpace.gutter),
            child: switch (_panel) {
              _Panel.design => _designPanel(context),
              _Panel.text => _textPanel(context),
              _Panel.personal => _personalPanel(context),
              _Panel.save => _savePanel(context),
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(MwbSpace.gutter, MwbSpace.sm, MwbSpace.gutter, MwbSpace.sm),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(top: BorderSide(color: c.divider)),
          ),
          child: Row(
            children: [
              MwbIconButton(
                key: const Key('studio.save'),
                icon: Icons.download_rounded,
                tooltip: 'Save to Photos',
                filled: true,
                onPressed: pages == null || _busy ? null : _save,
              ),
              const SizedBox(width: MwbSpace.xs),
              MwbIconButton(
                key: const Key('studio.sendInApp'),
                icon: Icons.person_add_alt_1_rounded,
                tooltip: 'Send to someone in My Word Bible',
                filled: true,
                onPressed: widget.scripture.isResolvable
                    ? () => Navigator.of(context).push(
                        SendScriptureScreen.route(widget.scripture, templateId: _design.template.id),
                      )
                    : null,
              ),
              const SizedBox(width: MwbSpace.sm),
              Expanded(
                child: MwbPrimaryButton(
                  key: const Key('studio.share'),
                  label: _destination == ShareDestination.anyApp ? 'Share' : 'Share to ${_destination.label}',
                  icon: Icons.ios_share_rounded,
                  loading: _busy,
                  onPressed: pages == null || _busy ? null : _send,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Panels
  // ---------------------------------------------------------------------------

  Widget _designPanel(BuildContext context) {
    final t = context.mwb.text;
    final d = _design;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: CardTemplate.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: MwbSpace.xs),
            itemBuilder: (context, i) {
              final tpl = CardTemplate.values[i];
              return _TemplateTile(
                template: tpl,
                selected: d.template == tpl,
                onTap: () => _update(d.copyWith(template: tpl), immediate: true),
              );
            },
          ),
        ),
        const SizedBox(height: MwbSpace.xs),
        Text(d.template.description, style: t.caption),
        if (!d.template.isClassic) ...[
          const SizedBox(height: MwbSpace.md),
          _Label('Background'),
          Wrap(
            spacing: MwbSpace.xs,
            runSpacing: MwbSpace.xs,
            children: [
              for (var i = 0; i < d.template.colorways.length; i++)
                _Swatch(
                  key: Key('studio.colorway.$i'),
                  colors: d.template.colorways[i].background,
                  label: d.template.colorways[i].name,
                  selected: d.colorway == i,
                  onTap: () => _update(d.copyWith(colorway: i, clearInk: true), immediate: true),
                ),
            ],
          ),
        ],
        const SizedBox(height: MwbSpace.md),
        _Label('Size'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final f in ShareFormat.values)
              _Chip(
                key: Key('studio.format.${f.name}'),
                label: '${f.label} ${f.width}×${f.height}',
                selected: d.format == f,
                onTap: () => _update(d.copyWith(format: f), immediate: true),
              ),
          ],
        ),
        if (!d.template.isClassic) ...[
          const SizedBox(height: MwbSpace.sm),
          _Toggle(
            key: const Key('studio.decorations'),
            label: 'Decorative details',
            value: d.decorations,
            onChanged: (v) => _update(d.copyWith(decorations: v)),
          ),
        ],
      ],
    );
  }

  Widget _classicNote(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: MwbSpace.sm),
    child: Text(
      'Classic is the quick-share card in your app theme. Choose another design to change type, colours or add a note.',
      style: context.mwb.text.supporting,
    ),
  );

  Widget _textPanel(BuildContext context) {
    final d = _design;
    if (d.template.isClassic) return _classicNote(context);
    final multi = widget.scripture.verses.length > 1 || widget.scripture.numbered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('Typeface'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final f in CardFont.values)
              _Chip(
                key: Key('studio.font.${f.name}'),
                label: f.label,
                selected: d.effectiveFont == f,
                onTap: () => _update(d.copyWith(font: f)),
              ),
          ],
        ),
        const SizedBox(height: MwbSpace.md),
        _Label('Text size'),
        Wrap(
          spacing: 6,
          children: [
            for (final (scale, label) in [(0.85, 'Smaller'), (1.0, 'Standard'), (1.15, 'Larger')])
              _Chip(
                key: Key('studio.scale.$label'),
                label: label,
                selected: d.textScale == scale,
                onTap: () => _update(d.copyWith(textScale: scale)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Long passages still fit: the card adds pages rather than cutting text.', style: context.mwb.text.caption),
        const SizedBox(height: MwbSpace.md),
        _Label('Alignment'),
        MwbSegmentedControl<CardAlignment>(
          options: CardAlignment.values,
          value: d.alignment,
          labelOf: (a) => a.label,
          onChanged: (a) => _update(d.copyWith(alignment: a)),
        ),
        const SizedBox(height: MwbSpace.md),
        _Label('Text colour'),
        Wrap(
          spacing: MwbSpace.xs,
          children: [
            for (final (i, color) in d.inkOptions.indexed)
              _InkDot(
                key: Key('studio.ink.$i'),
                color: color,
                selected: d.effectiveInk == color,
                onTap: () => _update(d.copyWith(ink: color)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Only colours that stay readable on this background are offered.', style: context.mwb.text.caption),
        const SizedBox(height: MwbSpace.md),
        _Label('Reference'),
        MwbSegmentedControl<ReferencePlacement>(
          options: ReferencePlacement.values,
          value: d.effectivePlacement,
          labelOf: (p) => '${p.label} the verse',
          onChanged: (p) => _update(d.copyWith(referencePlacement: p)),
        ),
        if (multi) ...[
          const SizedBox(height: MwbSpace.sm),
          _Toggle(
            label: 'Verse numbers',
            value: d.showVerseNumbers,
            onChanged: (v) => _update(d.copyWith(showVerseNumbers: v)),
          ),
        ],
      ],
    );
  }

  Widget _personalPanel(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final d = _design;
    if (d.template.isClassic) return _classicNote(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('A word of encouragement (optional)'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final care in CareIntent.values)
              _Chip(
                key: Key('studio.care.${care.name}'),
                label: care.label,
                selected: _care == care,
                onTap: () {
                  final next = _care == care ? null : care;
                  setState(() => _care = next);
                  _message.text = next?.suggestion ?? '';
                  _update(d.copyWith(message: _message.text, clearMessage: next == null));
                },
              ),
          ],
        ),
        const SizedBox(height: MwbSpace.sm),
        TextField(
          key: const Key('studio.message'),
          controller: _message,
          maxLength: 160,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Write a short note to show on the card'),
          onChanged: (v) => _update(d.copyWith(message: v, clearMessage: v.trim().isEmpty)),
        ),
        Text(
          'Your note is printed on the image, so anyone who sees the card will read it. Keep private words '
          'for “Send to someone”.',
          style: t.caption,
        ),
        const SizedBox(height: MwbSpace.md),
        _Toggle(
          key: const Key('studio.sender'),
          label: _myName.isEmpty ? 'Show my name' : 'Show “Shared by $_myName”',
          value: d.trimmedSender != null,
          onChanged: _myName.isEmpty
              ? null
              : (v) => _update(v ? d.copyWith(senderName: _myName) : d.copyWith(clearSender: true)),
        ),
        _Toggle(
          key: const Key('studio.branding'),
          label: 'Small “My Word Bible” line',
          value: d.branding,
          onChanged: (v) => _update(d.copyWith(branding: v)),
        ),
        const SizedBox(height: MwbSpace.xs),
        Container(
          padding: const EdgeInsets.all(MwbSpace.sm),
          decoration: BoxDecoration(color: c.selected, borderRadius: MwbRadius.mdAll),
          child: Text(
            'Scripture can comfort, but it is not a substitute for being there. If someone is going through '
            'a hard time, a call or a visit may mean even more.',
            style: t.caption.copyWith(color: c.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _savePanel(BuildContext context) {
    final t = context.mwb.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('File type'),
        MwbSegmentedControl<CardFileType>(
          options: CardFileType.values,
          value: _type,
          labelOf: (f) => f.label,
          onChanged: (f) => setState(() => _type = f),
        ),
        const SizedBox(height: 4),
        Text(_type.description, style: t.caption),
        if (_type == CardFileType.jpg) ...[
          const SizedBox(height: MwbSpace.sm),
          Row(
            children: [
              Text('Quality', style: t.label),
              Expanded(
                child: Slider(
                  key: const Key('studio.quality'),
                  value: _quality.toDouble(),
                  min: 60,
                  max: 100,
                  divisions: 8,
                  label: '$_quality',
                  onChanged: (v) => setState(() => _quality = v.round()),
                ),
              ),
              SizedBox(width: 36, child: Text('$_quality', style: t.label)),
            ],
          ),
        ],
        const SizedBox(height: MwbSpace.sm),
        _Toggle(
          key: const Key('studio.caption'),
          label: 'Send the verse text with the image',
          value: _withCaption,
          onChanged: (v) => setState(() => _withCaption = v),
        ),
        Text(
          'WhatsApp and Telegram keep the text. Instagram and Facebook do not, so it is copied for you to paste.',
          style: t.caption,
        ),
        const SizedBox(height: MwbSpace.md),
        MwbSecondaryButton(
          key: const Key('studio.saveGallery'),
          label: 'Save to Photos',
          icon: Icons.photo_library_outlined,
          onPressed: _pages == null || _busy ? null : _save,
        ),
        const SizedBox(height: MwbSpace.xs),
        MwbSecondaryButton(
          key: const Key('studio.saveAs'),
          label: 'Save to a folder…',
          icon: Icons.folder_open_outlined,
          onPressed: _pages == null || _busy ? null : () => _save(chooseLocation: true),
        ),
        const SizedBox(height: MwbSpace.xs),
        MwbSecondaryButton(
          key: const Key('studio.copyText'),
          label: 'Copy verse text',
          icon: Icons.copy_rounded,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: sharePayloadFor(widget.scripture).text));
            if (context.mounted) showMwbSnack(context, 'Verse text copied');
          },
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Small building blocks
// -----------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(MwbSpace.gutter, 0, MwbSpace.gutter, MwbSpace.xs),
    child: Text(text.toUpperCase(), style: context.mwb.text.overline.copyWith(color: context.mwb.colors.textSecondary)),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: MwbSpace.xs),
    child: Text(text, style: context.mwb.text.label.copyWith(fontWeight: FontWeight.w600)),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      labelStyle: t.label.copyWith(color: selected ? c.primaryStrong : c.textPrimary, fontWeight: FontWeight.w600),
      selectedColor: c.selected,
      backgroundColor: c.surfaceElevated,
      side: BorderSide(color: selected ? c.primary.withValues(alpha: 0.5) : c.border),
      shape: const StadiumBorder(),
      onSelected: (_) => onTap(),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({super.key, required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    dense: true,
    title: Text(label, style: context.mwb.text.body),
    value: value,
    onChanged: onChanged,
  );
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.template, required this.selected, required this.onTap});
  final CardTemplate template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final cw = template.isClassic ? null : template.colorways.first;
    final bg = cw?.background ?? [c.background, c.surface];
    final ink = cw?.ink ?? c.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      label: '${template.label} design',
      child: InkWell(
        key: Key('studio.template.${template.id}'),
        borderRadius: MwbRadius.mdAll,
        onTap: onTap,
        child: SizedBox(
          width: 84,
          child: Column(
            children: [
              AnimatedContainer(
                duration: MwbMotion.fast,
                width: 84,
                height: 98,
                decoration: BoxDecoration(
                  borderRadius: MwbRadius.mdAll,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: bg.length == 1 ? [bg.first, bg.first] : bg,
                  ),
                  border: Border.all(color: selected ? c.primary : c.border, width: selected ? 2.5 : 1),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Aa',
                  style: TextStyle(
                    fontFamily: template.defaultFont.family,
                    fontWeight: template.defaultFont.weight,
                    fontSize: 26,
                    color: ink,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                template.label,
                style: t.caption.copyWith(
                  color: selected ? c.primaryStrong : c.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({super.key, required this.colors, required this.label, required this.selected, required this.onTap});
  final List<Color> colors;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label background',
      child: InkWell(
        borderRadius: BorderRadius.circular(MwbRadius.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MwbRadius.pill),
            border: Border.all(color: selected ? c.primary : c.border, width: selected ? 2 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: colors.length == 1 ? [colors.first, colors.first] : colors),
                  border: Border.all(color: c.border),
                ),
              ),
              const SizedBox(width: 8),
              Text(label, style: context.mwb.text.label),
            ],
          ),
        ),
      ),
    );
  }
}

class _InkDot extends StatelessWidget {
  const _InkDot({super.key, required this.color, required this.selected, required this.onTap});
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Text colour',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: selected ? c.primary : Colors.transparent, width: 2),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: c.border),
            ),
          ),
        ),
      ),
    );
  }
}
