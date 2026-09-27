import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/data/remote/room_code_generator.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

void main() {
  group('RoomCode format', () {
    test('is six characters from the documented alphabet', () {
      expect(RoomCode.length, 6);
      expect(RoomCode.alphabet.length, 32);
      // The alphabet deliberately omits the visually ambiguous symbols.
      expect(RoomCode.alphabet, isNot(contains('0')));
      expect(RoomCode.alphabet, isNot(contains('O')));
      expect(RoomCode.alphabet, isNot(contains('1')));
      expect(RoomCode.alphabet, isNot(contains('I')));
      // Sanity: nothing lowercase, so codes are unambiguous when read aloud.
      expect(RoomCode.alphabet, RoomCode.alphabet.toUpperCase());
    });

    test('accepts a well-formed code', () {
      final code = RoomCode.tryParse('AB39HK');
      expect(code, isNotNull);
      expect(code!.value, 'AB39HK');
      expect(RoomCode.isValid('AB39HK'), isTrue);
    });

    test('is case-insensitive, because a code is read aloud', () {
      expect(RoomCode.tryParse('ab39hk')!.value, 'AB39HK');
      expect(RoomCode.tryParse('Ab39hK')!.value, 'AB39HK');
    });

    test('ignores separators and surrounding whitespace', () {
      expect(RoomCode.tryParse('  ab3-9hk  ')!.value, 'AB39HK');
      expect(RoomCode.tryParse('AB 39 HK')!.value, 'AB39HK');
    });

    test('rejects the wrong length', () {
      expect(RoomCode.tryParse('AB39HK7'), isNull);
      expect(RoomCode.tryParse('AB39H'), isNull);
      expect(RoomCode.tryParse(''), isNull);
    });

    test('rejects symbols outside the alphabet', () {
      // 0/O/1/I are not in the alphabet, so a code containing them is not a code
      // this app could ever have issued.
      expect(RoomCode.tryParse('AB390K'), isNull);
      expect(RoomCode.tryParse('ABO9HK'), isNull);
    });

    test('equality and hashing are by value', () {
      expect(const RoomCode.valid('AB39HK'), RoomCode.tryParse('ab39hk'));
      expect(
        const RoomCode.valid('AB39HK').hashCode,
        RoomCode.tryParse('ab39hk')!.hashCode,
      );
      expect(
        const RoomCode.valid('AB39HK'),
        isNot(const RoomCode.valid('ZZ99ZZ')),
      );
    });

    test('toString yields the bare code, so it can be logged and copied', () {
      expect(RoomCode.tryParse('ab39hk')!.toString(), 'AB39HK');
    });
  });

  group('RandomRoomCodeGenerator', () {
    test('only ever produces valid codes', () {
      final generator = RandomRoomCodeGenerator();
      for (var i = 0; i < 200; i++) {
        final code = generator.generate();
        expect(code.length, RoomCode.length);
        expect(
          RoomCode.isValid(code),
          isTrue,
          reason: 'generated "$code" which is not a valid code',
        );
      }
    });

    test('does not repeat itself in a small sample', () {
      // Not a uniqueness proof — the repository checks collisions for real — just
      // a guard against a generator stuck on one value.
      final generator = RandomRoomCodeGenerator();
      final seen = <String>{};
      for (var i = 0; i < 50; i++) {
        seen.add(generator.generate());
      }
      expect(seen.length, greaterThan(45));
    });

    test('is deterministic when given a seeded Random', () {
      final first = RandomRoomCodeGenerator(random: Random(7));
      final second = RandomRoomCodeGenerator(random: Random(7));
      expect(first.generate(), second.generate());
    });
  });

  group('ScriptedRoomCodeGenerator', () {
    test('returns the script in order, then falls back', () {
      final generator = ScriptedRoomCodeGenerator(const <String>[
        'AAAAAA',
        'BBBBBB',
      ], fallback: const _FixedGenerator('CCCCCC'));
      expect(generator.generate(), 'AAAAAA');
      expect(generator.generate(), 'BBBBBB');
      expect(generator.generate(), 'CCCCCC');
      expect(generator.generate(), 'CCCCCC');
      expect(generator.calls, 4);
    });
  });
}

/// Returns one fixed code, so the scripted-generator fallback path is testable
/// without depending on randomness.
class _FixedGenerator implements RoomCodeGenerator {
  const _FixedGenerator(this.code);
  final String code;
  @override
  String generate() => code;
}
