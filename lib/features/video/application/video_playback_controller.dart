import 'dart:async';

import 'package:flutter/foundation.dart';

/// Playback boundary for video. A `video_player`-backed implementation will
/// be added once licensed, hosted video media exists (MWB media service).
abstract class VideoPlaybackController extends ChangeNotifier {
  Duration get duration;
  Duration get position;
  bool get isPlaying;

  /// True when no real video is decoded (Foundation V1 preview mode).
  bool get isSimulated;

  void play();
  void pause();
  void seek(Duration position);

  void toggle() => isPlaying ? pause() : play();
}

/// Advances a playhead over the item's listed duration so the player
/// interface (play/pause, seek, progress, full screen) can be exercised.
/// The UI states clearly that no video media is bundled.
class SimulatedVideoPlaybackController extends VideoPlaybackController {
  // ignore: prefer_initializing_formals
  SimulatedVideoPlaybackController({required Duration duration}) : _duration = duration;

  final Duration _duration;
  Duration _position = Duration.zero;
  Timer? _timer;
  bool _disposed = false;

  @override
  Duration get duration => _duration;

  @override
  Duration get position => _position;

  @override
  bool get isPlaying => _timer?.isActive ?? false;

  @override
  bool get isSimulated => true;

  @override
  void play() {
    if (isPlaying) return;
    if (_position >= _duration) _position = Duration.zero;
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _position += const Duration(milliseconds: 250);
      if (_position >= _duration) {
        _position = _duration;
        _timer?.cancel();
      }
      _notify();
    });
    _notify();
  }

  @override
  void pause() {
    _timer?.cancel();
    _notify();
  }

  @override
  void seek(Duration position) {
    final ms = position.inMilliseconds.clamp(0, _duration.inMilliseconds);
    _position = Duration(milliseconds: ms);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
