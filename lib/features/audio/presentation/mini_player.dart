import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../discovery/application/content_providers.dart';
import '../application/audio_controller.dart';

/// Persistent mini player shown above the tab bar while audio is loaded.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioControllerProvider);
    final item = state.item;
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final creator = item == null ? null : ref.watch(creatorMapProvider).value?[item.creatorId];
    final progress = (state.duration == null || state.duration!.inMilliseconds == 0)
        ? 0.0
        : (state.position.inMilliseconds / state.duration!.inMilliseconds).clamp(0.0, 1.0);

    return AnimatedSize(
      duration: MwbMotion.medium,
      curve: MwbMotion.curve,
      child: item == null
          ? const SizedBox(width: double.infinity)
          : Material(
              color: c.surfaceElevated,
              child: InkWell(
                onTap: () => context.push(AppRoutes.content(item.id)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: progress, minHeight: 2),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(MwbSpace.md, 4, 4, 4),
                      child: Row(
                        children: [
                          Icon(Icons.graphic_eq_rounded, color: c.primary, size: 20),
                          const SizedBox(width: MwbSpace.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.title,
                                  style: t.label.copyWith(fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (creator != null)
                                  Text(
                                    creator.displayName,
                                    style: t.caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          MwbIconButton(
                            icon: state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            tooltip: state.playing ? 'Pause' : 'Play',
                            onPressed: () => ref.read(audioControllerProvider.notifier).toggle(item),
                          ),
                          MwbIconButton(
                            icon: Icons.close_rounded,
                            tooltip: 'Close player',
                            onPressed: () => ref.read(audioControllerProvider.notifier).stop(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
