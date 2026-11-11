import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/content.dart';
import '../../content/widgets/content_artwork.dart';
import '../application/video_playback_controller.dart';

/// Inline 16:9 video player with play/pause, seekable progress, duration and
/// a full-screen control.
class VideoPlayerView extends StatelessWidget {
  const VideoPlayerView({super.key, required this.item, required this.controller, this.fullscreen = false});

  final ContentItem item;
  final VideoPlaybackController controller;
  final bool fullscreen;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final playing = controller.isPlaying;
        return ClipRRect(
          borderRadius: fullscreen ? BorderRadius.zero : MwbRadius.lgAll,
          child: ColoredBox(
            color: Colors.black,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Poster artwork stands in for decoded frames in preview mode.
                  Opacity(
                    opacity: 0.85,
                    child: ContentArtworkView(
                      item: item,
                      aspectRatio: 16 / 9,
                      radius: 0,
                      showTypeBadge: false,
                      showDuration: false,
                      showIcon: false,
                    ),
                  ),
                  if (controller.isSimulated)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          'PREVIEW · NO VIDEO MEDIA',
                          style: context.mwb.text.caption.copyWith(
                            color: Colors.white,
                            fontSize: 10,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  Center(
                    child: Semantics(
                      button: true,
                      label: playing ? 'Pause video' : 'Play video',
                      excludeSemantics: true,
                      child: Material(
                        key: const Key('video.playPause'),
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.6))),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            controller.toggle();
                          },
                          child: SizedBox(
                            width: 60,
                            height: 60,
                            child: Icon(
                              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(color: Color(0x99000000)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            Text(
                              formatDuration(controller.position),
                              style: context.mwb.text.caption.copyWith(color: Colors.white),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: c.accent,
                                  thumbColor: Colors.white,
                                  inactiveTrackColor: Colors.white24,
                                ),
                                child: Semantics(
                                  label: 'Video position',
                                  child: Slider(
                                    key: const Key('video.progress'),
                                    value: controller.position.inMilliseconds
                                        .clamp(0, controller.duration.inMilliseconds)
                                        .toDouble(),
                                    max: controller.duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                                    onChanged: (v) => controller.seek(Duration(milliseconds: v.round())),
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              formatDuration(controller.duration),
                              style: context.mwb.text.caption.copyWith(color: Colors.white),
                            ),
                            IconButton(
                              key: const Key('video.fullscreen'),
                              tooltip: fullscreen ? 'Exit full screen' : 'Full screen',
                              color: Colors.white,
                              icon: Icon(fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded),
                              onPressed: () => fullscreen
                                  ? Navigator.of(context).maybePop()
                                  : Navigator.of(context, rootNavigator: true).push(
                                      MaterialPageRoute<void>(
                                        fullscreenDialog: true,
                                        builder: (_) => VideoFullscreenPage(item: item, controller: controller),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Landscape, immersive full-screen playback sharing the inline controller.
class VideoFullscreenPage extends StatefulWidget {
  const VideoFullscreenPage({super.key, required this.item, required this.controller});

  final ContentItem item;
  final VideoPlaybackController controller;

  @override
  State<VideoFullscreenPage> createState() => _VideoFullscreenPageState();
}

class _VideoFullscreenPageState extends State<VideoFullscreenPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: VideoPlayerView(item: widget.item, controller: widget.controller, fullscreen: true),
      ),
    );
  }
}
