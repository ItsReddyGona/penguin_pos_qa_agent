import 'dart:async';

import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_cancellation.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_runner.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_runner.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/register/register_runner.dart';
import 'package:penguin_pos_qa_agent/automation/register/register_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/api_trace_collector.dart';
import 'package:penguin_pos_qa_agent/core/secret_redactor.dart';
import 'package:penguin_pos_qa_agent/domain/plan/execution_plan.dart';
import 'package:penguin_pos_qa_agent/domain/suites/qa_suite_registry.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/login_test_case.dart';
import 'package:penguin_pos_qa_agent/runtime/app_target_handle.dart';
import 'package:penguin_pos_qa_agent/runtime/app_launcher.dart';
import 'package:penguin_pos_qa_agent/runtime/driver_engine.dart';

enum ExecutionTargetMode { local, ssh }

class SshExecutionConfig {
  const SshExecutionConfig({
    required this.username,
    required this.host,
    this.port = 22,
    this.identityFile,
    this.remoteAppRoot = '',
    this.remoteFlutterExecutable = 'flutter',
    this.password,
  });

  final String username;
  final String host;
  final int port;
  final String? identityFile;
  final String remoteAppRoot;
  final String remoteFlutterExecutable;
  final String? password;

  bool get isConfigured => username.trim().isNotEmpty && host.trim().isNotEmpty;
}

typedef SshConnectionTester = Future<bool> Function(SshExecutionConfig config);

/// Runtime-only credentials resolved by the caller after preflight. They are
/// never included in [ExecutionPlanResult] or any event emitted by this class.
class ExecutionCredentials {
  const ExecutionCredentials({
    required this.loginId,
    required this.password,
    this.unlockPin,
  });

  final String loginId;
  final String password;
  final String? unlockPin;
}

/// A preflight-approved execution request. Constructing this object does not
/// launch PenguinPOS; callers should create it only after a passing preflight.
class PreparedExecution {
  const PreparedExecution({
    required this.plan,
    required this.profileId,
    required this.profileLabel,
    required this.entity,
    required this.environment,
    required this.credentials,
    required this.appRoot,
    required this.flutterExecutable,
    this.targetMode = ExecutionTargetMode.local,
    this.sshConfig,
    this.configuredLoginCases = const <LoginTestCaseDefinition>[],
    this.loginRepeatCount = 1,
    this.orderScenario,
    this.registerScenario,
    this.telemetryCollector,
    this.noticeDisplayMode = QaTestNoticeDisplayMode.warningsAndErrors,
  });

  final ExecutionPlan plan;
  final String profileId;
  final String profileLabel;
  final String entity;
  final String environment;
  final ExecutionCredentials credentials;
  final String appRoot;
  final String flutterExecutable;
  final ExecutionTargetMode targetMode;
  final SshExecutionConfig? sshConfig;
  final List<LoginTestCaseDefinition> configuredLoginCases;
  final int loginRepeatCount;
  final OrderScenario? orderScenario;
  final RegisterScenario? registerScenario;
  final ApiTraceCollector? telemetryCollector;
  final QaTestNoticeDisplayMode noticeDisplayMode;
}

class ExecutionLaunchRequest {
  const ExecutionLaunchRequest({
    required this.appRoot,
    required this.flutterExecutable,
    required this.entity,
    required this.environment,
    this.targetMode = ExecutionTargetMode.local,
    this.sshConfig,
  });

  final String appRoot;
  final String flutterExecutable;
  final String entity;
  final String environment;
  final ExecutionTargetMode targetMode;
  final SshExecutionConfig? sshConfig;
}

typedef ExecutionLauncher =
    Future<AppTargetHandle> Function(ExecutionLaunchRequest request);

typedef LoginSuiteExecutor =
    Future<LoginRunResult> Function(
      LoginScenario scenario, {
      required Uri vmServiceUri,
      void Function(ExecutionEvent event)? onExecutionEvent,
      void Function(String scenarioName)? onScenarioCompleted,
      List<LoginTestCaseDefinition>? configuredCases,
      int? repeatCount,
      ApiTraceCollector? telemetryCollector,
      QaTestNoticeDisplayMode? noticeDisplayMode,
    });

