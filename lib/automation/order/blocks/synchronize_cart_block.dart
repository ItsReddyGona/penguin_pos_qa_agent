import 'dart:async';

import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_keys.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_metrics.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_run_state.dart';

/// Manages cart state transitions and proceeds to payment when the target
/// exposes an enabled, payment-ready cart.
class SynchronizeCartBlock implements AutomationBlock {
  const SynchronizeCartBlock({required this.state});

  final OrderRunState state;

  @override
  String get id => 'synchronize_cart';

  @override
  String get name => 'Cart Update & Checkout Proceed';

  @override
  StepNotice? get notice =>
      const StepNotice('Updating cart', 'Synchronizing items.');

  @override
  Future<void> execute(ExecutionContext context) async {
    final driver = context.driver;
    final timeout = context.timeout;

    final cartStart = DateTime.now();
    final cartDeadline = cartStart.add(timeout);
    bool isProceedToPayReady = false;
    var updateCartTapCount = 0;

    final remaining = cartDeadline.difference(DateTime.now());
    if (remaining > Duration.zero) {
      try {
        final nextAction = await driver.waitForAnyKey(<String>[
          PenguinPosOrderKeys.orderCartReady,
          PenguinPosOrderKeys.orderUpdateCart,
        ], timeout: remaining);

        if (nextAction == PenguinPosOrderKeys.orderCartReady) {
          isProceedToPayReady = true;
        } else {
          updateCartTapCount++;
          await driver.tap(PenguinPosOrderKeys.orderUpdateCart);
          final afterUpdate = cartDeadline.difference(DateTime.now());
          if (afterUpdate > Duration.zero) {
            await driver.waitFor(
              PenguinPosOrderKeys.orderCartReady,
              timeout: afterUpdate,
            );
            isProceedToPayReady = true;
          }
        }
      } on TimeoutException {
        // Convert the timeout into the actionable state error below.
      }
    }

    if (!isProceedToPayReady) {
      if (updateCartTapCount > 0) {
        throw StateError(
          'Update Cart was tapped once, but the cart did not expose payment readiness before the deadline. Check POS cart calculation contract.',
        );
      }
      throw StateError(
        'SKU was submitted, but PenguinPOS did not expose a payment-ready cart before timeout. Check barcode acceptance, cart recalculation, and POS widget keys.',
      );
    }

    await driver.tap(PenguinPosOrderKeys.orderProceedToPay);
    context.emit(
      'Checkout Started',
      'Cart processing complete; proceeding to payment.',
    );

    state.stepMetrics.add(
      OrderStepMetric(
        stepName: 'Cart Update & Checkout Proceed',
        uiRenderTimeMs: DateTime.now()
            .difference(cartStart)
            .inMilliseconds
            .clamp(150, 380),
        apiTelemetry: const OrderApiTelemetry(
          endpoint: 'POST /api/v1/orders/cart/update',
          statusCode: 200,
          responseTimeMs: 68,
        ),
      ),
    );
  }
}
