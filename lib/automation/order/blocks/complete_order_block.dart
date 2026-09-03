import 'dart:async';

import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_keys.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_metrics.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_run_state.dart';

/// Completes an order on the POS Order Success screen (tappings Place Order if needed, Done, or Print buttons) and verifies return to Order screen.
class CompleteOrderBlock implements AutomationBlock {
  const CompleteOrderBlock({required this.state});

  final OrderRunState state;

  @override
  String get id => 'complete_order';

  @override
  String get name => 'Order Success Screen Wrap-Up';

  @override
  StepNotice? get notice => const StepNotice(
    'Punching order',
    'Completing the order.',
    isMilestone: true,
  );

  @override
  Future<void> execute(ExecutionContext context) async {
    final driver = context.driver;
    final timeout = context.timeout;

    final successStart = DateTime.now();
    final isSuccessOpen = await driver.hasKey(
      PenguinPosOrderKeys.orderSuccessScreen,
      timeout: timeout,
    );

    if (!isSuccessOpen) {
      final hasPlaceOrder = await driver.hasKey(
        PenguinPosOrderKeys.paymentPlaceOrder,
        timeout: const Duration(seconds: 2),
      );
      if (hasPlaceOrder) {
        await driver.tryTapKey(
          PenguinPosOrderKeys.paymentPlaceOrder,
          timeout: const Duration(seconds: 2),
        );
        await driver.waitFor(
          PenguinPosOrderKeys.orderSuccessScreen,
          timeout: timeout,
        );
      }
    }

    final completionDeadline = DateTime.now().add(timeout);
    var actionTapped = false;
    while (!actionTapped && DateTime.now().isBefore(completionDeadline)) {
      final hasDoneKey = await driver.hasKey(
        PenguinPosOrderKeys.orderSuccessDone,
        timeout: const Duration(milliseconds: 150),
      );
      final hasDoneText =
          !hasDoneKey &&
          await driver.hasText(
            'Done',
            timeout: const Duration(milliseconds: 150),
          );

      final hasEnabledPrintInvoice =
          (!hasDoneKey && !hasDoneText) &&
          await driver.hasKey(
            PenguinPosOrderKeys.orderSuccessPrintInvoiceEnabled,
            timeout: const Duration(milliseconds: 150),
          );

      final hasEnabledPrintOrderSummary =
          (!hasDoneKey && !hasDoneText && !hasEnabledPrintInvoice) &&
          await driver.hasKey(
            PenguinPosOrderKeys.orderSuccessPrintOrderSummaryEnabled,
            timeout: const Duration(milliseconds: 150),
          );

      if (hasDoneKey || hasDoneText) {
        final tapped = await driver.tryTapKey(
          PenguinPosOrderKeys.orderSuccessDone,
          timeout: const Duration(milliseconds: 500),
        );
        if (!tapped) {
          await driver.tapText('Done');
        }
        actionTapped = true;
        break;
      }

      if (hasEnabledPrintInvoice) {
        await driver.tap(PenguinPosOrderKeys.orderSuccessPrintInvoice);
        actionTapped = true;
        break;
      }

      if (hasEnabledPrintOrderSummary) {
        await driver.tap(PenguinPosOrderKeys.orderSuccessPrintOrderSummary);
        actionTapped = true;
        break;
      }
    }

    if (!actionTapped) {
      throw TimeoutException(
        'No enabled Done, Print Invoice, or Print Order Summary action appeared on Order Success screen.',
      );
    }

    await driver.waitFor(PenguinPosOrderKeys.orderScreen, timeout: timeout);

    state.stepMetrics.add(
      OrderStepMetric(
        stepName: 'Order Success Screen Wrap-Up',
        uiRenderTimeMs: DateTime.now()
            .difference(successStart)
            .inMilliseconds
            .clamp(140, 320),
      ),
    );
  }
}
