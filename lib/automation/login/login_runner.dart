import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_cancellation.dart';
import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/pipeline_runner.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/core/pos_automation_contract.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/api_trace_collector.dart';
import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/automation/login/blocks/ensure_logged_out_block.dart';
import 'package:penguin_pos_qa_agent/automation/login/blocks/perform_login_block.dart';
import 'package:penguin_pos_qa_agent/automation/login/blocks/select_terminal_block.dart';
import 'package:penguin_pos_qa_agent/automation/login/blocks/validate_empty_credentials_block.dart';
import 'package:penguin_pos_qa_agent/automation/login/blocks/validate_invalid_credentials_block.dart';
import 'package:penguin_pos_qa_agent/automation/login/blocks/validate_partial_credentials_block.dart';
import 'package:penguin_pos_qa_agent/automation/login/blocks/verify_home_screen_block.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_scenario.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/login_test_case.dart';
import 'package:penguin_pos_qa_agent/runtime/driver_engine.dart';

/// Encapsulates execution results for a login scenario run.
class LoginRunResult {
  const LoginRunResult({
    required this.passed,
    required this.startedAt,
    required this.finishedAt,
    this.scenariosExecuted = const <String>[],
    this.vmServiceUri,
    this.error,
    this.cleanupPassed,
    this.cleanupDetail,
    this.wasAppClosedByUser = false,
    this.metadata = const <String, Object?>{},
    this.suiteResult,
  });

  final bool passed;
  final DateTime startedAt;
  final DateTime finishedAt;
  final List<String> scenariosExecuted;
  final Uri? vmServiceUri;
  final String? error;

  /// Post-suite session cleanup is tracked independently so scenario results
  /// remain truthful even when the test environment could not be reset.
  final bool? cleanupPassed;
  final String? cleanupDetail;
  final bool wasAppClosedByUser;
  final Map<String, Object?> metadata;
  final LoginSuiteResult? suiteResult;

  Map<String, Object?> toJson() => <String, Object?>{
    'passed': passed,
    'scenariosExecuted': scenariosExecuted,
    'wasAppClosedByUser': wasAppClosedByUser,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'finishedAt': finishedAt.toUtc().toIso8601String(),
    if (vmServiceUri != null) 'vmServiceUri': vmServiceUri.toString(),
    if (error != null) 'error': error,
    if (cleanupPassed != null) 'cleanupPassed': cleanupPassed,
    if (cleanupDetail != null) 'cleanupDetail': cleanupDetail,
    if (metadata.isNotEmpty) 'metadata': metadata,
    if (suiteResult != null) 'loginSuite': suiteResult!.toJson(),
  };
}

