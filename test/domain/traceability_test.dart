import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Traceability test: verifies that all 79 catalog IDs from game_spec.md
/// are represented in spec_catalog_test.dart.
///
/// This reads the test file and checks for the presence of each ID.
void main() {
  test('all 79 catalog IDs have individual tests', () {
    final content = File('test/domain/spec_catalog_test.dart')
        .readAsStringSync();

    final requiredIds = <String>{
      // T-MOVE (20)
      'T-MOVE-001', 'T-MOVE-002', 'T-MOVE-003', 'T-MOVE-004',
      'T-MOVE-005', 'T-MOVE-006', 'T-MOVE-007', 'T-MOVE-008',
      'T-MOVE-009', 'T-MOVE-010', 'T-MOVE-011', 'T-MOVE-012',
      'T-MOVE-013', 'T-MOVE-014', 'T-MOVE-015', 'T-MOVE-016',
      'T-MOVE-017', 'T-MOVE-018', 'T-MOVE-019', 'T-MOVE-020',
      // T-JUMP (13)
      'T-JUMP-001', 'T-JUMP-002', 'T-JUMP-003', 'T-JUMP-004',
      'T-JUMP-005', 'T-JUMP-006', 'T-JUMP-007', 'T-JUMP-008',
      'T-JUMP-009', 'T-JUMP-010', 'T-JUMP-011', 'T-JUMP-012',
      'T-JUMP-013',
      // T-WALL (13)
      'T-WALL-001', 'T-WALL-002', 'T-WALL-003', 'T-WALL-004',
      'T-WALL-005', 'T-WALL-006', 'T-WALL-007', 'T-WALL-008',
      'T-WALL-009', 'T-WALL-010', 'T-WALL-011', 'T-WALL-012',
      'T-WALL-013',
      // T-PATH (6)
      'T-PATH-001', 'T-PATH-002', 'T-PATH-003', 'T-PATH-004',
      'T-PATH-005', 'T-PATH-006',
      // T-WIN (6)
      'T-WIN-001', 'T-WIN-002', 'T-WIN-003', 'T-WIN-004',
      'T-WIN-005', 'T-WIN-006',
      // T-TURN (6)
      'T-TURN-001', 'T-TURN-002', 'T-TURN-003', 'T-TURN-004',
      'T-TURN-005', 'T-TURN-006',
      // T-SERIAL (6)
      'T-SERIAL-001', 'T-SERIAL-002', 'T-SERIAL-003', 'T-SERIAL-004',
      'T-SERIAL-005', 'T-SERIAL-006',
      // T-DET (5)
      'T-DET-001', 'T-DET-002', 'T-DET-003', 'T-DET-004',
      'T-DET-005',
      // T-CONFIG (4)
      'T-CONFIG-001', 'T-CONFIG-002', 'T-CONFIG-003', 'T-CONFIG-004',
    };

    final missing = <String>{};
    for (final id in requiredIds) {
      if (!content.contains(id)) {
        missing.add(id);
      }
    }

    expect(
      missing,
      isEmpty,
      reason: 'Missing catalog IDs in spec_catalog_test.dart: $missing',
    );
  });

  test('count of test() calls in spec_catalog_test.dart', () {
    final content = File('test/domain/spec_catalog_test.dart')
        .readAsStringSync();
    final testCount = 'test('.allMatches(content).length;
    expect(
      testCount,
      greaterThanOrEqualTo(79),
      reason: 'Expected at least 79 test() calls, found $testCount',
    );
  });
}