typedef OrderSuiteExecutor =
    Future<OrderRunResult> Function(
      OrderScenario scenario, {
      required Uri vmServiceUri,
      void Function(ExecutionEvent event)? onExecutionEvent,
      void Function(String scenarioName)? onScenarioCompleted,
      void Function(int completed, int total)? onBatchProgress,
      ApiTraceCollector? telemetryCollector,
      QaTestNoticeDisplayMode? noticeDisplayMode,
    });

/// UI-neutral listener callbacks. The GUI can transform them into activity
/// messages or progress widgets without becoming part of execution logic.
class ExecutionCallbacks {
  const ExecutionCallbacks({
    this.onEvent,
    this.onScenarioCompleted,
    this.onOrderProgress,
  });

  final void Function(ExecutionEvent event)? onEvent;
  final void Function(String scenarioName)? onScenarioCompleted;
  final void Function(int completed, int total)? onOrderProgress;
}

/// Safe aggregate order information for a report. It contains no runner or
/// driver handles and can be rendered by either AI or Manual mode.
class ExecutionOrderSummary {
  const ExecutionOrderSummary({
    required this.ordersCompleted,
    required this.ordersTarget,
    required this.totalItemsProcessed,
    required this.aggregateTotalPayable,
    required this.aggregatePayableAmount,
  });

  final int ordersCompleted;
  final int ordersTarget;
  final int totalItemsProcessed;
  final double aggregateTotalPayable;
  final int aggregatePayableAmount;
}

/// One normalized result for either login or order execution.
class ExecutionPlanResult {
  const ExecutionPlanResult({
    required this.plan,
    required this.profileId,
    required this.profileLabel,
    required this.startedAt,
    required this.finishedAt,
    required this.passed,
    this.cancelled = false,
    this.wasAppClosedByUser = false,
    this.completedScenarios = const <String>[],
    this.error,
    this.cleanupPassed,
    this.cleanupDetail,
    this.orderSummary,
    this.loginResult,
    this.orderResult,
    this.registerResult,
  });

  final ExecutionPlan plan;
  final String profileId;
  final String profileLabel;
  final DateTime startedAt;
  final DateTime finishedAt;
  final bool passed;
  final bool cancelled;
  final bool wasAppClosedByUser;
  final List<String> completedScenarios;
  final String? error;
  final bool? cleanupPassed;
  final String? cleanupDetail;
  final ExecutionOrderSummary? orderSummary;
  final LoginRunResult? loginResult;
  final OrderRunResult? orderResult;
  final RegisterRunResult? registerResult;

  Duration get duration => finishedAt.difference(startedAt);
}

/// Sole owner of a PenguinPOS process while a GUI execution is active.
///
/// It is intentionally constructed with function adapters so the existing
/// concrete runners remain unchanged and the coordinator stays unit-testable.
class QaExecutionCoordinator {
  QaExecutionCoordinator({
    required ExecutionLauncher launcher,
    required LoginSuiteExecutor loginExecutor,
    required OrderSuiteExecutor orderExecutor,
    this.sshLauncher,
  }) : _launcher = launcher,
       _loginExecutor = loginExecutor,
       _orderExecutor = orderExecutor;

