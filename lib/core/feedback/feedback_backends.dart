import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../logging/app_logger.dart';

/// The sound output the feedback layer drives (Phase 12).
///
/// An interface so the feedback controller can be unit-tested with a fake:
/// no test should need a platform audio stack to prove cue gating.
abstract interface class SoundBackend {
  /// Plays one short effect asset at [volume] (0.0–1.0).
  Future<void> playEffect(String asset, double volume);

  /// Starts the looping background music at [volume] (0.0–1.0).
  Future<void> startMusic(String asset, double volume);

  /// Stops the background music.
  Future<void> stopMusic();

  /// Adjusts the playing music's volume (0.0–1.0).
  Future<void> setMusicVolume(double volume);

  /// Releases the underlying players.
  void dispose();
}

/// The haptic output the feedback layer drives (Phase 12).
///
/// Flutter's built-in [HapticFeedback] covers everything `design.md` §25
/// asks for, so per `rules.md` §3.3 this backend adds no package — it is
/// an interface only so tests can substitute a fake.
abstract interface class HapticsBackend {
  void light();
  void medium();
  void heavy();
  void selection();
}

/// [SoundBackend] on `audioplayers` (vetted in `memory.md` §13t:
/// maintained, and compatible with Android, iOS and Web — the three
/// platforms this project ships).
///
/// Two players: one low-latency player for effects (rapid cues must not
/// queue behind each other) and one looping player for music. Every call
/// is failure-tolerant: audio is feedback, never a reason to crash or
/// block the game — on the web, for example, a browser may refuse
/// playback before the first user gesture, and that refusal is logged,
/// not surfaced.
class AudioplayersSoundBackend implements SoundBackend {
  AudioplayersSoundBackend() : _effects = AudioPlayer(), _music = AudioPlayer();

  static const AppLogger _log = AppLogger('feedback.audio');

  final AudioPlayer _effects;
  final AudioPlayer _music;
  bool _effectsConfigured = false;
  bool _musicPlaying = false;

  Future<void> _guard(Future<void> Function() call) async {
    try {
      await call();
    } catch (error) {
      _log.error('audio call failed: ${error.runtimeType}');
    }
  }

  @override
  Future<void> playEffect(String asset, double volume) => _guard(() async {
    if (!_effectsConfigured) {
      _effectsConfigured = true;
      await _effects.setPlayerMode(PlayerMode.lowLatency);
    }
    await _effects.stop();
    await _effects.play(AssetSource(asset), volume: volume);
  });

  @override
  Future<void> startMusic(String asset, double volume) => _guard(() async {
    await _music.setReleaseMode(ReleaseMode.loop);
    await _music.play(AssetSource(asset), volume: volume);
    _musicPlaying = true;
  });

  @override
  Future<void> stopMusic() => _guard(() async {
    if (!_musicPlaying) return;
    _musicPlaying = false;
    await _music.stop();
  });

  @override
  Future<void> setMusicVolume(double volume) => _guard(() async {
    if (!_musicPlaying) return;
    await _music.setVolume(volume);
  });

  @override
  void dispose() {
    unawaited(_effects.dispose());
    unawaited(_music.dispose());
  }
}

/// [HapticsBackend] on Flutter's built-in [HapticFeedback] — no package
/// (`rules.md` §3.3: do not add packages for problems Flutter solves).
class PlatformHapticsBackend implements HapticsBackend {
  const PlatformHapticsBackend();

  @override
  void light() => unawaited(HapticFeedback.lightImpact());

  @override
  void medium() => unawaited(HapticFeedback.mediumImpact());

  @override
  void heavy() => unawaited(HapticFeedback.heavyImpact());

  @override
  void selection() => unawaited(HapticFeedback.selectionClick());
}
