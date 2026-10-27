import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/repositories/app_settings.dart';
import '../logging/app_logger.dart';
import 'feedback_backends.dart';
import 'feedback_timing.dart';

/// The single feedback/effects layer (Phase 12).
///
/// ## What it is
///
/// Every sound cue and haptic in `design.md` §25 is triggered through
/// here, by name, from the game controllers at the moment an action
/// actually succeeds or fails — never from widgets guessing at state
/// changes, and never duplicated per screen. The controller holds the
/// current [AppSettings] snapshot and applies the §23 gates:
///
/// * effects (move / wall / invalid / turn / victory / button) are gated
///   by `effectsEnabled` and scaled by `volume`;
/// * background music is gated by `musicEnabled` (independently, per
///   §23's grouping) and scaled by the same `volume`;
/// * haptics are gated by `hapticsEnabled` **and** suppressed while
///   reduced motion is active (`design.md` §25: haptics are "disabled
///   by reduced-motion/accessibility settings where appropriate");
/// * sound is *not* motion, so reduced motion never mutes it — it only
///   shortens/skips the visual animations, which the widgets resolve
///   through [FeedbackScope].
///
/// ## Cue → feedback mapping (decided and recorded, `memory.md` §13t)
///
/// | Cue | Sound | Haptic |
/// |---|---|---|
/// | move | `move.wav` | light impact |
/// | wall placed | `wall.wav` | medium impact |
/// | invalid action | `invalid.wav` | heavy impact |
/// | turn change | `turn.wav` | none — the turn returning is already |
/// | | | on screen; a buzz every turn would not be "subtle" (§25) |
/// | victory | `victory.wav` | medium impact |
/// | button press | `button.wav` | selection click |
///
/// ## Which events fire which cue (exactly once per event)
///
/// * The local player's own applied move/wall → move / wall cue. Own
///   actions in the online game fire when the verified snapshot adopts
///   them, not at submit time (a rejected submit must not sound like a
///   success — its `invalidAction` rejection fires the invalid cue).
/// * An opponent/AI action that returns the turn → turn-change cue
///   (not the move/wall cue: one event, one sound).
/// * A transition into the finished state → victory cue, in addition to
///   the winning action's own cue: the action and the match ending are
///   two events.
/// * A locally refused action (engine failure) → invalid cue.
/// * Catch-up snapshots that jump more than one ply fire no action cue:
///   no single action can be attributed.
class FeedbackController extends ChangeNotifier {
  FeedbackController(
    this._sound,
    this._haptics, [
    this._settings = AppSettings.defaults,
  ]);

  static const AppLogger _log = AppLogger('feedback');

  final SoundBackend _sound;
  final HapticsBackend _haptics;
  AppSettings _settings;
  bool _musicWanted = false;
  bool _disposed = false;

  /// The settings snapshot cues are gated by.
  AppSettings get settings => _settings;

  /// Whether the in-app reduced-motion toggle is on. Widgets combine
  /// this with the platform signal — see [FeedbackScope].
  bool get reducedMotionInApp => _settings.reducedMotion;

  /// Applies a new settings snapshot (startup load, or a Settings save)
  /// and reconciles the music with it: music starts when it becomes
  /// enabled, stops when it is disabled, and follows volume changes.
  void applySettings(AppSettings next) {
    final previous = _settings;
    _settings = next;
    if (next.musicEnabled && !_musicWanted) {
      _musicWanted = true;
      unawaited(_sound.startMusic(FeedbackAssets.music, next.volume));
    } else if (!next.musicEnabled && _musicWanted) {
      _musicWanted = false;
      unawaited(_sound.stopMusic());
    } else if (_musicWanted && next.volume != previous.volume) {
      unawaited(_sound.setMusicVolume(next.volume));
    }
    notifyListeners();
  }

  /// Starts the background music if the settings allow it. Called once
  /// the app has loaded its persisted settings.
  void startMusicIfEnabled() {
    if (!_settings.musicEnabled || _musicWanted) return;
    _musicWanted = true;
    unawaited(_sound.startMusic(FeedbackAssets.music, _settings.volume));
  }

  // --- Cues ---------------------------------------------------------------

  /// A pawn move was applied.
  void onMove() {
    _effect(FeedbackAssets.move);
    _haptic(_haptics.light);
  }

  /// A wall was placed.
  void onWallPlaced() {
    _effect(FeedbackAssets.wallPlaced);
    _haptic(_haptics.medium);
  }

  /// An action was refused.
  void onInvalidAction() {
    _effect(FeedbackAssets.invalidAction);
    _haptic(_haptics.heavy);
  }

  /// The turn returned to the local viewer (opponent/AI acted).
  void onTurnChanged() {
    _effect(FeedbackAssets.turnChange);
  }

  /// The match reached its finished state.
  void onVictory() {
    _effect(FeedbackAssets.victory);
    _haptic(_haptics.medium);
  }

  /// A primary/secondary app button was pressed.
  void onButtonPress() {
    _effect(FeedbackAssets.buttonPress);
    _haptic(_haptics.selection);
  }

  void _effect(String asset) {
    if (!_settings.effectsEnabled) return;
    unawaited(_sound.playEffect(asset, _settings.volume));
  }

  void _haptic(void Function() fire) {
    if (!_settings.hapticsEnabled) return;
    if (_settings.reducedMotion) return; // §25: reduced motion disables.
    fire();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _log.log('feedback disposed');
    _sound.dispose();
    super.dispose();
  }
}

/// The app-wide feedback holder.
///
/// The app has exactly one [FeedbackController], created by the root
/// widget with the platform backends. Static access exists for the two
/// places that cannot reach an inherited widget: the router (it builds
/// routes outside a `BuildContext` it owns) and the game controllers
/// (assigned once by the screens/router that create them). Widgets must
/// prefer [FeedbackScope]; tests substitute their own controller here or
/// through the scope.
abstract final class FeedbackService {
  static FeedbackController? _shared;

  /// The shared controller, or null before the app root creates it
  /// (and in tests that never install one — cues then simply don't fire).
  static FeedbackController? get shared => _shared;

  /// Installs [controller] as the shared instance. Called once by the
  /// app root; tests may replace it and restore null afterwards.
  static void install(FeedbackController? controller) {
    _shared = controller;
  }
}