  factory QaExecutionCoordinator.live({
    PenguinPosAppLauncher? launcher,
    PenguinPosLoginRunner? loginRunner,
    PenguinPosOrderRunner? orderRunner,
    ExecutionLauncher? sshLauncher,
  }) {
    final resolvedLauncher = launcher ?? PenguinPosAppLauncher();
    final resolvedLoginRunner = loginRunner ?? PenguinPosLoginRunner();
    final resolvedOrderRunner = orderRunner ?? PenguinPosOrderRunner();
    return QaExecutionCoordinator(
      launcher: (request) => resolvedLauncher.launch(
        appRoot: request.appRoot,
        flutterExecutable: request.flutterExecutable,
        entity: request.entity,
        env: request.environment,
      ),
      sshLauncher: sshLauncher,
      loginExecutor:
          (
            scenario, {
            required vmServiceUri,
            onExecutionEvent,
            onScenarioCompleted,
            configuredCases = const <LoginTestCaseDefinition>[],
            repeatCount = 1,
            telemetryCollector,
            noticeDisplayMode = QaTestNoticeDisplayMode.warningsAndErrors,
          }) async {
            final cases = configuredCases ?? const <LoginTestCaseDefinition>[];
            final repeats = repeatCount ?? 1;
            final notices =
                noticeDisplayMode ?? QaTestNoticeDisplayMode.warningsAndErrors;
            if (cases.isNotEmpty) {
              return resolvedLoginRunner.runConfiguredCases(
                cases,
                vmServiceUri: vmServiceUri,
                // Each API-gated case (invalid/valid credentials) needs time for
                // field entry + the 30-second API timeout + UI verification.
                // 90 seconds gives a comfortable margin across all case types.
                timeout: const Duration(seconds: 90),
                onExecutionEvent: onExecutionEvent,
                onScenarioCompleted: onScenarioCompleted,
                telemetryCollector: telemetryCollector,
                noticeDisplayMode: notices,
              );
            }
            var result = await resolvedLoginRunner.runFullSequence(
              scenario,
              vmServiceUri: vmServiceUri,
              onExecutionEvent: onExecutionEvent,
              onScenarioCompleted: onScenarioCompleted,
              telemetryCollector: telemetryCollector,
              noticeDisplayMode: notices,
            );
            for (var iteration = 2; iteration <= repeats; iteration++) {
              if (!result.passed || result.wasAppClosedByUser) break;
              result = await resolvedLoginRunner.runFullSequence(
                LoginScenario(
                  id: '${scenario.id}_$iteration',
                  name: scenario.name,
                  loginId: scenario.loginId,
                  password: scenario.password,
                  unlockPin: scenario.unlockPin,
                  terminalContinueKey: scenario.terminalContinueKey,
                  expectedKey: scenario.expectedKey,
                ),
                vmServiceUri: vmServiceUri,
                onExecutionEvent: onExecutionEvent,
                onScenarioCompleted: onScenarioCompleted,
                telemetryCollector: telemetryCollector,
                noticeDisplayMode: notices,
              );
            }
            return result;
          },
      orderExecutor:
          (
            scenario, {
            required vmServiceUri,
            onExecutionEvent,
            onScenarioCompleted,
            onBatchProgress,
            telemetryCollector,
            noticeDisplayMode = QaTestNoticeDisplayMode.warningsAndErrors,
          }) => resolvedOrderRunner.run(
            scenario,
            vmServiceUri: vmServiceUri,
            onExecutionEvent: onExecutionEvent,
            onScenarioCompleted: onScenarioCompleted,
            onBatchProgress: onBatchProgress,
            telemetryCollector: telemetryCollector,
            noticeDisplayMode:
                noticeDisplayMode ?? QaTestNoticeDisplayMode.warningsAndErrors,
          ),
    );
  }

  final ExecutionLauncher _launcher;
  final ExecutionLauncher? sshLauncher;
  final LoginSuiteExecutor _loginExecutor;
  final OrderSuiteExecutor _orderExecutor;

  AppTargetHandle? _activeLaunch;
  ExecutionCancellationSignal? _activeCancellation;
  bool _running = false;
  bool _stopRequested = false;

  bool get isRunning => _running;

  ExecutionLauncher? get sshExecutionLauncher => sshLauncher;

  /// Requests cancellation by closing only the process launched by this
  /// coordinator. Runner completion/cleanup still happens in [run]'s finally.
  Future<void> requestStop() async {
    if (_stopRequested || (!_running && _activeLaunch == null)) return;
    _stopRequested = true;
    _activeCancellation?.cancel(
      ExecutionCancellationReason.userRequested,
      'Test execution stopped by user.',
    );
    final activeLaunch = _activeLaunch;
    _activeLaunch = null;
    await _closeTarget(activeLaunch);
  }

