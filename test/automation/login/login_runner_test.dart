import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/qa_agent.dart';

void main() {
  group('LoginRunner Payload', () {
    test('constructs LoginScenario with expected defaults', () {
      const scenario = LoginScenario(
        id: 'test_login',
        name: 'Test Login',
        loginId: '8888888888',
        password: 'secret_password',
      );

      expect(scenario.id, equals('test_login'));
      expect(scenario.loginId, equals('8888888888'));
      expect(scenario.password, equals('secret_password'));
      expect(scenario.unlockPin, isNull);
      expect(scenario.terminalContinueKey, equals('login.terminal.continue'));
      expect(scenario.expectedKey, equals('home.screen'));
    });

    test(
      'LoginRunResult serializes cleanly to JSON without leaking secrets and includes scenariosExecuted',
      () {
        final started = DateTime.parse('2026-08-06T10:00:00Z');
        final finished = DateTime.parse('2026-08-06T10:00:05Z');
        final result = LoginRunResult(
          passed: true,
          startedAt: started,
          finishedAt: finished,
          scenariosExecuted: const <String>[
            'empty_credentials_validation',
            'invalid_credentials_attempt',
            'valid_login_terminal_selection_and_home_screen',
          ],
          vmServiceUri: Uri.parse('http://127.0.0.1:12345/'),
        );

        final json = result.toJson();
        expect(json['passed'], isTrue);
        expect(
          json['scenariosExecuted'],
          equals(<String>[
            'empty_credentials_validation',
            'invalid_credentials_attempt',
            'valid_login_terminal_selection_and_home_screen',
          ]),
        );
        expect(json['vmServiceUri'], equals('http://127.0.0.1:12345/'));
        expect(json.containsKey('password'), isFalse);
      },
    );
  });
}
