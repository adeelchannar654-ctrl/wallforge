import 'dart:math';

import '../../domain/repositories/room.dart';

/// Produces candidate room codes.
///
/// Behind an interface so a test can force collisions deterministically — the
/// collision path is the one worth testing and the one a random generator will
/// never produce on demand.
abstract interface class RoomCodeGenerator {
  /// Returns a candidate code. Not necessarily unique; the caller must check.
  String generate();
}

/// Cryptographically-seeded [RoomCodeGenerator] over [RoomCode.alphabet].
///
/// Uses [Random.secure] because a predictable room code is a room someone else
/// can walk into. The alphabet and length are the domain's, so the format stays
/// defined in one place.
class RandomRoomCodeGenerator implements RoomCodeGenerator {
  RandomRoomCodeGenerator({Random? random})
    : _random = random ?? Random.secure();

  final Random _random;

  @override
  String generate() {
    final buffer = StringBuffer();
    for (var i = 0; i < RoomCode.length; i++) {
      buffer.write(
        RoomCode.alphabet[_random.nextInt(RoomCode.alphabet.length)],
      );
    }
    return buffer.toString();
  }
}

/// A generator that returns a fixed sequence, then falls back to a real one.
///
/// Test-only: it makes both the collision-retry path and the
/// collision-exhaustion path reachable without waiting on randomness.
class ScriptedRoomCodeGenerator implements RoomCodeGenerator {
  ScriptedRoomCodeGenerator(List<String> codes, {RoomCodeGenerator? fallback})
    : _codes = List<String>.from(codes),
      _fallback = fallback ?? RandomRoomCodeGenerator();

  final List<String> _codes;
  final RoomCodeGenerator _fallback;
  int _index = 0;
  int _calls = 0;

  /// How many candidates have been handed out in total, scripted or fallback.
  ///
  /// The repository bounds its collision retries, so a test needs to see how many
  /// candidates were actually asked for.
  int get calls => _calls;

  @override
  String generate() {
    _calls++;
    if (_index < _codes.length) return _codes[_index++];
    return _fallback.generate();
  }
}