  Future<ExecutionPlanResult> run(
    PreparedExecution execution, {
    ExecutionCallbacks callbacks = const ExecutionCallbacks(),
  }) async {
    if (_running) {
      throw StateError('A QA execution is already running.');
    }
    final planIssues = execution.plan.validate();
    if (planIssues.isNotEmpty) {
      throw ArgumentError.value(
        execution.plan,
        'execution.plan',
        planIssues.first,
      );
    }

    _running = true;
    _stopRequested = false;
    final startedAt = DateTime.now();
    AppTargetHandle? launched;
    StreamSubscription<AppTargetLifecycleEvent>? lifecycleSubscription;
    String? targetFailureMessage;
    final cancellation = ExecutionCancellationSignal();
    _activeCancellation = cancellation;
    final completedScenarios = <String>[];

    void scenarioCompleted(String scenarioName) {
      if (!completedScenarios.contains(scenarioName)) {
        completedScenarios.add(scenarioName);
      }
      callbacks.onScenarioCompleted?.call(scenarioName);
    }

    try {
      // Clear any target left behind by an interrupted or timed-out teardown
      // before starting another run.
      final previousLaunch = _activeLaunch;
      _activeLaunch = null;
      if (previousLaunch != null) {
        await _closeTarget(previousLaunch);
      }

      callbacks.onEvent?.call(
        const ExecutionEvent(
          title: 'Launching PenguinPOS',
          message: 'Starting the configured QA application instance.',
        ),
      );
      final launchRequest = ExecutionLaunchRequest(
        appRoot: execution.appRoot,
        flutterExecutable: execution.flutterExecutable,
        entity: execution.entity,
        environment: execution.environment,
        targetMode: execution.targetMode,
        sshConfig: execution.sshConfig,
      );
      final launcher = execution.targetMode == ExecutionTargetMode.ssh
          ? sshLauncher
          : _launcher;
      if (launcher == null) {
        throw StateError(
          'SSH launcher is not configured. Connect the SSH runtime adapter before executing a remote target.',
        );
      }
      final launchOperation = launcher(launchRequest);
      unawaited(
        launchOperation
            .then((lateTarget) async {
              if (cancellation.isCancelled) await _closeTarget(lateTarget);
            })
            .catchError((_) {}),
      );
      final target = await cancellation.race(launchOperation);
      launched = target;
      _activeLaunch = target;
      lifecycleSubscription = target.lifecycleEvents.listen((event) {
        if (_stopRequested || targetFailureMessage != null) return;
        switch (event.state) {
          case AppTargetLifecycleState.disconnected:
          case AppTargetLifecycleState.exited:
          case AppTargetLifecycleState.failed:
          case AppTargetLifecycleState.stopped:
            targetFailureMessage =
                event.message ??
                'The ${execution.targetMode == ExecutionTargetMode.ssh ? 'remote' : 'local'} PenguinPOS target disconnected.';
            cancellation.cancel(
              ExecutionCancellationReason.targetUnavailable,
              targetFailureMessage!,
            );
            callbacks.onEvent?.call(
              ExecutionEvent(
                title: 'PenguinPOS target disconnected',
                message: targetFailureMessage!,
              ),
            );
          case AppTargetLifecycleState.starting:
          case AppTargetLifecycleState.ready:
          case AppTargetLifecycleState.stopping:
            break;
        }
      });

      if (_stopRequested) {
        return _cancelledResult(execution, startedAt, completedScenarios);
      }

      if (execution.plan.suiteId == QaSuiteId.loginTerminal) {
        final result = await cancellation.race(
          cancellation.run(
            () => _loginExecutor(
              LoginScenario(
                id: 'login_terminal_full_sequence',
                name: 'Login and terminal selection',
                loginId: execution.credentials.loginId,
                password: execution.credentials.password,
                unlockPin: execution.credentials.unlockPin,
              ),
              vmServiceUri: target.vmServiceUri,
              onExecutionEvent: callbacks.onEvent,
              onScenarioCompleted: scenarioCompleted,
              configuredCases: execution.configuredLoginCases,
              repeatCount: execution.loginRepeatCount,
              telemetryCollector: execution.telemetryCollector,
              noticeDisplayMode: execution.noticeDisplayMode,
            ),
          ),
        );
        return ExecutionPlanResult(
          plan: execution.plan,
          profileId: execution.profileId,
          profileLabel: execution.profileLabel,
          startedAt: result.startedAt,
          finishedAt: result.finishedAt,
          passed:
              result.passed && !_stopRequested && targetFailureMessage == null,
          cancelled: _stopRequested,
          wasAppClosedByUser: result.wasAppClosedByUser || _stopRequested,
          completedScenarios: completedScenarios.isEmpty
              ? result.scenariosExecuted
              : completedScenarios,
          error: _stopRequested
              ? _cancelledMessage
              : targetFailureMessage ?? result.error,
          cleanupPassed: result.cleanupPassed,
          cleanupDetail: result.cleanupDetail,
          loginResult: result,
        );
      }

      if (execution.plan.suiteId == QaSuiteId.register ||
          execution.plan.suiteId == QaSuiteId.closeRegister) {
        final registerSuite = QaSuiteRegistry.instance.get(
          execution.plan.suiteId,
        );
        if (registerSuite != null) {
          return await cancellation.race(
            cancellation.run(
              () => registerSuite.execute(
                driver: DriverEngine(),
                vmServiceUri: target.vmServiceUri,
                execution: execution,
                callbacks: callbacks,
              ),
            ),
          );
        }
      }

      final order =
          execution.orderScenario ?? _orderScenarioFromPlan(execution);
      final result = await cancellation.race(
        cancellation.run(
          () => _orderExecutor(
            order,
            vmServiceUri: target.vmServiceUri,
            onExecutionEvent: callbacks.onEvent,
            onScenarioCompleted: scenarioCompleted,
            onBatchProgress: callbacks.onOrderProgress,
            telemetryCollector: execution.telemetryCollector,
            noticeDisplayMode: execution.noticeDisplayMode,
          ),
        ),
      );
      return ExecutionPlanResult(
        plan: execution.plan,
        profileId: execution.profileId,
        profileLabel: execution.profileLabel,
        startedAt: result.startedAt,
        finishedAt: result.finishedAt,
        passed:
            result.passed && !_stopRequested && targetFailureMessage == null,
        cancelled: _stopRequested,
        wasAppClosedByUser: result.wasAppClosedByUser || _stopRequested,
        completedScenarios: completedScenarios,
        error: _stopRequested
            ? _cancelledMessage
            : targetFailureMessage ?? result.error,
        orderSummary: ExecutionOrderSummary(
          ordersCompleted: result.ordersCompleted,
          ordersTarget: result.ordersTarget,
          totalItemsProcessed: result.totalItemsProcessed,
          aggregateTotalPayable: result.aggregateTotalPayable,
          aggregatePayableAmount: result.aggregatePayableAmount,
        ),
        orderResult: result,
      );
    } catch (error) {
      final wasStopped = _stopRequested;
      return ExecutionPlanResult(
        plan: execution.plan,
        profileId: execution.profileId,
        profileLabel: execution.profileLabel,
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        passed: false,
        cancelled: wasStopped,
        wasAppClosedByUser:
            wasStopped ||
            targetFailureMessage != null ||
            _isAppClosed(error.toString()),
        completedScenarios: completedScenarios,
        error: wasStopped
            ? _cancelledMessage
            : targetFailureMessage ??
                  redactSecrets(error.toString(), <String?>[
                    execution.credentials.loginId,
                    execution.credentials.password,
                    execution.credentials.unlockPin,
                  ]),
      );
    } finally {
      await lifecycleSubscription?.cancel();
      await _closeTarget(launched);
      if (identical(_activeLaunch, launched)) _activeLaunch = null;
      if (identical(_activeCancellation, cancellation)) {
        _activeCancellation = null;
      }
      _running = false;
    }
  }

