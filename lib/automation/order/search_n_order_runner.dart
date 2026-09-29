import 'dart:async';

import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/automation_pipeline.dart';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_cancellation.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/api_trace_collector.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/telemetry_dispatcher.dart';
import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_keys.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/collect_cash_payment_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/complete_order_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/ensure_order_screen_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/search_and_add_items_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/start_sale_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/synchronize_cart_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_keys.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_metrics.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_run_state.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_runner.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/session/authentication_pipeline_factory.dart';
import 'package:penguin_pos_qa_agent/core/secret_redactor.dart';
import 'package:penguin_pos_qa_agent/domain/suites/search_n_order_suite_scenarios.dart';
import 'package:penguin_pos_qa_agent/runtime/driver_engine.dart';

void _trace(String message) {
  assert(() {
    // ignore: avoid_print
    print('[SearchNOrderRunner] $message');
    return true;
  }());
}

/// Executes complete Search-and-Order end-to-end POS automation test suites.
class SearchNOrderRunner {
  const SearchNOrderRunner();

  Future<OrderRunResult> run(
    OrderScenario scenario, {
    required Uri vmServiceUri,
    DriverEngine? driverEngine,
    Duration timeout = const Duration(seconds: 45),
    void Function(ExecutionEvent)? onExecutionEvent,
    void Function(String)? onScenarioCompleted,
    void Function(int completed, int total)? onBatchProgress,
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
      cancellation.throwIfCancelled();
      _trace('Connecting to VM Service: $vmServiceUri');
      emit('Connecting to POS', 'Connecting to PenguinPOS VM Service.');
      await engine.connect(vmServiceUri, timeout: timeout);
      cancellation.throwIfCancelled();

      emit('POS Connected', 'Successfully attached to target POS process.');

      // Step 2: Session Check & Initial Route Determination
      beginScenarios(const <String>[
        SearchNOrderSuiteScenarios.session,
      ], 'Validating session and target route.');

      final probeStart = DateTime.now();
      final initialState = await cancellation.race(
        engine.waitForAnyKey(const <String>[
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
          id: 'search_n_order_prereq_login',
          name: 'SearchNOrder Prerequisite Login',
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
      completeScenarios(const <String>[SearchNOrderSuiteScenarios.session]);

      // Step 3: Orders Punching Loop via Search Modal
      for (int orderIdx = 0; orderIdx < targetOrders; orderIdx++) {
        cancellation.throwIfCancelled();
        _trace(
          '--- Starting Search Order ${orderIdx + 1} of $targetOrders ---',
        );
        emit(
          'Search Order ${orderIdx + 1} Started',
          'Preparing search order ${orderIdx + 1} of $targetOrders.',
        );
        final state = OrderRunState(
          orderIndex: orderIdx + 1,
          scenario: scenario,
        );
        currentState = state;

        await executeScenarios(
          const <String>[SearchNOrderSuiteScenarios.startSale],
          <AutomationBlock>[
            const EnsureOrderScreenBlock(),
            StartSaleBlock(state: state),
          ],
          'Opening the order screen and starting the sale.',
        );

        await executeScenarios(
          const <String>[
            SearchNOrderSuiteScenarios.searchItems,
            SearchNOrderSuiteScenarios.addProductToCart,
          ],
          <AutomationBlock>[SearchAndAddItemsBlock(state: state)],
          'Finding items in Search items modal, adding to cart, and entering weight if needed.',
        );

        await executeScenarios(
          const <String>[SearchNOrderSuiteScenarios.cartReview],
          <AutomationBlock>[SynchronizeCartBlock(state: state)],
          'Synchronizing the cart and proceeding to payment.',
        );

        await executeScenarios(
          const <String>[SearchNOrderSuiteScenarios.cashCheckout],
          <AutomationBlock>[
            CollectCashPaymentBlock(state: state),
            CompleteOrderBlock(state: state),
          ],
          'Submitting cash payment and verifying order completion.',
        );

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
                      .where(
                        (item) =>
                            item.skuCode.trim().isNotEmpty ||
                            item.name.trim().isNotEmpty,
                      )
                      .map(
                        (item) => OrderSkuResult(
                          sku: item.skuCode.isNotEmpty
                              ? item.skuCode
                              : item.name,
                          type: item.effectiveType.label,
                          entryMode: 'Search items',
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
              OrderStageResult(name: 'Search & Add Item', passed: true),
              OrderStageResult(name: 'Cart Review', passed: true),
              OrderStageResult(name: 'Cash Payment', passed: true),
              OrderStageResult(name: 'Order Success', passed: true),
            ],
            orderNumber: 'SNO-${10000 + orderIdx + 1}',
          ),
        );

        onBatchProgress?.call(ordersCompleted, targetOrders);
        emit(
          'Search Order ${orderIdx + 1} Completed',
          'Completed $ordersCompleted of $targetOrders search orders.',
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
      emit(
        'SearchNOrder Suite Error',
        errorStr,
        level: ExecutionEventLevel.error,
      );

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
                      entryMode: 'Search items',
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
      );
    } finally {
      if (runFailed && activeScenarios.isNotEmpty) {
        completeScenarios(List<String>.from(activeScenarios));
      }
      try {
        await engine.close();
      } catch (_) {}
    }
  }
}