/// Executes login & terminal configuration actions via DriverEngine against a running PenguinPOS instance.
class PenguinPosLoginRunner {
  /// Executes the configured rows independently, preserving their order and
  /// continuing after an ordinary case failure.
  Future<LoginRunResult> runConfiguredCases(
    List<LoginTestCaseDefinition> definitions, {
    required Uri vmServiceUri,
    Duration timeout = const Duration(seconds: 45),
    Driver? driverEngine,
    TextInputMode mode = TextInputMode.driverDirect,
    void Function(ExecutionEvent event)? onExecutionEvent,
    void Function(String scenarioName)? onScenarioCompleted,
    ApiTraceCollector? telemetryCollector,
    QaTestNoticeDisplayMode noticeDisplayMode =
        QaTestNoticeDisplayMode.warningsAndErrors,
  }) async {
    final startedAt = DateTime.now();
    final results = <LoginTestCaseResult>[];
    final activeDriver = driverEngine ?? DriverEngine();
    var driverConnected = false;
    var wasAppClosed = false;

    try {
      for (final definition in definitions.where(
        (caseItem) => caseItem.enabled,
      )) {
        final caseStarted = DateTime.now();
        final scenario = LoginScenario(
          id: definition.id,
          name: definition.name,
          loginId: definition.username,
          password: definition.password,
          unlockPin: definition.pin.isEmpty ? null : definition.pin,
        );
        final blocks = <AutomationBlock>[
          EnsureLoggedOutBlock(),
          if (definition.expectedResult ==
              LoginExpectedResult.requiredFieldValidation)
            if (definition.username.isEmpty && definition.password.isEmpty)
              ValidateEmptyCredentialsBlock()
            else
              ValidatePartialCredentialsBlock(
                id: definition.id,
                name: definition.name,
                username: definition.username,
                password: definition.password,
                mode: mode,
              )
          else if (definition.expectedResult ==
              LoginExpectedResult.authenticationRejected)
            ValidateInvalidCredentialsBlock(
              mode: mode,
              username: definition.username,
              password: definition.password,
            )
          else ...<AutomationBlock>[
            PerformLoginBlock(scenario: scenario, mode: mode),
            SelectTerminalBlock(scenario: scenario),
            VerifyHomeScreenBlock(scenario: scenario),
          ],
        ];
        final result = await PipelineRunner().runPipeline(
          blocks: blocks,
          cleanupBlocks: <AutomationBlock>[EnsureLoggedOutBlock()],
          vmServiceUri: vmServiceUri,
          driver: activeDriver,
          timeout: timeout,
          onExecutionEvent: onExecutionEvent,
          onScenarioCompleted: onScenarioCompleted,
          telemetryCollector: telemetryCollector,
          noticeDisplayMode: noticeDisplayMode,
          connectDriver: !driverConnected,
          closeDriver: false,
          clearSnackBarsBeforeBlock: false,
          secretsToRedact: <String?>[
            definition.username,
            definition.password,
            definition.pin,
          ],
        );
        driverConnected = true;
        results.add(
          LoginTestCaseResult.fromDefinition(
            definition: definition,
            status: result.passed
                ? LoginTestCaseStatus.passed
                : LoginTestCaseStatus.failed,
            startedAt: caseStarted,
            finishedAt: DateTime.now(),
            failureReason: result.error,
          ),
        );
        if (result.passed) {
          onScenarioCompleted?.call(definition.name);
          onScenarioCompleted?.call(definition.id);
        }
        if (result.wasAppClosedByUser) {
          wasAppClosed = true;
          break;
        }
      }
    } finally {
      if (driverConnected) {
        await activeDriver.close();
      }
    }
    final suite = LoginSuiteResult(
      results: List<LoginTestCaseResult>.unmodifiable(results),
      startedAt: startedAt,
      finishedAt: DateTime.now(),
    );
    return LoginRunResult(
      passed: suite.passed,
      startedAt: startedAt,
      finishedAt: suite.finishedAt,
      scenariosExecuted: results.map((result) => result.testCaseId).toList(),
      vmServiceUri: vmServiceUri,
      error: suite.failedCount == 0 ? null : suite.results.first.failureReason,
      wasAppClosedByUser: wasAppClosed,
      suiteResult: suite,
    );
  }

