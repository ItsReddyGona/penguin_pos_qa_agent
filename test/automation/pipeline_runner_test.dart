import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_cancellation.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/pipeline_runner.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/login/blocks/ensure_logged_out_block.dart';
import 'package:penguin_pos_qa_agent/automation/login/blocks/perform_login_block.dart';
import 'package:penguin_pos_qa_agent/automation/login/blocks/select_terminal_block.dart';
import 'package:penguin_pos_qa_agent/automation/login/blocks/validate_invalid_credentials_block.dart';
import 'package:penguin_pos_qa_agent/automation/login/blocks/verify_home_screen_block.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_keys.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_runner.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_state_snapshot.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/api_trace_event.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/login_test_case.dart';

class FakeDriverEngine implements Driver {
  final List<String> tappedKeys = [];
  final List<String> enteredTexts = [];
  final List<String> waitedTexts = [];
  final List<String> requestDataMessages = [];
  final List<ApiTraceEvent> _loginApiTraces = [];
  final List<(ApiTraceResult, int)> queuedLoginApiResponses = [];
  ApiTraceResult nextLoginApiResult = ApiTraceResult.success;
  int nextLoginApiStatusCode = 200;
  bool isConnected = false;
  bool isClosed = false;
  int clearQaTestNoticeCalls = 0;
  final List<QaTestNotice> notices = [];
  String currentUiState = PenguinPosLoginKeys.loginId;

  @override
  Future<void> connect(
    Uri vmServiceUri, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    isConnected = true;
  }

  @override
  Future<void> waitFor(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  }) async {}

  @override
  Future<void> waitForAbsent(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  }) async {}

  @override
  Future<String> waitForAnyKey(
    Iterable<String> keys, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    return currentUiState;
  }

  @override
  Future<void> waitForText(
    String text, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    waitedTexts.add(text);
  }

  @override
  Future<bool> hasKey(
    String key, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    return key == PenguinPosLoginKeys.loginId ||
        key == PenguinPosLoginKeys.logoutButton ||
        key == PenguinPosLoginKeys.authErrorSnackBar ||
        key == PenguinPosLoginKeys.loginErrorSnackBar ||
        key == 'login.qwerty.key.a';
  }

  @override
  Future<bool> hasText(
    String text, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    return false;
  }

  @override
  Future<void> enterText(
    String key,
    String text, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    enteredTexts.add('$key:$text');
  }

  @override
  Future<void> enterTextViaVirtualKeyboard(
    String targetInputKey,
    String text, {
    String keyPrefix = 'login.qwerty',
    TextInputMode mode = TextInputMode.customQwertyPad,
  }) async {
    if (mode == TextInputMode.driverDirect) {
      await enterText(targetInputKey, text);
      return;
    }
    tappedKeys.add('focus:$targetInputKey');
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (!RegExp(r'^[a-zA-Z0-9.,_/# ]$').hasMatch(char)) {
        throw UnsupportedKeyboardCharacterException(position: i + 1);
      }
      final isUpper = RegExp(r'^[A-Z]$').hasMatch(char);
      if (isUpper) {
        tappedKeys.add('$keyPrefix.shift');
        tappedKeys.add('$keyPrefix.key.${char.toLowerCase()}');
        tappedKeys.add('$keyPrefix.shift');
      } else {
        tappedKeys.add('$keyPrefix.key.$char');
      }
    }
  }

  @override
  Future<String?> tryGetText(
    String key, {
    Duration timeout = const Duration(seconds: 3),
  }) async => null;

  @override
  Future<String> getText(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  }) async => '';

  @override
  Future<void> tap(String key) async {
    tappedKeys.add(key);
    if (key == PenguinPosLoginKeys.submit) {
      final queuedResponse = queuedLoginApiResponses.isEmpty
          ? null
          : queuedLoginApiResponses.removeAt(0);
      final traceId = _loginApiTraces.length + 1;
      _loginApiTraces.add(
        ApiTraceEvent(
          traceId: traceId,
          stepId: 'login',
          startTimeMs: traceId * 10,
          endTimeMs: traceId * 10 + 5,
          durationMs: 5,
          method: 'POST',
          route: '/authn/api/v1/pos/login',
          statusCode: queuedResponse?.$2 ?? nextLoginApiStatusCode,
          result: queuedResponse?.$1 ?? nextLoginApiResult,
          timeoutBudgetMs: 30000,
          sanitizedPreview: '',
          responseSizeBytes: 0,
        ),
      );
    }
  }

  @override
  Future<void> tapText(String text) async {
    tappedKeys.add('text:$text');
  }

  @override
  Future<bool> tryTapText(
    String text, {
    Duration timeout = const Duration(seconds: 3),
  }) async => true;

  @override
  Future<bool> tryTapKey(
    String key, {
    Duration timeout = const Duration(seconds: 3),
  }) async => true;

  @override
  Future<String?> requestData(
    String message, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    requestDataMessages.add(message);
    if (message.startsWith('api_traces_since:')) {
      final cursor = int.tryParse(message.split(':').last) ?? 0;
      return jsonEncode(<String, Object?>{
        'cursor': _loginApiTraces.isEmpty
            ? cursor
            : _loginApiTraces.last.traceId,
        'events': _loginApiTraces
            .where((trace) => trace.traceId > cursor)
            .map((trace) => trace.toJson())
            .toList(growable: false),
      });
    }
    return 'cleared';
  }

  @override
  Future<OrderStateSnapshot?> queryOrderState({
    Duration timeout = const Duration(seconds: 3),
  }) async => null;

  @override
  Future<bool> clearSnackBars() async => true;

  @override
  Future<bool> showQaTestNotice(QaTestNotice notice) async {
    notices.add(notice);
    return true;
  }

  @override
  Future<bool> clearQaTestNotice() async {
    clearQaTestNoticeCalls++;
    return true;
  }

  @override
  Future<void> close() async {
    isClosed = true;
  }
}

