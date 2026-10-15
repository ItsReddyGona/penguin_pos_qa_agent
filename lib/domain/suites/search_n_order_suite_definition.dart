import 'package:penguin_pos_qa_agent/application/execution/qa_execution_coordinator.dart';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/order/search_n_order_runner.dart';
import 'package:penguin_pos_qa_agent/domain/plan/execution_plan.dart';
import 'package:penguin_pos_qa_agent/domain/suites/qa_suite_definition.dart';
import 'package:penguin_pos_qa_agent/domain/suites/search_n_order_suite_scenarios.dart';
import 'package:penguin_pos_qa_agent/runtime/driver_engine.dart';

/// Test suite definition for SearchNOrder automation.
class SearchNOrderSuiteDefinition extends QaSuiteDefinition {
  const SearchNOrderSuiteDefinition({this.runner = const SearchNOrderRunner()});

  final SearchNOrderRunner runner;

  @override
  QaSuiteId get id => QaSuiteId.searchNOrder;

  @override
  String get title => 'SearchNOrder';

  @override
  String get description =>
      'Searches items in catalog using Search items modal, adds products to cart with weight handling, and completes cash checkout.';

  @override
  bool get isImplemented => true;

  @override
  Future<ExecutionPlanResult> execute({
    required Driver driver,
    required Uri vmServiceUri,
    required PreparedExecution execution,
    ExecutionCallbacks callbacks = const ExecutionCallbacks(),
  }) async {
    final orderConfig = execution.plan.orderConfiguration;
    final scenario =
        execution.orderScenario ??
        (orderConfig != null
            ? OrderScenario(
                id: '${execution.profileId}_search_n_order',
                name: 'SearchNOrder Flow',
                loginId: execution.credentials.loginId,
                password: execution.credentials.password,
                unlockPin: execution.credentials.unlockPin,
                items: orderConfig.items,
                ordersCount: orderConfig.ordersCount,
                inputSourceMode: InputSourceMode.uiForm,
                uiCustomMode:
                    orderConfig.itemStrategy == ExecutionItemStrategy.perOrder
                    ? UiCustomMode.perIteration
                    : UiCustomMode.common,
                perIterationItems: orderConfig.perIterationItems,
                customerMode: orderConfig.customerMode,
                customerPhoneNumber: orderConfig.customerPhoneNumber,
                customerName: orderConfig.customerName,
                customerOtp: orderConfig.customerOtp,
              )
            : OrderScenario(
                id: 'search_n_order_flow',
                name: 'SearchNOrder Flow',
                items: const <OrderItem>[],
                loginId: execution.credentials.loginId,
                password: execution.credentials.password,
                unlockPin: execution.credentials.unlockPin,
              ));

    final completedScenarios = <String>[];
    void scenarioCompleted(String scenarioName) {
      if (!completedScenarios.contains(scenarioName)) {
        completedScenarios.add(scenarioName);
      }
      callbacks.onScenarioCompleted?.call(scenarioName);
    }

    final result = await runner.run(
      scenario,
      vmServiceUri: vmServiceUri,
      driverEngine: driver is DriverEngine ? driver : null,
      onExecutionEvent: callbacks.onEvent,
      onScenarioCompleted: scenarioCompleted,
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
      cancelled: false,
      wasAppClosedByUser: result.wasAppClosedByUser,
      completedScenarios: completedScenarios.isEmpty && result.passed
          ? SearchNOrderSuiteScenarios.all
          : completedScenarios,
      error: result.error,
      orderResult: result,
      orderSummary: ExecutionOrderSummary(
        ordersCompleted: result.ordersCompleted,
        ordersTarget: result.ordersTarget,
        totalItemsProcessed: result.totalItemsProcessed,
        aggregateTotalPayable: result.aggregateTotalPayable,
        aggregatePayableAmount: result.aggregatePayableAmount,
      ),
    );
  }
}
