import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/core/feedback/feedback_backends.dart';
import 'package:wallforge/core/feedback/feedback_controller.dart';
import 'package:wallforge/core/feedback/feedback_timing.dart';
import 'package:wallforge/domain/repositories/app_settings.dart';

/// Records every sound call as (method, asset, volume).
class FakeSoundBackend implements SoundBackend {
  final List<(String, String?, double?)> calls = [];

  List<String?> get effects =>
      calls.where((c) => c.$1 == 'effect').map((c) => c.$2).toList();

  int countOf(String method) => calls.where((c) => c.$1 == method).length;

  @override
  Future<void> playEffect(String asset, double volume) async {
    calls.add(('effect', asset, volume));
  }

  @override
  Future<void> startMusic(String asset, double volume) async {
    calls.add(('startMusic', asset, volume));
  }

  @override
  Future<void> stopMusic() async {
    calls.add(('stopMusic', null, null));
  }

  @override
  Future<void> setMusicVolume(double volume) async {
    calls.add(('musicVolume', null, volume));
  }

  @override
  void dispose() {}
}

/// Records every haptic by name.
class FakeHapticsBackend implements HapticsBackend {
  final List<String> calls = [];

  @override
  void light() => calls.add('light');

  @override
  void medium() => calls.add('medium');

  @override
  void heavy() => calls.add('heavy');

  @override
  void selection() => calls.add('selection');
}

void main() {
  late FakeSoundBackend sound;
  late FakeHapticsBackend haptics;

  FeedbackController controller([AppSettings settings = AppSettings.defaults]) {
    sound = FakeSoundBackend();
    haptics = FakeHapticsBackend();
    return FeedbackController(sound, haptics, settings);
  }

  group('cue mapping (design.md §25)', () {
    test('each cue fires its sound and haptic exactly once', () {
      final c = controller();
      c.onMove();
      c.onWallPlaced();
      c.onInvalidAction();
      c.onTurnChanged();
      c.onVictory();
      c.onButtonPress();

      expect(sound.effects, [
        FeedbackAssets.move,
        FeedbackAssets.wallPlaced,
        FeedbackAssets.invalidAction,
        FeedbackAssets.turnChange,
        FeedbackAssets.victory,
        FeedbackAssets.buttonPress,
      ]);
      // Turn change deliberately has no haptic (recorded decision):
      // five haptics for six cues.
      expect(haptics.calls, [
        'light', // move
        'medium', // wall
        'heavy', // invalid
        'medium', // victory
        'selection', // button
      ]);
    });

    test('effects are scaled by the persisted volume', () {
      final c = controller(const AppSettings(volume: 0.3));
      c.onMove();
      expect(sound.calls.single.$3, 0.3);
    });
  });

  group('gating (design.md §23)', () {
    test('effects off silences sounds but not haptics', () {
      final c = controller(const AppSettings(effectsEnabled: false));
      c.onMove();
      c.onVictory();
      expect(sound.effects, isEmpty);
      expect(haptics.calls, ['light', 'medium']);
    });

    test('haptics off silences haptics but not sounds', () {
      final c = controller(const AppSettings(hapticsEnabled: false));
      c.onMove();
      c.onWallPlaced();
      expect(sound.effects, hasLength(2));
      expect(haptics.calls, isEmpty);
    });

    test('reduced motion suppresses haptics but never sound (§25)', () {
      final c = controller(const AppSettings(reducedMotion: true));
      c.onMove();
      c.onInvalidAction();
      expect(sound.effects, hasLength(2));
      expect(haptics.calls, isEmpty);
    });
  });

  group('music lifecycle', () {
    test('applySettings starts music when enabled, once', () {
      final c = controller(const AppSettings(musicEnabled: false));
      c.applySettings(const AppSettings(musicEnabled: true, volume: 0.4));
      c.applySettings(const AppSettings(musicEnabled: true, volume: 0.4));
      expect(sound.countOf('startMusic'), 1);
      expect(
        sound.calls.firstWhere((x) => x.$1 == 'startMusic').$2,
        FeedbackAssets.music,
      );
      expect(sound.calls.firstWhere((x) => x.$1 == 'startMusic').$3, 0.4);
    });

    test('applySettings stops music when disabled', () {
      final c = controller();
      c.startMusicIfEnabled();
      expect(sound.countOf('startMusic'), 1);
      c.applySettings(const AppSettings(musicEnabled: false));
      expect(sound.countOf('stopMusic'), 1);
    });

    test(
      'startMusicIfEnabled respects the toggle and does not double-start',
      () {
        final off = controller(const AppSettings(musicEnabled: false));
        off.startMusicIfEnabled();
        expect(sound.countOf('startMusic'), 0);

        final on = controller();
        on.startMusicIfEnabled();
        on.startMusicIfEnabled();
        expect(sound.countOf('startMusic'), 1);
      },
    );

    test('a volume change reaches the playing music', () {
      final c = controller();
      c.startMusicIfEnabled();
      c.applySettings(const AppSettings(volume: 0.9));
      expect(sound.countOf('musicVolume'), 1);
      expect(sound.calls.firstWhere((x) => x.$1 == 'musicVolume').$3, 0.9);
    });
  });

  group('AppSettings Phase 12 fields', () {
    test('defaults: audio and haptics on, volume 0.5, reduced motion off', () {
      const s = AppSettings.defaults;
      expect(s.musicEnabled, isTrue);
      expect(s.effectsEnabled, isTrue);
      expect(s.volume, 0.5);
      expect(s.hapticsEnabled, isTrue);
      expect(s.reducedMotion, isFalse);
    });

    test('the new fields round-trip through JSON', () {
      const s = AppSettings(
        musicEnabled: false,
        effectsEnabled: false,
        volume: 0.25,
        hapticsEnabled: false,
        reducedMotion: true,
      );
      expect(AppSettings.fromJson(s.toJson()), s);
    });

    test('an out-of-range stored volume is clamped, never trusted', () {
      expect(AppSettings.fromJson({'volume': 1.7}).volume, 1.0);
      expect(AppSettings.fromJson({'volume': -0.2}).volume, 0.0);
    });

    test('wrong-typed stored values fall back to defaults', () {
      final s = AppSettings.fromJson({
        'musicEnabled': 'yes',
        'effectsEnabled': 1,
        'volume': 'loud',
        'hapticsEnabled': null,
        'reducedMotion': 'no',
      });
      expect(s, AppSettings.defaults);
    });

    test('a pre-Phase-12 store (no new keys) loads with the defaults', () {
      final s = AppSettings.fromJson({
        'confirmWallPlacement': false,
        'aiDifficulty': 'hard',
        'tutorialCompleted': true,
        'movementAssistance': true,
      });
      expect(s.musicEnabled, isTrue);
      expect(s.volume, 0.5);
      expect(s.confirmWallPlacement, isFalse);
    });
  });
}
