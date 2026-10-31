import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/match_clock.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Phase 16.5, Part C: the per-move countdown itself — expiry,
/// pause and resume, all against an injected manual clock.
void main() {
  late DateTime now;
  late List<PlayerId> fired;
  late MatchClock clock;

  setUp(() {
    now = DateTime.utc(2026, 10, 31, 12);
    fired = <PlayerId>[];
    clock = MatchClock(now: () => now, onTimeout: fired.add);
  });

  void advance(Duration d) => now = now.add(d);

  test('an idle clock reports nothing and never fires', () {
    expect(clock.isArmed, isFalse);
    expect(clock.remaining, isNull);
    advance(const Duration(minutes: 5));
    clock.tick();
    expect(fired, isEmpty);
  });

  test('remaining counts down from the full limit', () {
    clock.startTurn(PlayerId.blue, const Duration(seconds: 30));
    expect(clock.side, PlayerId.blue);
    expect(clock.remaining, const Duration(seconds: 30));
    advance(const Duration(seconds: 12));
    expect(clock.remaining, const Duration(seconds: 18));
  });

  test('expiry fires exactly once, for the side that was timed', () {
    clock.startTurn(PlayerId.red, const Duration(seconds: 15));
    advance(const Duration(seconds: 15));
    clock.tick();
    clock.tick();
    advance(const Duration(seconds: 30));
    clock.tick();
    expect(fired, [PlayerId.red]);
    // Remaining clamps at zero rather than going negative.
    expect(clock.remaining, Duration.zero);
  });

  test('a new turn re-arms and can fire again', () {
    clock.startTurn(PlayerId.blue, const Duration(seconds: 10));
    advance(const Duration(seconds: 10));
    clock.tick();
    clock.startTurn(PlayerId.red, const Duration(seconds: 10));
    expect(clock.remaining, const Duration(seconds: 10));
    advance(const Duration(seconds: 10));
    clock.tick();
    expect(fired, [PlayerId.blue, PlayerId.red]);
  });

  test('pause freezes the remainder; resume spends only the rest', () {
    clock.startTurn(PlayerId.blue, const Duration(seconds: 20));
    advance(const Duration(seconds: 8));
    clock.pause();
    expect(clock.isPaused, isTrue);
    expect(clock.remaining, const Duration(seconds: 12));
    // Wall-clock time passing during a pause changes nothing,
    // and a paused clock cannot fire.
    advance(const Duration(minutes: 10));
    clock.tick();
    expect(fired, isEmpty);
    expect(clock.remaining, const Duration(seconds: 12));
    clock.resume();
    advance(const Duration(seconds: 11));
    clock.tick();
    expect(fired, isEmpty);
    advance(const Duration(seconds: 1));
    clock.tick();
    expect(fired, [PlayerId.blue]);
  });

  test('stop disarms: no remainder, no fire', () {
    clock.startTurn(PlayerId.blue, const Duration(seconds: 5));
    clock.stop();
    expect(clock.isArmed, isFalse);
    expect(clock.remaining, isNull);
    advance(const Duration(seconds: 30));
    clock.tick();
    expect(fired, isEmpty);
  });
}
