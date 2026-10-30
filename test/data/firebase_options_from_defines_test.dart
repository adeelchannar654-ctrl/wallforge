import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/data/remote/firebase_options_from_defines.dart';

/// Phase 15 (A.4): the --dart-define web-options seam, tested with fake
/// values (no real credentials anywhere near the test suite).
void main() {
  group('FirebaseOptionsFromDefines.fromValues', () {
    test('a complete fake value set maps field for field', () {
      final options = FirebaseOptionsFromDefines.fromValues(
        apiKey: 'fake-api-key',
        appId: '1:123:web:fake',
        projectId: 'demo-wallforge',
        messagingSenderId: '123',
        authDomain: 'demo-wallforge.firebaseapp.com',
        storageBucket: 'demo-wallforge.appspot.com',
      );
      expect(options, isNotNull);
      expect(options!.apiKey, 'fake-api-key');
      expect(options.appId, '1:123:web:fake');
      expect(options.projectId, 'demo-wallforge');
      expect(options.messagingSenderId, '123');
      expect(options.authDomain, 'demo-wallforge.firebaseapp.com');
      expect(options.storageBucket, 'demo-wallforge.appspot.com');
    });

    test('absent optional values map to null, not empty strings', () {
      final options = FirebaseOptionsFromDefines.fromValues(
        apiKey: 'fake-api-key',
        appId: '1:123:web:fake',
        projectId: 'demo-wallforge',
        messagingSenderId: '123',
      );
      expect(options, isNotNull);
      expect(options!.authDomain, isNull);
      expect(options.storageBucket, isNull);
    });

    test('any missing required value yields no options at all', () {
      for (final missing in [0, 1, 2, 3]) {
        final values = ['k', 'a', 'p', 's'];
        values[missing] = '';
        expect(
          FirebaseOptionsFromDefines.fromValues(
            apiKey: values[0],
            appId: values[1],
            projectId: values[2],
            messagingSenderId: values[3],
          ),
          isNull,
          reason: 'required value #$missing missing must yield null',
        );
      }
    });

    test('maybe() is null in a build without the defines', () {
      // The test runner supplies no FIREBASE_* defines, which is the
      // clean-clone default: no options, Firebase unavailable, local
      // storage — exactly the pre-Phase-15 behaviour.
      expect(FirebaseOptionsFromDefines.maybe(), isNull);
    });
  });
}