  static Future<void> _closeTarget(AppTargetHandle? target) async {
    if (target == null) return;
    try {
      await target.close().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Target teardown is best effort and must never block or terminate the
      // QA Agent process. Concrete handles still finish their own cleanup.
    }
  }

  static OrderScenario _orderScenarioFromPlan(PreparedExecution execution) {
    final order = execution.plan.orderConfiguration!;
    return OrderScenario(
      id: '${execution.profileId}_order_cash',
      name: 'Order & Cash Payment',
      loginId: execution.credentials.loginId,
      password: execution.credentials.password,
      unlockPin: execution.credentials.unlockPin,
      items: order.items,
      ordersCount: order.ordersCount,
      inputSourceMode: InputSourceMode.uiForm,
      uiCustomMode: order.itemStrategy == ExecutionItemStrategy.perOrder
          ? UiCustomMode.perIteration
          : UiCustomMode.common,
      perIterationItems: order.perIterationItems,
    );
  }

  ExecutionPlanResult _cancelledResult(
    PreparedExecution execution,
    DateTime startedAt,
    List<String> completedScenarios,
  ) => ExecutionPlanResult(
    plan: execution.plan,
    profileId: execution.profileId,
    profileLabel: execution.profileLabel,
    startedAt: startedAt,
    finishedAt: DateTime.now(),
    passed: false,
    cancelled: true,
    wasAppClosedByUser: true,
    completedScenarios: completedScenarios,
    error: _cancelledMessage,
  );

  static const _cancelledMessage = 'Test stopped by the user.';

  static bool _isAppClosed(String error) =>
      error.contains('Service has disappeared') ||
      error.contains('112') ||
      error.contains('SocketException') ||
      error.contains('Closed') ||
      error.contains('exited');
}
