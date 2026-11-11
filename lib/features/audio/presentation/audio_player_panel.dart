import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/notices.dart';
import '../../../core/widgets/sheets.dart';
import '../../../data/models/content.dart';
import '../application/audio_controller.dart';

/// Full audio player: play/pause, skip, seekable progress, duration and
/// playback speed.
class AudioPlayerPanel extends ConsumerWidget {
  const AudioPlayerPanel({super.key, required this.item});

  final ContentItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final state = ref.watch(audioControllerProvider);
    final ctrl = ref.read(audioControllerProvider.notifier);
    final current = state.item?.id == item.id;
    final playing = current && state.playing;
    final loading = current && state.loading;
    final position = current ? state.position : Duration.zero;
    final duration = current ? (state.duration ?? Duration.zero) : Duration.zero;
    final maxMs = duration.inMilliseconds <= 0 ? 1.0 : duration.inMilliseconds.toDouble();
    final value = position.inMilliseconds.clamp(0, maxMs).toDouble();
    final error = current ? state.error : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(MwbSpace.md, MwbSpace.md, MwbSpace.md, MwbSpace.sm),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: MwbRadius.lgAll,
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Semantics(
            label: 'Playback position',
            value: '${formatDuration(position)} of ${formatDuration(duration)}',
            child: Slider(
              key: const Key('audio.progress'),
              value: value,
              max: maxMs,
              onChanged: current && duration > Duration.zero
                  ? (v) => ctrl.seek(Duration(milliseconds: v.round()))
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MwbSpace.sm),
            child: Row(
              children: [
                Text(formatDuration(position), style: t.caption),
                const Spacer(),
                Text(current ? formatDuration(duration) : '--:--', style: t.caption),
              ],
            ),
          ),
          const SizedBox(height: MwbSpace.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SpeedButton(speed: current ? state.speed : 1.0, enabled: current, onSelected: ctrl.setSpeed),
              const Spacer(),
              IconButton(
                tooltip: 'Back 15 seconds',
                iconSize: 28,
                onPressed: current ? () => ctrl.skip(const Duration(seconds: -15)) : null,
                icon: const Icon(Icons.replay_10_rounded),
              ),
              const SizedBox(width: MwbSpace.sm),
              Semantics(
                button: true,
                label: playing ? 'Pause' : 'Play',
                excludeSemantics: true,
                child: Material(
                  key: const Key('audio.playPause'),
                  color: c.primaryStrong,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ctrl.toggle(item);
                    },
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: Center(
                        child: loading
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2, color: c.onPrimary),
                              )
                            : AnimatedSwitcher(
                                duration: MwbMotion.fast,
                                transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                                child: Icon(
                                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  key: ValueKey(playing),
                                  color: c.onPrimary,
                                  size: 34,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: MwbSpace.sm),
              IconButton(
                tooltip: 'Forward 15 seconds',
                iconSize: 28,
                onPressed: current ? () => ctrl.skip(const Duration(seconds: 15)) : null,
                icon: const Icon(Icons.forward_10_rounded),
              ),
              const Spacer(),
              const SizedBox(width: 56),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: MwbSpace.xs),
            Text(error, style: t.caption.copyWith(color: c.error)),
          ],
          if (item.media.isSampleStandIn) ...[
            const SizedBox(height: MwbSpace.sm),
            MwbNotice(
              icon: Icons.graphic_eq_rounded,
              message:
                  'Foundation V1 plays a short, original sample tone in place of this '
                  '${item.duration == null ? '' : '${formatMinutes(item.durationSeconds!)} '}message. '
                  'Creator recordings will stream once MWB media hosting launches.',
            ),
          ],
        ],
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.speed, required this.enabled, required this.onSelected});

  final double speed;
  final bool enabled;
  final ValueChanged<double> onSelected;

  String _label(double s) => '${s.toStringAsFixed(s.truncateToDouble() == s ? 0 : 2).replaceAll(RegExp(r'0$'), '')}×';

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    return SizedBox(
      width: 56,
      child: TextButton(
        key: const Key('audio.speed'),
        onPressed: !enabled
            ? null
            : () async {
                final chosen = await showMwbSheet<double>(
                  context,
                  title: 'Playback speed',
                  builder: (ctx) => Column(
                    children: [
                      for (final s in AudioController.speeds)
                        ListTile(
                          title: Text(_label(s)),
                          trailing: s == speed ? Icon(Icons.check_rounded, color: c.primary) : null,
                          onTap: () => Navigator.of(ctx).pop(s),
                        ),
                    ],
                  ),
                );
                if (chosen != null) onSelected(chosen);
              },
        style: TextButton.styleFrom(foregroundColor: c.textPrimary, minimumSize: const Size(48, 48)),
        child: Text(_label(speed), semanticsLabel: 'Playback speed ${_label(speed)}'),
      ),
    );
  }
}
