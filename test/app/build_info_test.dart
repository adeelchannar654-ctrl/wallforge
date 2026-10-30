// Phase 16 A.1: the build identifier's fallback logic, tested with
// fakes (the real define only exists at build time).
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/build_info.dart';

void main() {
  test('a provided sha is shown verbatim', () {
    expect(BuildInfo.labelFor('d34cc53'), 'Build d34cc53');
  });

  test('missing or blank values fall back to dev', () {
    expect(BuildInfo.labelFor(null), 'Build dev');
    expect(BuildInfo.labelFor(''), 'Build dev');
    expect(BuildInfo.labelFor('   '), 'Build dev');
  });

  test('the current build always has a non-empty label', () {
    expect(BuildInfo.label, startsWith('Build '));
    expect(BuildInfo.label.length, greaterThan('Build '.length));
  });
}
