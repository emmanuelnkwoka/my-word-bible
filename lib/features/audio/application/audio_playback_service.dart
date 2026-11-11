import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../../data/models/content.dart';

@immutable
class AudioPlaybackState {
  const AudioPlaybackState({
    this.item,
    this.playing = false,
    this.loading = false,
    this.position = Duration.zero,
    this.duration,
    this.speed = 1.0,
    this.error,
    this.completed = false,
  });

  final ContentItem? item;
  final bool playing;
  final bool loading;
  final Duration position;
  final Duration? duration;
  final double speed;
  final String? error;
  final bool completed;

  bool get hasItem => item != null;

  AudioPlaybackState copyWith({
    ContentItem? item,
    bool? playing,
    bool? loading,
    Duration? position,
    Duration? duration,
    double? speed,
    String? error,
    bool clearError = false,
    bool? completed,
  }) => AudioPlaybackState(
    item: item ?? this.item,
    playing: playing ?? this.playing,
    loading: loading ?? this.loading,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    speed: speed ?? this.speed,
    error: clearError ? null : (error ?? this.error),
    completed: completed ?? this.completed,
  );
}

/// Playback boundary for audio messages.
///
/// Background playback (lock-screen controls, notification) is added by
/// providing an implementation backed by `audio_service` /
/// `just_audio_background`; UI and state code depend only on this interface.
abstract interface class AudioPlaybackService {
  Stream<AudioPlaybackState> get states;
  AudioPlaybackState get current;

  Future<void> load(ContentItem item);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> stop();
  Future<void> dispose();
}

/// just_audio implementation. The underlying player is created lazily so
/// the app does not touch audio hardware until the user plays something.
class JustAudioPlaybackService implements AudioPlaybackService {
  AudioPlayer? _player;
  final _controller = StreamController<AudioPlaybackState>.broadcast();
  final _subs = <StreamSubscription<Object?>>[];
  AudioPlaybackState _state = const AudioPlaybackState();

  @override
  Stream<AudioPlaybackState> get states => _controller.stream;

  @override
  AudioPlaybackState get current => _state;

  void _emit(AudioPlaybackState s) {
    _state = s;
    if (!_controller.isClosed) _controller.add(s);
  }

  AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final p = AudioPlayer();
    _subs.addAll([
      p.playerStateStream.listen((ps) {
        final completed = ps.processingState == ProcessingState.completed;
        _emit(
          _state.copyWith(
            playing: ps.playing && !completed,
            loading: ps.processingState == ProcessingState.loading || ps.processingState == ProcessingState.buffering,
            completed: completed,
          ),
        );
        if (completed) {
          p.pause();
          p.seek(Duration.zero);
        }
      }),
      p.positionStream.listen((pos) => _emit(_state.copyWith(position: pos))),
      p.durationStream.listen((d) => _emit(_state.copyWith(duration: d))),
      p.speedStream.listen((s) => _emit(_state.copyWith(speed: s))),
    ]);
    return _player = p;
  }

  @override
  Future<void> load(ContentItem item) async {
    final uri = item.media.uri;
    if (!item.media.isPlayable || uri == null) {
      _emit(AudioPlaybackState(item: item, error: 'No audio is available for this item yet.'));
      return;
    }
    final p = _ensurePlayer();
    _emit(AudioPlaybackState(item: item, loading: true, speed: _state.speed));
    try {
      final duration = item.media.kind == MediaSourceKind.asset ? await p.setAsset(uri) : await p.setUrl(uri);
      _emit(_state.copyWith(item: item, loading: false, duration: duration, position: Duration.zero, clearError: true));
    } catch (_) {
      _emit(_state.copyWith(item: item, loading: false, error: 'This audio could not be played.'));
    }
  }

  @override
  Future<void> play() async {
    final p = _player;
    if (p == null) return;
    // just_audio's play() completes only when playback stops; do not await.
    unawaited(p.play());
  }

  @override
  Future<void> pause() async => _player?.pause();

  @override
  Future<void> seek(Duration position) async => _player?.seek(position);

  @override
  Future<void> setSpeed(double speed) async {
    await _player?.setSpeed(speed);
    _emit(_state.copyWith(speed: speed));
  }

  @override
  Future<void> stop() async {
    await _player?.stop();
    _emit(const AudioPlaybackState());
  }

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _player?.dispose();
    await _controller.close();
  }
}

/// Timer-driven playback for tests and environments without audio output.
class SimulatedAudioPlaybackService implements AudioPlaybackService {
  SimulatedAudioPlaybackService({this.mediaDuration = const Duration(seconds: 48)});

  final Duration mediaDuration;
  final _controller = StreamController<AudioPlaybackState>.broadcast();
  AudioPlaybackState _state = const AudioPlaybackState();
  Timer? _timer;

  @override
  Stream<AudioPlaybackState> get states => _controller.stream;

  @override
  AudioPlaybackState get current => _state;

  void _emit(AudioPlaybackState s) {
    _state = s;
    if (!_controller.isClosed) _controller.add(s);
  }

  @override
  Future<void> load(ContentItem item) async {
    _timer?.cancel();
    _emit(AudioPlaybackState(item: item, duration: mediaDuration, speed: _state.speed));
  }

  @override
  Future<void> play() async {
    if (!_state.hasItem) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final next = _state.position + Duration(milliseconds: (250 * _state.speed).round());
      if (next >= mediaDuration) {
        _timer?.cancel();
        _emit(_state.copyWith(position: Duration.zero, playing: false, completed: true));
      } else {
        _emit(_state.copyWith(position: next));
      }
    });
    _emit(_state.copyWith(playing: true, completed: false));
  }

  @override
  Future<void> pause() async {
    _timer?.cancel();
    _emit(_state.copyWith(playing: false));
  }

  @override
  Future<void> seek(Duration position) async => _emit(_state.copyWith(position: position));

  @override
  Future<void> setSpeed(double speed) async => _emit(_state.copyWith(speed: speed));

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _emit(const AudioPlaybackState());
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await _controller.close();
  }
}
