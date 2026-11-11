import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../data/models/content.dart';
import 'audio_playback_service.dart';

/// App-wide audio state. A single player is shared so playback continues
/// across screens and is reflected in the mini player.
final audioControllerProvider = NotifierProvider<AudioController, AudioPlaybackState>(AudioController.new);

class AudioController extends Notifier<AudioPlaybackState> {
  StreamSubscription<AudioPlaybackState>? _sub;

  AudioPlaybackService get _service => ref.read(audioPlaybackServiceProvider);

  static const speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  AudioPlaybackState build() {
    final service = ref.watch(audioPlaybackServiceProvider);
    _sub?.cancel();
    _sub = service.states.listen((s) => state = s);
    ref.onDispose(() => _sub?.cancel());
    return service.current;
  }

  bool isCurrent(ContentItem item) => state.item?.id == item.id;

  Future<void> toggle(ContentItem item) async {
    if (!isCurrent(item)) {
      await _service.load(item);
      if (_service.current.error != null) return;
      await _service.play();
      return;
    }
    state.playing ? await _service.pause() : await _service.play();
  }

  Future<void> pause() => _service.pause();

  Future<void> seek(Duration position) => _service.seek(position);

  Future<void> skip(Duration delta) {
    final duration = state.duration ?? Duration.zero;
    var target = state.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > duration) target = duration;
    return _service.seek(target);
  }

  Future<void> setSpeed(double speed) => _service.setSpeed(speed);

  Future<void> stop() => _service.stop();
}
