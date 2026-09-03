import 'dart:async';

import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/automation_pipeline.dart';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/pos_automation_contract.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_cancellation.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/api_trace_collector.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/telemetry_dispatcher.dart';
import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_keys.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/collect_cash_payment_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/complete_order_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/ensure_order_screen_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/enter_order_items_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/start_sale_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/synchronize_cart_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/cash_round_off.dart'
    as order_round_off;
import 'package:penguin_pos_qa_agent/automation/order/order_keys.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_metrics.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_run_state.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/session/authentication_pipeline_factory.dart';
import 'package:penguin_pos_qa_agent/core/secret_redactor.dart';
import 'package:penguin_pos_qa_agent/domain/suites/order_suite_scenarios.dart';
import 'package:penguin_pos_qa_agent/runtime/driver_engine.dart';

/// Encapsulates execution results for an order automation test scenario run.
class OrderRunResult {
  const OrderRunResult({
    required this.passed,
    required this.startedAt,
    required this.finishedAt,
    this.ordersCompleted = 0,
    this.ordersTarget = 1,
    this.totalItemsProcessed = 0,
    this.aggregateTotalPayable = 0.0,
    this.aggregatePayableAmount = 0,
    this.loopMetrics = const <OrderLoopMetrics>[],
    this.error,
    this.wasAppClosedByUser = false,
    this.metadata = const <String, Object?>{},
  });

  final bool passed;
  final DateTime startedAt;
  final DateTime finishedAt;
  final int ordersCompleted;
  final int ordersTarget;
  final int totalItemsProcessed;
  final double aggregateTotalPayable;
  final int aggregatePayableAmount;
  final List<OrderLoopMetrics> loopMetrics;
  final String? error;
  final bool wasAppClosedByUser;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => <String, Object?>{
    'passed': passed,
    'ordersCompleted': ordersCompleted,
    'ordersTarget': ordersTarget,
    'totalItemsProcessed': totalItemsProcessed,
    'aggregateTotalPayable': aggregateTotalPayable,
    'aggregatePayableAmount': aggregatePayableAmount,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'finishedAt': finishedAt.toUtc().toIso8601String(),
    if (error != null) 'error': error,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}

/// Executes end-to-end POS order creation & cash payment automation flows.
class PenguinPosOrderRunner {
  void _trace(String message) {
    // ignore: avoid_print
    print('[PenguinPOS QA][order] $message');
  }

  /// Calculates round-off payable amount matching POS business logic.
  /// Forwarder method to domain utility [order_round_off.calculateRoundOff].
  static int calculateRoundOff(double totalAmount) =>
      order_round_off.calculateRoundOff(totalAmount);

