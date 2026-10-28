import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/core/feedback/feedback_backends.dart';
import 'package:wallforge/core/feedback/feedback_controller.dart';
import 'package:wallforge/core/feedback/feedback_scope.dart';
import 'package:wallforge/data/local/in_memory_repositories.dart';
import 'package:wallforge/domain/repositories/auth.dart';
import 'package:wallforge/domain/repositories/repositories.dart';
import 'package:wallforge/presentation/screens/settings/settings_screen.dart';

class _FakeAuthGateway implements AuthGateway {
  AuthState state = const AuthState.signedIn('uid-test');

  @override
  Future<AuthState> signInAnonymously() async => state;

  @override
  Future<AuthState> current() async => state;

  @override
  Future<AuthState> signOut() async {
    state = const AuthState.signedOut();
    return state;
  }

  @override
  Stream<AuthState> authStateChanges() => const Stream.empty();

  @override
  Future<String?> currentUid() async => state.uid;
}

class _RecordingSound implements SoundBackend {
  int musicStarts = 0;
  int musicStops = 0;
  final List<double> musicVolumes = [];

  @override
  Future<void> playEffect(String asset, double volume) async {}

  @override
  Future<void> startMusic(String asset, double volume) async {
    musicStarts++;
  }

  @override
  Future<void> stopMusic() async {
    musicStops++;
  }

  @override
  Future<void> setMusicVolume(double volume) async {
    musicVolumes.add(volume);
  }

  @override
  void dispose() {}
}

class _SilentHaptics implements HapticsBackend {
  const _SilentHaptics();

  @override
  void light() {}

  @override
  void medium() {}

  @override
  void heavy() {}

  @override
  void selection() {}
}

void main() {
  late InMemorySettingsRepository settings;
  late _RecordingSound sound;
  late FeedbackController feedback;

  Future<void> pumpSettings(WidgetTester tester) async {
    settings = InMemorySettingsRepository();
    sound = _RecordingSound();
    feedback = FeedbackController(sound, const _SilentHaptics());
    await tester.pumpWidget(
      FeedbackScope(
        controller: feedback,
        child: MaterialApp(
          home: SettingsScreen(
            settingsRepository: settings,
            authGateway: _FakeAuthGateway(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder switchFor(String label) => find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
    matching: find.byType(Switch),
  );

  Future<void> toggle(WidgetTester tester, String label) async {
    final target = switchFor(label);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  group('Settings — Phase 12 controls are real', () {
    testWidgets('Music toggle persists and stops the live music', (
      tester,
    ) async {
      await pumpSettings(tester);
      feedback.startMusicIfEnabled();
      expect(sound.musicStarts, 1);

      await toggle(tester, 'Music');
      expect((await settings.load()).musicEnabled, isFalse);
      expect(sound.musicStops, 1, reason: 'the save reaches the live layer');
    });

    testWidgets('Sound effects and Haptics toggles persist', (tester) async {
      await pumpSettings(tester);
      await toggle(tester, 'Sound effects');
      expect((await settings.load()).effectsEnabled, isFalse);
      await toggle(tester, 'Haptic feedback');
      expect((await settings.load()).hapticsEnabled, isFalse);
    });

    testWidgets('Reduced motion persists and reaches the feedback layer', (
      tester,
    ) async {
      await pumpSettings(tester);
      expect(feedback.reducedMotionInApp, isFalse);
      await toggle(tester, 'Reduced motion');
      expect((await settings.load()).reducedMotion, isTrue);
      expect(feedback.reducedMotionInApp, isTrue);
    });

    testWidgets('the Volume slider persists where the drag ends', (
      tester,
    ) async {
      await pumpSettings(tester);
      // The Volume slider is the first of the two sliders on the screen
      // since Phase 13 added the UI scale slider.
      final slider = find.byType(Slider).first;
      await tester.ensureVisible(slider);
      await tester.drag(slider, const Offset(150, 0));
      await tester.pumpAndSettle();
      final saved = await settings.load();
      expect(saved.volume, greaterThan(0.5));
      expect(saved.volume, lessThanOrEqualTo(1.0));
    });

    testWidgets('Color assistance and High contrast are live toggles '
        'since Phase 13; UI scale is a live slider', (tester) async {
      await pumpSettings(tester);
      expect(find.textContaining('Not yet available'), findsNothing);
      for (final label in ['Color assistance', 'High contrast']) {
        final row = switchFor(label);
        final widget = tester.widget<Switch>(row);
        expect(widget.onChanged, isNotNull, reason: '$label must be live');
      }
      expect(find.text('UI scale'), findsOneWidget);
      expect(find.byType(Slider), findsNWidgets(2)); // Volume + UI scale
    });
  });
}