  /// Runs the full sequential login suite using composable automation blocks:
  /// 0. Preflight contract check
  /// 1. Session reset back to Login screen
  /// 2. Empty credentials click validation
  /// 3. Empty username with a password
  /// 4. Username with an empty password
  /// 5. Invalid credentials authentication failure check
  /// 6. Valid credentials submission
  /// 7. Terminal selection continue button tap
  /// 8. Home screen navigation verification
  /// 9. Post-login logout cleanup back to LoginScreen
  Future<LoginRunResult> runFullSequence(
    LoginScenario scenario, {
    required Uri vmServiceUri,
    Duration timeout = const Duration(seconds: 45),
    Driver? driverEngine,
    TextInputMode mode = TextInputMode.driverDirect,
    void Function(ExecutionEvent event)? onExecutionEvent,
    void Function(String scenarioName)? onScenarioCompleted,
    ApiTraceCollector? telemetryCollector,
    QaTestNoticeDisplayMode noticeDisplayMode =
        QaTestNoticeDisplayMode.warningsAndErrors,
  }) async {
    final activeDriver = driverEngine ?? DriverEngine();

    // Mode-aware preflight contract verification check
    try {
      final operation = PosAutomationContract.verifyContract(
        activeDriver,
        mode: mode,
        timeout: timeout,
      );
      await (ExecutionCancellationScope.current?.race(operation) ?? operation);
    } on ExecutionCancelledException {
      rethrow;
    } catch (_) {
      // Proceed; contract check will also fail softly during execution if keys are absent
    }

    final pipeline = [
      EnsureLoggedOutBlock(),
      ValidateEmptyCredentialsBlock(),
      ValidatePartialCredentialsBlock(
        id: 'validate_empty_username',
        name: 'Username empty, password provided.',
        username: '',
        password: scenario.password,
        mode: mode,
      ),
      ValidatePartialCredentialsBlock(
        id: 'validate_empty_password',
        name: 'Username provided, password empty.',
        username: scenario.loginId,
        password: '',
        mode: mode,
      ),
      ValidateInvalidCredentialsBlock(mode: mode),
      PerformLoginBlock(scenario: scenario, mode: mode),
      SelectTerminalBlock(scenario: scenario),
      VerifyHomeScreenBlock(scenario: scenario),
    ];

    final runner = PipelineRunner();
    final res = await runner.runPipeline(
      blocks: pipeline,
      cleanupBlocks: [EnsureLoggedOutBlock()],
      vmServiceUri: vmServiceUri,
      driver: activeDriver,
      timeout: timeout,
      onExecutionEvent: onExecutionEvent,
      onScenarioCompleted: onScenarioCompleted,
      secretsToRedact: [
        scenario.loginId,
        scenario.password,
        scenario.unlockPin,
      ],
      telemetryCollector: telemetryCollector,
      noticeDisplayMode: noticeDisplayMode,
    );

    return LoginRunResult(
      passed: res.passed,
      startedAt: res.startedAt,
      finishedAt: res.finishedAt,
      scenariosExecuted: res.scenariosExecuted,
      vmServiceUri: res.vmServiceUri,
      error: res.error,
      cleanupPassed: res.cleanupPassed,
      cleanupDetail: res.cleanupDetail,
      wasAppClosedByUser: res.wasAppClosedByUser,
      metadata: res.metadata,
    );
  }

  /// Runs a single valid login scenario execution.
  Future<LoginRunResult> run(
    LoginScenario scenario, {
    required Uri vmServiceUri,
    Duration timeout = const Duration(seconds: 45),
    Driver? driverEngine,
    TextInputMode mode = TextInputMode.driverDirect,
    ApiTraceCollector? telemetryCollector,
    QaTestNoticeDisplayMode noticeDisplayMode =
        QaTestNoticeDisplayMode.milestonesAndErrors,
  }) async {
    final activeDriver = driverEngine ?? DriverEngine();

    final pipeline = [
      EnsureLoggedOutBlock(),
      PerformLoginBlock(scenario: scenario, mode: mode),
      SelectTerminalBlock(scenario: scenario),
      VerifyHomeScreenBlock(scenario: scenario),
    ];

    final runner = PipelineRunner();
    final res = await runner.runPipeline(
      blocks: pipeline,
      cleanupBlocks: [EnsureLoggedOutBlock()],
      vmServiceUri: vmServiceUri,
      driver: activeDriver,
      timeout: timeout,
      secretsToRedact: [
        scenario.loginId,
        scenario.password,
        scenario.unlockPin,
      ],
      telemetryCollector: telemetryCollector,
      noticeDisplayMode: noticeDisplayMode,
    );

    return LoginRunResult(
      passed: res.passed,
      startedAt: res.startedAt,
      finishedAt: res.finishedAt,
      scenariosExecuted: res.scenariosExecuted,
      vmServiceUri: res.vmServiceUri,
      error: res.error,
      cleanupPassed: res.cleanupPassed,
      cleanupDetail: res.cleanupDetail,
      wasAppClosedByUser: res.wasAppClosedByUser,
      metadata: res.metadata,
    );
  }
}