class FailingBlock implements AutomationBlock {
  @override
  String get id => 'failing_block';
  @override
  String get name => 'Failing Block';
  @override
  StepNotice? get notice => null;

  @override
  Future<void> execute(ExecutionContext context) async {
    throw Exception('Simulated step failure with secret user_pass_123');
  }
}

class DisconnectedBlock implements AutomationBlock {
  @override
  String get id => 'disconnected_block';
  @override
  String get name => 'Disconnected Block';
  @override
  StepNotice? get notice => null;

  @override
  Future<void> execute(ExecutionContext context) async {
    throw const TargetAppDisconnectedException();
  }
}

class NeverCompletingBlock implements AutomationBlock {
  final Completer<void> started = Completer<void>();

  @override
  String get id => 'never_completing_block';
  @override
  String get name => 'Never Completing Block';
  @override
  StepNotice? get notice => null;

  @override
  Future<void> execute(ExecutionContext context) {
    if (!started.isCompleted) started.complete();
    return Completer<void>().future;
  }
}

class CountingCleanupBlock implements AutomationBlock {
  int executions = 0;

  @override
  String get id => 'counting_cleanup';
  @override
  String get name => 'Counting Cleanup';
  @override
  StepNotice? get notice => null;

  @override
  Future<void> execute(ExecutionContext context) async {
    executions++;
  }
}

