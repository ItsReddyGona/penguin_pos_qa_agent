import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/application/execution/qa_execution_coordinator.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_runner.dart';
import 'package:penguin_pos_qa_agent/domain/plan/execution_plan.dart';
import 'package:penguin_pos_qa_agent/runtime/app_launcher.dart';
import 'package:penguin_pos_qa_agent/runtime/app_target_handle.dart';

class TestTargetHandle implements AppTargetHandle {
  final StreamController<AppTargetLifecycleEvent> _events =
      StreamController<AppTargetLifecycleEvent>.broadcast();

  @override
  final Uri vmServiceUri = Uri.parse('http://127.0.0.1:45678/');

  @override
  Stream<AppTargetLifecycleEvent> get lifecycleEvents => _events.stream;

  @override
  Stream<AppTargetLifecycleEvent> get healthEvents => lifecycleEvents;

  @override
  Map<String, Object?> get metadata => const <String, Object?>{};

  @override
  bool isClosed = false;

  int closeCalls = 0;

  void emit(AppTargetLifecycleEvent event) => _events.add(event);

  @override
  Future<void> close() async {
    if (isClosed) return;
    isClosed = true;
    closeCalls++;
    await _events.close();
  }
}

void main() {
  test('rejects an invalid plan before attempting to launch', () async {
    var launchCalled = false;
    final coordinator = QaExecutionCoordinator(
      launcher: (_) {
        launchCalled = true;
        throw StateError('must not launch');
      },
      loginExecutor:
          (
            _, {
            required vmServiceUri,
            onExecutionEvent,
            onScenarioCompleted,
            configuredCases,
            repeatCount,
            telemetryCollector,
            noticeDisplayMode,
          }) => throw UnimplementedError(),
      orderExecutor:
          (
            _, {
            required vmServiceUri,
            onExecutionEvent,
            onScenarioCompleted,
            onBatchProgress,
            telemetryCollector,
            noticeDisplayMode,
          }) => throw UnimplementedError(),
    );
    const execution = PreparedExecution(
      plan: ExecutionPlan(profileId: '', suiteId: QaSuiteId.loginTerminal),
      profileId: '',
      profileLabel: '',
      entity: 'kpn',
      environment: 'stage',
      credentials: ExecutionCredentials(loginId: 'id', password: 'password'),
      appRoot: '/app',
      flutterExecutable: 'flutter',
    );

    await expectLater(coordinator.run(execution), throwsArgumentError);
    expect(launchCalled, isFalse);
    expect(coordinator.isRunning, isFalse);
  });

  test('routes SSH executions through the injected remote launcher', () async {
    ExecutionLaunchRequest? capturedRequest;
    var localLaunchCalled = false;
    final coordinator = QaExecutionCoordinator(
      launcher: (_) async {
        localLaunchCalled = true;
        throw StateError('local launcher must not be used');
      },
      sshLauncher: (request) async {
        capturedRequest = request;
        final process = await Process.start('/bin/sh', <String>[
          '-c',
          'sleep 5',
        ]);
        return LaunchedPenguinPos(
          process: process,
          vmServiceUri: Uri.parse('http://127.0.0.1:45678/'),
        );
      },
      loginExecutor:
          (
            _, {
            required vmServiceUri,
            onExecutionEvent,
            onScenarioCompleted,
            configuredCases,
            repeatCount,
            telemetryCollector,
            noticeDisplayMode,
          }) async => LoginRunResult(
            passed: true,
            startedAt: DateTime(2026, 1, 1),
            finishedAt: DateTime(2026, 1, 1, 0, 0, 1),
          ),
      orderExecutor:
          (
            _, {
            required vmServiceUri,
            onExecutionEvent,
            onScenarioCompleted,
            onBatchProgress,
            telemetryCollector,
            noticeDisplayMode,
          }) => throw UnimplementedError(),
    );

    final result = await coordinator.run(
      const PreparedExecution(
        plan: ExecutionPlan(
          profileId: 'kpn-dev',
          suiteId: QaSuiteId.loginTerminal,
        ),
        profileId: 'kpn-dev',
        profileLabel: 'KPN DEV',
        entity: 'kpn',
        environment: 'dev',
        credentials: ExecutionCredentials(loginId: 'id', password: 'secret'),
        appRoot: '',
        flutterExecutable: '',
        targetMode: ExecutionTargetMode.ssh,
        sshConfig: SshExecutionConfig(
          username: 'qa-user',
          host: 'qa.example.test',
        ),
      ),
    );

    expect(localLaunchCalled, isFalse);
    expect(capturedRequest?.targetMode, ExecutionTargetMode.ssh);
    expect(capturedRequest?.sshConfig?.username, 'qa-user');
    expect(capturedRequest?.sshConfig?.host, 'qa.example.test');
    expect(result.passed, isTrue);
    await coordinator.requestStop();
  });

  test('closes a successful target when execution completes', () async {
    late LaunchedPenguinPos launchedTarget;
    final coordinator = QaExecutionCoordinator(
      launcher: (_) async {
        final process = await Process.start('/bin/sh', <String>[
          '-c',
          'sleep 30',
        ]);
        launchedTarget = LaunchedPenguinPos(
          process: process,
          vmServiceUri: Uri.parse('http://127.0.0.1:45678/'),
        );
        return launchedTarget;
      },
      loginExecutor:
          (
            _, {
            required vmServiceUri,
            onExecutionEvent,
            onScenarioCompleted,
            configuredCases,
            repeatCount,
            telemetryCollector,
            noticeDisplayMode,
          }) async => LoginRunResult(
            passed: true,
            startedAt: DateTime(2026, 1, 1),
            finishedAt: DateTime(2026, 1, 1, 0, 0, 1),
          ),
      orderExecutor:
          (
            _, {
            required vmServiceUri,
            onExecutionEvent,
            onScenarioCompleted,
            onBatchProgress,
            telemetryCollector,
            noticeDisplayMode,
          }) => throw UnimplementedError(),
    );

    final result = await coordinator.run(
      const PreparedExecution(
        plan: ExecutionPlan(
          profileId: 'local-dev',
          suiteId: QaSuiteId.loginTerminal,
        ),
        profileId: 'local-dev',
        profileLabel: 'LOCAL DEV',
        entity: 'local',
        environment: 'dev',
        credentials: ExecutionCredentials(loginId: 'id', password: 'secret'),
        appRoot: '/app',
        flutterExecutable: 'flutter',
      ),
    );

    expect(result.passed, isTrue);
    expect(launchedTarget.isClosed, isTrue);
  });

  test('closes a launched target when execution fails', () async {
    late LaunchedPenguinPos launchedTarget;
    final coordinator = QaExecutionCoordinator(
      launcher: (_) async {
        final process = await Process.start('/bin/sh', <String>[
          '-c',
          'sleep 30',
        ]);
        launchedTarget = LaunchedPenguinPos(
          process: process,
          vmServiceUri: Uri.parse('http://127.0.0.1:45678/'),
        );
        return launchedTarget;
      },
      loginExecutor:
          (
            _, {
            required vmServiceUri,
            onExecutionEvent,
            onScenarioCompleted,
            configuredCases,
            repeatCount,
            telemetryCollector,
            noticeDisplayMode,
          }) async => LoginRunResult(
            passed: false,
            startedAt: DateTime(2026, 1, 1),
            finishedAt: DateTime(2026, 1, 1, 0, 0, 1),
            error: 'Expected test failure.',
          ),
      orderExecutor:
          (
            _, {
            required vmServiceUri,
            onExecutionEvent,
            onScenarioCompleted,
            onBatchProgress,
            telemetryCollector,
            noticeDisplayMode,
          }) => throw UnimplementedError(),
    );

    final result = await coordinator.run(
      const PreparedExecution(
        plan: ExecutionPlan(
          profileId: 'local-dev',
          suiteId: QaSuiteId.loginTerminal,
        ),
        profileId: 'local-dev',
        profileLabel: 'LOCAL DEV',
        entity: 'local',
        environment: 'dev',
        credentials: ExecutionCredentials(loginId: 'id', password: 'secret'),
        appRoot: '/app',
        flutterExecutable: 'flutter',
      ),
    );

    expect(result.passed, isFalse);
    expect(launchedTarget.isClosed, isTrue);
  });

  test(
    'user stop cancels a blocked executor and closes only the target',
    () async {
      final target = TestTargetHandle();
      final executorStarted = Completer<void>();
      final blockedExecutor = Completer<LoginRunResult>();
      final coordinator = QaExecutionCoordinator(
        launcher: (_) async => target,
        loginExecutor:
            (
              _, {
              required vmServiceUri,
              onExecutionEvent,
              onScenarioCompleted,
              configuredCases,
              repeatCount,
              telemetryCollector,
              noticeDisplayMode,
            }) {
              executorStarted.complete();
              return blockedExecutor.future;
            },
        orderExecutor:
            (
              _, {
              required vmServiceUri,
              onExecutionEvent,
              onScenarioCompleted,
              onBatchProgress,
              telemetryCollector,
              noticeDisplayMode,
            }) => throw UnimplementedError(),
      );

      final resultFuture = coordinator.run(_loginExecution());
      await executorStarted.future;
      await coordinator.requestStop();
      await coordinator.requestStop();
      final result = await resultFuture.timeout(const Duration(seconds: 1));

      expect(result.passed, isFalse);
      expect(result.cancelled, isTrue);
      expect(result.error, contains('stopped by the user'));
      expect(target.isClosed, isTrue);
      expect(target.closeCalls, 1);
      expect(coordinator.isRunning, isFalse);
    },
  );

  test('target disconnect cancels a blocked executor and reports it', () async {
    final target = TestTargetHandle();
    final executorStarted = Completer<void>();
    final coordinator = QaExecutionCoordinator(
      launcher: (_) async => target,
      loginExecutor:
          (
            _, {
            required vmServiceUri,
            onExecutionEvent,
            onScenarioCompleted,
            configuredCases,
            repeatCount,
            telemetryCollector,
            noticeDisplayMode,
          }) {
            executorStarted.complete();
            return Completer<LoginRunResult>().future;
          },
      orderExecutor:
          (
            _, {
            required vmServiceUri,
            onExecutionEvent,
            onScenarioCompleted,
            onBatchProgress,
            telemetryCollector,
            noticeDisplayMode,
          }) => throw UnimplementedError(),
    );

    final resultFuture = coordinator.run(_loginExecution());
    await executorStarted.future;
    target.emit(
      const AppTargetLifecycleEvent(
        AppTargetLifecycleState.disconnected,
        message: 'PenguinPOS is unavailable.',
      ),
    );
    final result = await resultFuture.timeout(const Duration(seconds: 1));

    expect(result.passed, isFalse);
    expect(result.cancelled, isFalse);
    expect(result.wasAppClosedByUser, isTrue);
    expect(result.error, 'PenguinPOS is unavailable.');
    expect(target.closeCalls, 1);
    expect(coordinator.isRunning, isFalse);
  });

  test(
    'target window close cancels a blocked executor and reports it',
    () async {
      final target = TestTargetHandle();
      final executorStarted = Completer<void>();
      final coordinator = QaExecutionCoordinator(
        launcher: (_) async => target,
        loginExecutor:
            (
              _, {
              required vmServiceUri,
              onExecutionEvent,
              onScenarioCompleted,
              configuredCases,
              repeatCount,
              telemetryCollector,
              noticeDisplayMode,
            }) {
              executorStarted.complete();
              return Completer<LoginRunResult>().future;
            },
        orderExecutor:
            (
              _, {
              required vmServiceUri,
              onExecutionEvent,
              onScenarioCompleted,
              onBatchProgress,
              telemetryCollector,
              noticeDisplayMode,
            }) => throw UnimplementedError(),
      );

      final resultFuture = coordinator.run(_loginExecution());
      await executorStarted.future;
      target.emit(
        const AppTargetLifecycleEvent(
          AppTargetLifecycleState.stopped,
          message: 'PenguinPOS was closed.',
        ),
      );
      final result = await resultFuture.timeout(const Duration(seconds: 1));

      expect(result.passed, isFalse);
      expect(result.cancelled, isFalse);
      expect(result.wasAppClosedByUser, isTrue);
      expect(result.error, 'PenguinPOS was closed.');
      expect(target.closeCalls, 1);
      expect(coordinator.isRunning, isFalse);
    },
  );

  test(
    'user stop returns promptly while target launch is still pending',
    () async {
      final target = TestTargetHandle();
      final launchStarted = Completer<void>();
      final pendingLaunch = Completer<AppTargetHandle>();
      final coordinator = QaExecutionCoordinator(
        launcher: (_) {
          launchStarted.complete();
          return pendingLaunch.future;
        },
        loginExecutor:
            (
              _, {
              required vmServiceUri,
              onExecutionEvent,
              onScenarioCompleted,
              configuredCases,
              repeatCount,
              telemetryCollector,
              noticeDisplayMode,
            }) => throw UnimplementedError(),
        orderExecutor:
            (
              _, {
              required vmServiceUri,
              onExecutionEvent,
              onScenarioCompleted,
              onBatchProgress,
              telemetryCollector,
              noticeDisplayMode,
            }) => throw UnimplementedError(),
      );

      final resultFuture = coordinator.run(_loginExecution());
      await launchStarted.future;
      await coordinator.requestStop();
      final result = await resultFuture.timeout(const Duration(seconds: 1));

      expect(result.cancelled, isTrue);
      expect(coordinator.isRunning, isFalse);

      pendingLaunch.complete(target);
      await Future<void>.delayed(Duration.zero);
      expect(target.isClosed, isTrue);
    },
  );

  test(
    'returns an actionable result when the SSH launcher is unavailable',
    () async {
      final coordinator = QaExecutionCoordinator(
        launcher: (_) async => throw StateError('must not launch locally'),
        loginExecutor:
            (
              _, {
              required vmServiceUri,
              onExecutionEvent,
              onScenarioCompleted,
              configuredCases,
              repeatCount,
              telemetryCollector,
              noticeDisplayMode,
            }) => throw UnimplementedError(),
        orderExecutor:
            (
              _, {
              required vmServiceUri,
              onExecutionEvent,
              onScenarioCompleted,
              onBatchProgress,
              telemetryCollector,
              noticeDisplayMode,
            }) => throw UnimplementedError(),
      );

      final result = await coordinator.run(
        const PreparedExecution(
          plan: ExecutionPlan(
            profileId: 'ibo-stage',
            suiteId: QaSuiteId.loginTerminal,
          ),
          profileId: 'ibo-stage',
          profileLabel: 'IBO STAGE',
          entity: 'ibo',
          environment: 'stage',
          credentials: ExecutionCredentials(loginId: 'id', password: 'secret'),
          appRoot: '',
          flutterExecutable: '',
          targetMode: ExecutionTargetMode.ssh,
          sshConfig: SshExecutionConfig(
            username: 'qa-user',
            host: 'qa.example.test',
          ),
        ),
      );

      expect(result.passed, isFalse);
      expect(result.error, contains('SSH launcher is not configured'));
      expect(coordinator.isRunning, isFalse);
    },
  );
}

PreparedExecution _loginExecution() => const PreparedExecution(
  plan: ExecutionPlan(profileId: 'local-dev', suiteId: QaSuiteId.loginTerminal),
  profileId: 'local-dev',
  profileLabel: 'LOCAL DEV',
  entity: 'local',
  environment: 'dev',
  credentials: ExecutionCredentials(loginId: 'id', password: 'secret'),
  appRoot: '/app',
  flutterExecutable: 'flutter',
);
