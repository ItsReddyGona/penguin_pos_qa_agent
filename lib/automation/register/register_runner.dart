import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/runtime/driver_engine.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/api_trace_collector.dart';
import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_keys.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_keys.dart';
import 'package:penguin_pos_qa_agent/automation/register/blocks/close_register_block.dart';
import 'package:penguin_pos_qa_agent/automation/register/blocks/open_register_block.dart';
import 'package:penguin_pos_qa_agent/automation/register/register_keys.dart';
import 'package:penguin_pos_qa_agent/automation/register/register_scenario.dart';

class RegisterRunResult {
  const RegisterRunResult({
    required this.startedAt,
    required this.finishedAt,
    required this.passed,
    this.error,
    this.floatAmount = 0,
    this.totalAmount = 0,
    this.requiresReconciliation = false,
  });

  final DateTime startedAt;
  final DateTime finishedAt;
  final bool passed;
  final String? error;
  final int floatAmount;
  final int totalAmount;
  final bool requiresReconciliation;
}

/// Executes the Register test suites against a running PenguinPOS instance.
class RegisterRunner {
  const RegisterRunner({this.driverEngine});

  final Driver? driverEngine;

  Future<RegisterRunResult> run(
    RegisterScenario scenario, {
    required Uri vmServiceUri,
    Duration timeout = const Duration(seconds: 45),
    void Function(ExecutionEvent event)? onExecutionEvent,
    void Function(String scenarioName)? onScenarioCompleted,
    ApiTraceCollector? telemetryCollector,
    QaTestNoticeDisplayMode noticeDisplayMode =
        QaTestNoticeDisplayMode.warningsAndErrors,
  }) async {
    final startedAt = DateTime.now();
    final engine = driverEngine ?? DriverEngine();

    final execContext = ExecutionContext(
      driver: engine,
      timeout: timeout,
      onEvent: onExecutionEvent,
      telemetryCollector: telemetryCollector,
      noticeDisplayMode: noticeDisplayMode,
    );

    try {
      await engine.connect(vmServiceUri, timeout: timeout);
      execContext.emit(
        'Driver Connected',
        'Connected to PenguinPOS Flutter Driver.',
      );

      // Probe current UI state
      final currentScreen = await engine.waitForAnyKey(<String>[
        PenguinPosRegisterKeys.registerScreen,
        PenguinPosOrderKeys.orderScreen,
        PenguinPosLoginKeys.homeScreen,
      ], timeout: timeout);

      if (currentScreen != PenguinPosRegisterKeys.registerScreen) {
        // If on Order screen and register is closed
        final isClosedOnOrder = await engine.hasKey(
          PenguinPosOrderKeys.orderOpenRegister,
          timeout: const Duration(seconds: 2),
        );
        if (isClosedOnOrder) {
          execContext.emit(
            'Navigating to Register',
            'Tapping Open Register button on Order screen.',
          );
          await engine.tap(PenguinPosOrderKeys.orderOpenRegister);
        } else {
          // Check if register is already open on Order screen
          final isAlreadyOpen = await engine.hasKey(
            PenguinPosOrderKeys.orderSaleStart,
            timeout: const Duration(seconds: 2),
          );
          if (isAlreadyOpen) {
            execContext.emit(
              'Register Already Open',
              'Cash register is already open on Order screen.',
            );
            onScenarioCompleted?.call(scenario.name);
            return RegisterRunResult(
              startedAt: startedAt,
              finishedAt: DateTime.now(),
              passed: true,
              floatAmount: scenario.effectiveFloatAmount,
            );
          }

          // Navigate via home tab
          await engine.waitFor(
            PenguinPosOrderKeys.homeRegisterTab,
            timeout: timeout,
          );
          await engine.tap(PenguinPosOrderKeys.homeRegisterTab);
        }
      }

      // Execute OpenRegisterBlock
      final block = OpenRegisterBlock(
        openingFloatAmount: scenario.openingFloatAmount,
      );
      await block.execute(execContext);

      onScenarioCompleted?.call(scenario.name);
      return RegisterRunResult(
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        passed: true,
        floatAmount: scenario.effectiveFloatAmount,
      );
    } catch (e) {
      final isRecon = e is ReconciliationRequiredException;
      final errorMessage = isRecon ? e.message : e.toString();
      execContext.emit(
        isRecon ? 'Reconciliation Required' : 'Open Register Suite Failed',
        errorMessage,
        level: ExecutionEventLevel.error,
      );
      return RegisterRunResult(
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        passed: false,
        error: errorMessage,
        floatAmount: scenario.effectiveFloatAmount,
        requiresReconciliation: isRecon,
      );
    }
  }

  Future<RegisterRunResult> runClose(
    RegisterScenario scenario, {
    required Uri vmServiceUri,
    Duration timeout = const Duration(seconds: 45),
    void Function(ExecutionEvent event)? onExecutionEvent,
    void Function(String scenarioName)? onScenarioCompleted,
    ApiTraceCollector? telemetryCollector,
    QaTestNoticeDisplayMode noticeDisplayMode =
        QaTestNoticeDisplayMode.warningsAndErrors,
  }) async {
    final startedAt = DateTime.now();
    final engine = driverEngine ?? DriverEngine();

    final execContext = ExecutionContext(
      driver: engine,
      timeout: timeout,
      onEvent: onExecutionEvent,
      telemetryCollector: telemetryCollector,
      noticeDisplayMode: noticeDisplayMode,
    );

    try {
      await engine.connect(vmServiceUri, timeout: timeout);
      execContext.emit(
        'Driver Connected',
        'Connected to PenguinPOS Flutter Driver.',
      );

      final block = CloseRegisterBlock(
        totalAmount: scenario.closeTotalAmount,
        closingFloatAmount: 0.0,
      );
      await block.execute(execContext);

      onScenarioCompleted?.call(scenario.name);
      return RegisterRunResult(
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        passed: true,
        totalAmount: scenario.effectiveCloseTotalAmount,
      );
    } catch (e) {
      final errorMessage = e.toString();
      execContext.emit(
        'Close Register Suite Failed',
        errorMessage,
        level: ExecutionEventLevel.error,
      );
      return RegisterRunResult(
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        passed: false,
        error: errorMessage,
        totalAmount: scenario.effectiveCloseTotalAmount,
      );
    }
  }
}
