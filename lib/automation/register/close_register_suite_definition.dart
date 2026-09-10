import 'package:penguin_pos_qa_agent/application/execution/qa_execution_coordinator.dart';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/register/register_runner.dart';
import 'package:penguin_pos_qa_agent/automation/register/register_scenario.dart';
import 'package:penguin_pos_qa_agent/domain/plan/execution_plan.dart';
import 'package:penguin_pos_qa_agent/domain/suites/qa_suite_definition.dart';

/// Test suite definition for cash register closing automation.
class CloseRegisterSuiteDefinition extends QaSuiteDefinition {
  const CloseRegisterSuiteDefinition({this.runner = const RegisterRunner()});

  final RegisterRunner runner;

  @override
  QaSuiteId get id => QaSuiteId.closeRegister;

  @override
  String get title => 'Close Register';

  @override
  String get description =>
      'Automates cash register closing with target total cash amount, payment modes verification, and denominations distribution.';

  @override
  bool get isImplemented => true;

  @override
  Future<ExecutionPlanResult> execute({
    required Driver driver,
    required Uri vmServiceUri,
    required PreparedExecution execution,
    ExecutionCallbacks callbacks = const ExecutionCallbacks(),
  }) async {
    final scenario =
        execution.registerScenario ??
        const RegisterScenario(
          id: 'close_register',
          name: 'Close Register Flow',
          closeTotalAmount: 1000.0,
        );

    final resolvedRunner = RegisterRunner(driverEngine: driver);
    final result = await resolvedRunner.runClose(
      scenario,
      vmServiceUri: vmServiceUri,
      onExecutionEvent: callbacks.onEvent,
      onScenarioCompleted: callbacks.onScenarioCompleted,
      telemetryCollector: execution.telemetryCollector,
      noticeDisplayMode: execution.noticeDisplayMode,
    );

    return ExecutionPlanResult(
      plan: execution.plan,
      profileId: execution.profileId,
      profileLabel: execution.profileLabel,
      startedAt: result.startedAt,
      finishedAt: result.finishedAt,
      passed: result.passed,
      error: result.error,
      completedScenarios: result.passed ? [scenario.name] : [],
      registerResult: result,
    );
  }
}