void main() {
  group('PipelineRunner & Atomic Blocks Tests', () {
    test('preserves the initial session decision across cleanup', () async {
      final fakeDriver = FakeDriverEngine()
        ..currentUiState = PenguinPosLoginKeys.loginId;
      final context = ExecutionContext(driver: fakeDriver);
      final block = EnsureLoggedOutBlock();

      await block.execute(context);
      fakeDriver.currentUiState = PenguinPosLoginKeys.homeScreen;
      await block.execute(context);

      expect(context.state['initial_screen'], PenguinPosLoginKeys.loginId);
      expect(context.state['initial_session_state'], 'logged_out');
      expect(context.state['initial_logout_required'], isFalse);
      expect(context.state['cleanup_screen'], PenguinPosLoginKeys.homeScreen);
      expect(context.state['cleanup_session_state'], 'logged_in');
    });

    test(
      'PipelineRunner executes blocks sequentially and handles cleanup',
      () async {
        final fakeDriver = FakeDriverEngine();
        final runner = PipelineRunner();
        final scenario = const LoginScenario(
          id: 'test_1',
          name: 'Test Scenario',
          loginId: 'admin',
          password: 'pass',
        );

        final result = await runner.runPipeline(
          blocks: [
            EnsureLoggedOutBlock(),
            PerformLoginBlock(scenario: scenario),
            SelectTerminalBlock(scenario: scenario),
            VerifyHomeScreenBlock(scenario: scenario),
          ],
          cleanupBlocks: [EnsureLoggedOutBlock()],
          vmServiceUri: Uri.parse('http://127.0.0.1:8080/test'),
          driver: fakeDriver,
        );

        expect(result.passed, isTrue);
        expect(result.cleanupPassed, isTrue);
        expect(fakeDriver.isConnected, isTrue);
        expect(fakeDriver.isClosed, isTrue);
        expect(fakeDriver.tappedKeys, contains(PenguinPosLoginKeys.submit));
      },
    );

    test('PipelineRunner catches errors and redacts secrets', () async {
      final fakeDriver = FakeDriverEngine();
      final runner = PipelineRunner();

      final result = await runner.runPipeline(
        blocks: [FailingBlock()],
        vmServiceUri: Uri.parse('http://127.0.0.1:8080/test'),
        driver: fakeDriver,
        secretsToRedact: ['user_pass_123'],
      );

      expect(result.passed, isFalse);
      expect(result.error, contains('[REDACTED]'));
      expect(result.error, isNot(contains('user_pass_123')));
      expect(fakeDriver.isClosed, isTrue);
      expect(fakeDriver.notices, isNotEmpty);
      expect(fakeDriver.notices.last.severity, QaTestNoticeSeverity.error);
      expect(fakeDriver.clearQaTestNoticeCalls, isZero);
    });

    test(
      'target disconnect stops immediately without running cleanup',
      () async {
        final fakeDriver = FakeDriverEngine();
        final cleanup = CountingCleanupBlock();

        final result = await PipelineRunner().runPipeline(
          blocks: <AutomationBlock>[DisconnectedBlock()],
          cleanupBlocks: <AutomationBlock>[cleanup],
          vmServiceUri: Uri.parse('http://127.0.0.1:8080/test'),
          driver: fakeDriver,
        );

        expect(result.passed, isFalse);
        expect(result.wasAppClosedByUser, isTrue);
        expect(result.cleanupPassed, isFalse);
        expect(result.cleanupDetail, contains('disconnected'));
        expect(cleanup.executions, isZero);
        expect(fakeDriver.notices, isEmpty);
        expect(fakeDriver.isClosed, isTrue);
      },
    );

    test('cancellation interrupts an in-flight block promptly', () async {
      final fakeDriver = FakeDriverEngine();
      final block = NeverCompletingBlock();
      final cancellation = ExecutionCancellationSignal();
      final resultFuture = PipelineRunner().runPipeline(
        blocks: <AutomationBlock>[block],
        cleanupBlocks: <AutomationBlock>[CountingCleanupBlock()],
        vmServiceUri: Uri.parse('http://127.0.0.1:8080/test'),
        driver: fakeDriver,
        cancellationSignal: cancellation,
      );

      await block.started.future;
      cancellation.cancel(
        ExecutionCancellationReason.userRequested,
        'Test execution stopped by user.',
      );
      final result = await resultFuture.timeout(const Duration(seconds: 1));

      expect(result.passed, isFalse);
      expect(result.wasAppClosedByUser, isTrue);
      expect(result.error, 'Test execution stopped by user.');
      expect(result.cleanupPassed, isFalse);
    });

    test(
      'UnsupportedKeyboardCharacterException does not leak unmappable character',
      () {
        const exception = UnsupportedKeyboardCharacterException(position: 4);
        expect(exception.toString(), contains('position 4'));
        expect(exception.toString(), isNot(contains('@')));
      },
    );

    test('invalid credentials wait for the API rejection result', () async {
      final fakeDriver = FakeDriverEngine()
        ..nextLoginApiResult = ApiTraceResult.httpError
        ..nextLoginApiStatusCode = 401;
      final context = ExecutionContext(driver: fakeDriver);

      await ValidateInvalidCredentialsBlock().execute(context);

      expect(
        fakeDriver.enteredTexts,
        containsAll(<String>[
          '${PenguinPosLoginKeys.loginId}:0000000000',
          '${PenguinPosLoginKeys.password}:invalidpassword',
        ]),
      );
      expect(fakeDriver.tappedKeys, contains(PenguinPosLoginKeys.submit));
      expect(
        fakeDriver.requestDataMessages,
        containsAll(<String>['api_traces_since:0', 'api_traces_since:0']),
      );
      expect(fakeDriver.waitedTexts, isNot(contains('Incorrect User ID')));
    });

    test('generic WebSocket command errors are not target disconnects', () {
      final error = Exception(
        'Flutter Driver command timed out while using a WebSocket transport.',
      );

      expect(isTargetAppDisconnectedError(error), isFalse);
      expect(
        isTargetAppDisconnectedError(
          Exception('The VM Service connection closed unexpectedly.'),
        ),
        isTrue,
      );
    });

    test(
      'configured login suite continues to valid login after invalid case fails',
      () async {
        final fakeDriver = FakeDriverEngine()
          ..queuedLoginApiResponses.addAll(<(ApiTraceResult, int)>[
            (ApiTraceResult.unexpectedError, 500),
            (ApiTraceResult.success, 200),
          ]);
        final runner = PenguinPosLoginRunner();

        final result = await runner.runConfiguredCases(
          const <LoginTestCaseDefinition>[
            LoginTestCaseDefinition(
              id: 'invalid-case',
              name: 'Invalid credentials',
              username: 'invalid-user',
              password: 'invalid-password',
              expectedResult: LoginExpectedResult.authenticationRejected,
            ),
            LoginTestCaseDefinition(
              id: 'valid-case',
              name: 'Valid credentials',
              username: 'valid-user',
              password: 'valid-password',
              expectedResult: LoginExpectedResult.successfulLogin,
            ),
          ],
          vmServiceUri: Uri.parse('http://127.0.0.1:8080/test'),
          driverEngine: fakeDriver,
        );

        expect(result.suiteResult!.results, hasLength(2));
        expect(
          result.suiteResult!.results.map((caseResult) => caseResult.status),
          <LoginTestCaseStatus>[
            LoginTestCaseStatus.failed,
            LoginTestCaseStatus.passed,
          ],
        );
        expect(
          fakeDriver.tappedKeys.where(
            (key) => key == PenguinPosLoginKeys.submit,
          ),
          hasLength(2),
        );
        expect(result.wasAppClosedByUser, isFalse);
      },
    );

    test(
      'PenguinPosLoginRunner backward-compatible methods delegate to PipelineRunner',
      () async {
        final fakeDriver = FakeDriverEngine();
        final runner = PenguinPosLoginRunner();
        const scenario = LoginScenario(
          id: 'test_2',
          name: 'Runner Test',
          loginId: 'admin',
          password: 'pass',
        );

        final result = await runner.run(
          scenario,
          vmServiceUri: Uri.parse('http://127.0.0.1:8080/test'),
          driverEngine: fakeDriver,
        );

        expect(result.passed, isTrue);
        expect(result.scenariosExecuted, contains('Submit Credentials'));
      },
    );
  });
}