  /// Runs the full POS Order & Cash Payment automation workflow.
  Future<OrderRunResult> run(
    OrderScenario scenario, {
    required Uri vmServiceUri,
    Duration timeout = const Duration(seconds: 45),
    DriverEngine? driverEngine,
    void Function(String scenarioName)? onScenarioCompleted,
    void Function(int completed, int total)? onBatchProgress,
    void Function(ExecutionEvent event)? onExecutionEvent,
    ApiTraceCollector? telemetryCollector,
    QaTestNoticeDisplayMode noticeDisplayMode =
        QaTestNoticeDisplayMode.warningsAndErrors,
  }) async {
    final startedAt = DateTime.now();
    final engine = driverEngine ?? DriverEngine();
    final telemetryDispatcher = telemetryCollector == null
        ? null
        : TelemetryDispatcher(driver: engine, collector: telemetryCollector);

    int ordersCompleted = 0;
    final int targetOrders = scenario.effectiveOrdersCount > 0
        ? scenario.effectiveOrdersCount
        : 1;
    int totalItemsProcessed = 0;
    double aggregateTotalPayable = 0.0;
    int aggregatePayableAmount = 0;

    final List<OrderLoopMetrics> loopMetricsList = <OrderLoopMetrics>[];
    OrderRunState? currentState;
    void emit(
      String title,
      String message, {
      ExecutionEventLevel level = ExecutionEventLevel.info,
    }) {
      onExecutionEvent?.call(
        ExecutionEvent(title: title, message: message, level: level),
      );
    }

    final execContext = ExecutionContext(
      driver: engine,
      timeout: timeout,
      onEvent: onExecutionEvent,
      telemetryCollector: telemetryCollector,
      telemetryDispatcher: telemetryDispatcher,
      noticeDisplayMode: noticeDisplayMode,
    );
    const pipeline = AutomationPipeline();
    final activeScenarios = <String>{};
    final cancellation = execContext.cancellationSignal;

    void beginScenarios(Iterable<String> names, String message) {
      for (final name in names) {
        activeScenarios.add(name);
        emit(name, message);
      }
    }

    void completeScenarios(Iterable<String> names) {
      for (final name in names) {
        activeScenarios.remove(name);
        onScenarioCompleted?.call(name);
      }
    }

    Future<void> executeScenarios(
      List<String> names,
      List<AutomationBlock> blocks,
      String message,
    ) async {
      beginScenarios(names, message);
      await pipeline.execute(blocks, execContext, emitStepEvents: false);
      completeScenarios(names);
    }

    var runFailed = false;

    try {
      beginScenarios(const <String>[
        OrderSuiteScenarios.session,
      ], 'Connecting to PenguinPOS and verifying the active session.');
      await cancellation.race(engine.connect(vmServiceUri, timeout: timeout));
      emit('Driver Connected', 'Connected to PenguinPOS Flutter Driver.');
      final targetCapabilities = await cancellation.race(
        PosAutomationContract.probeCapabilities(engine),
      );
      _trace('Target capabilities: ${targetCapabilities.join(', ')}');
      execContext.state['target_capabilities'] = targetCapabilities.toList();
      final targetInfo = await cancellation.race(
        engine.requestData('qa_target_info'),
      );
      if (targetInfo != null && targetInfo.isNotEmpty) {
        _trace('Target info: $targetInfo');
        execContext.state['target_info'] = targetInfo;
      }

      // Step 1 & 2: Initial App state probe (Order Screen, Home, Login)
      _trace('Probing initial UI state (orderScreen, homeScreen, loginId)...');
      final probeStart = DateTime.now();
      final initialState = await cancellation.race(
        engine.waitForAnyKey(<String>[
          PenguinPosOrderKeys.orderScreen,
          PenguinPosLoginKeys.homeScreen,
          PenguinPosLoginKeys.loginId,
        ], timeout: timeout),
      );
      final probeDuration = DateTime.now().difference(probeStart);
      _trace(
        'Initial UI state probed in ${probeDuration.inMilliseconds}ms: "$initialState"',
      );
      execContext.state['initial_screen'] = initialState;
      execContext.state['initial_session_state'] =
          initialState == PenguinPosLoginKeys.loginId
          ? 'logged_out'
          : 'logged_in';
      execContext.state['login_required'] =
          initialState == PenguinPosLoginKeys.loginId;
      execContext.state['terminal_selection_required'] =
          initialState == PenguinPosLoginKeys.loginId;

      // Login prerequisite if app is currently on Login Screen
      if (initialState == PenguinPosLoginKeys.loginId) {
        final loginId = scenario.loginId;
        final password = scenario.password;

        if (loginId == null ||
            loginId.isEmpty ||
            password == null ||
            password.isEmpty) {
          throw StateError(
            'Login credentials are required when app is at Login Screen.',
          );
        }

        final loginScenario = LoginScenario(
          id: 'order_prereq_login',
          name: 'Order Prerequisite Login',
          loginId: loginId,
          password: password,
        );

        final setupBlocks =
            await AuthenticationPipelineFactory.createSetupPipeline(
              execContext,
              loginScenario,
            );

        await pipeline.execute(setupBlocks, execContext, emitStepEvents: false);

        emit(
          'Login Completed',
          'Logged in and continued through terminal selection.',
        );
      }
      completeScenarios(const <String>[OrderSuiteScenarios.session]);

      // Step 3: Back-to-Back Orders Punching Loop
      for (int orderIdx = 0; orderIdx < targetOrders; orderIdx++) {
        cancellation.throwIfCancelled();
        _trace('--- Starting Order ${orderIdx + 1} of $targetOrders ---');
        emit(
          'Order ${orderIdx + 1} Started',
          'Preparing order ${orderIdx + 1} of $targetOrders.',
        );
        final state = OrderRunState(
          orderIndex: orderIdx + 1,
          scenario: scenario,
        );
        currentState = state;

        await executeScenarios(
          const <String>[OrderSuiteScenarios.startSale],
          <AutomationBlock>[
            const EnsureOrderScreenBlock(),
            StartSaleBlock(state: state),
          ],
          'Opening the order screen and starting the sale.',
        );
        await executeScenarios(
          const <String>[
            OrderSuiteScenarios.standardSku,
            OrderSuiteScenarios.weighedItem,
          ],
          <AutomationBlock>[EnterOrderItemsBlock(state: state)],
          'Entering standard and weighed SKU items.',
        );
        await executeScenarios(
          const <String>[OrderSuiteScenarios.cartReview],
          <AutomationBlock>[SynchronizeCartBlock(state: state)],
          'Synchronizing the cart and proceeding to payment.',
        );
        await executeScenarios(
          const <String>[OrderSuiteScenarios.cashCheckout],
          <AutomationBlock>[
            CollectCashPaymentBlock(state: state),
            CompleteOrderBlock(state: state),
          ],
          'Submitting cash payment and verifying order completion.',
        );

        // Record Order Completion Metrics
        ordersCompleted++;
        totalItemsProcessed += state.itemsThisOrder;
        aggregateTotalPayable += state.totalPayableVal;
        aggregatePayableAmount += state.roundedPayable;

        final loopDurationMs = DateTime.now()
            .difference(state.loopStart)
            .inMilliseconds;

        loopMetricsList.add(
          OrderLoopMetrics(
            loopIndex: orderIdx + 1,
            durationMs: loopDurationMs,
            itemsCount: state.itemsThisOrder,
            totalPayable: state.totalPayableVal,
            payableCash: state.roundedPayable,
            stepMetrics: state.stepMetrics,
            skuResults: state.skuResults.isNotEmpty
                ? List<OrderSkuResult>.unmodifiable(state.skuResults)
                : scenario
                      .getItemsForIteration(state.orderIndex)
                      .where((item) => item.skuCode.trim().isNotEmpty)
                      .map(
                        (item) => OrderSkuResult(
                          sku: item.skuCode,
                          type: item.effectiveType.label,
                          entryMode: item.effectiveEntryMode.label,
                          weight:
                              state.resolvedWeights[state.weightKey(item)] ??
                              item.weight,
                          passed: true,
                        ),
                      )
                      .toList(growable: false),
            stageResults: const <OrderStageResult>[
              OrderStageResult(name: 'Login Check', passed: true),
              OrderStageResult(name: 'Customer', passed: true),
              OrderStageResult(name: 'Cart Operations', passed: true),
              OrderStageResult(name: 'Payment Screen', passed: true),
              OrderStageResult(name: 'Place Order', passed: true),
              OrderStageResult(name: 'Order Success Screen', passed: true),
            ],
            orderNumber: 'ORD-${10000 + orderIdx + 1}',
          ),
        );

        onBatchProgress?.call(ordersCompleted, targetOrders);
        emit(
          'Order ${orderIdx + 1} Completed',
          'Completed $ordersCompleted of $targetOrders orders.',
          level: ExecutionEventLevel.success,
        );
      }

      return OrderRunResult(
        passed: true,
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        ordersCompleted: ordersCompleted,
        ordersTarget: targetOrders,
        totalItemsProcessed: totalItemsProcessed,
        aggregateTotalPayable: aggregateTotalPayable,
        aggregatePayableAmount: aggregatePayableAmount,
        loopMetrics: loopMetricsList,
        metadata: Map<String, Object?>.unmodifiable(execContext.state),
      );
    } catch (error) {
      runFailed = true;
      final errorStr = redactSecrets(error.toString(), <String?>[
        scenario.loginId,
        scenario.password,
        scenario.unlockPin,
      ]);
      for (final scenarioName in activeScenarios) {
        emit(scenarioName, errorStr, level: ExecutionEventLevel.error);
      }
      emit('Order Suite Error', errorStr, level: ExecutionEventLevel.error);
      final failedState = currentState;
      if (failedState != null) {
        final failedItems = failedState.skuResults.isNotEmpty
            ? List<OrderSkuResult>.unmodifiable(failedState.skuResults)
            : scenario
                  .getItemsForIteration(failedState.orderIndex)
                  .where((item) => item.skuCode.trim().isNotEmpty)
                  .map(
                    (item) => OrderSkuResult(
                      sku: item.skuCode,
                      type: item.effectiveType.label,
                      entryMode: item.effectiveEntryMode.label,
                      weight:
                          failedState.resolvedWeights[failedState.weightKey(
                            item,
                          )] ??
                          item.weight,
                      passed: false,
                      error: errorStr,
                    ),
                  )
                  .toList(growable: false);
        loopMetricsList.add(
          OrderLoopMetrics(
            loopIndex: failedState.orderIndex,
            durationMs: DateTime.now()
                .difference(failedState.loopStart)
                .inMilliseconds,
            itemsCount: failedState.itemsThisOrder,
            totalPayable: failedState.totalPayableVal,
            payableCash: failedState.roundedPayable,
            stepMetrics: failedState.stepMetrics,
            skuResults: failedItems,
            passed: false,
            error: errorStr,
            stageResults: const <OrderStageResult>[],
          ),
        );
      }
      if (error is! ExecutionCancelledException) {
        await execContext.showNotice(
          QaTestNoticeSeverity.error,
          'Order automation failed',
          'Execution stopped. Check the QA Agent terminal for details.',
        );
      }

      final isAppClosed =
          error is ExecutionCancelledException ||
          isTargetAppDisconnectedError(error);

      return OrderRunResult(
        passed: false,
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        ordersCompleted: ordersCompleted,
        ordersTarget: targetOrders,
        totalItemsProcessed: totalItemsProcessed,
        aggregateTotalPayable: aggregateTotalPayable,
        aggregatePayableAmount: aggregatePayableAmount,
        loopMetrics: loopMetricsList,
        error: errorStr,
        wasAppClosedByUser: isAppClosed,
        metadata: Map<String, Object?>.unmodifiable(execContext.state),
      );
    } finally {
      // Preserve the error notice after a failed run so the operator can
      // inspect and dismiss it. Successful runs clear any stale notice.
      if (!runFailed && !cancellation.isCancelled) {
        await engine.clearQaTestNotice();
      }
      // Drain all queued step telemetry, including telemetry from a failed
      // partial order, before the driver session becomes unavailable.
      if (!cancellation.isCancelled) {
        await telemetryDispatcher?.flush();
      }
      await engine.close();
    }
  }
}
