import 'package:flutter_test/flutter_test.dart';
import 'package:inzone/screen/auth/interesting_select_screen.dart';

void main() {
  group('signup completion helpers', () {
    test('maps provider ids to the correct signup method', () {
      expect(
        resolveSignupMethodFromProviderIds(const ['password']),
        equals('email'),
      );
      expect(
        resolveSignupMethodFromProviderIds(const ['google.com']),
        equals('google'),
      );
      expect(
        resolveSignupMethodFromProviderIds(const ['apple.com']),
        equals('apple'),
      );
      expect(
        resolveSignupMethodFromProviderIds(const ['anonymous']),
        equals('anonymous'),
      );
    });

    test('event fires after successful onboarding-completion write', () async {
      final emitter = SignupCompletionEmitter();
      final calls = <String>[];

      await emitter.complete(
        signupMethod: 'google',
        writeCreatedAt: () async {
          calls.add('write');
          return true;
        },
        logSignupCompleted: (signupMethod) async {
          calls.add('log:$signupMethod');
        },
      );

      await Future<void>.delayed(Duration.zero);

      expect(calls, equals(['write', 'log:google']));
    });

    test('event does not fire when the Firestore write fails', () async {
      final emitter = SignupCompletionEmitter();
      var logCalls = 0;

      await expectLater(
        emitter.complete(
          signupMethod: 'email',
          writeCreatedAt: () async {
            throw StateError('write failed');
          },
          logSignupCompleted: (_) async {
            logCalls += 1;
          },
        ),
        throwsStateError,
      );

      await Future<void>.delayed(Duration.zero);

      expect(logCalls, equals(0));
    });

    test('duplicate completion callback in one process emits once', () async {
      final emitter = SignupCompletionEmitter();
      final calls = <String>[];

      await emitter.complete(
        signupMethod: 'apple',
        writeCreatedAt: () async {
          calls.add('write');
          return true;
        },
        logSignupCompleted: (signupMethod) async {
          calls.add('log:$signupMethod');
        },
      );
      await emitter.complete(
        signupMethod: 'apple',
        writeCreatedAt: () async {
          calls.add('write-again');
          return true;
        },
        logSignupCompleted: (signupMethod) async {
          calls.add('log-again:$signupMethod');
        },
      );

      await Future<void>.delayed(Duration.zero);

      expect(calls, equals(['write', 'log:apple']));
    });

    test('does not emit when createdAt is already present', () async {
      final emitter = SignupCompletionEmitter();
      var logCalls = 0;

      await emitter.complete(
        signupMethod: 'email',
        writeCreatedAt: () async => false,
        logSignupCompleted: (_) async {
          logCalls += 1;
        },
      );

      await Future<void>.delayed(Duration.zero);

      expect(logCalls, equals(0));
    });
  });
}
