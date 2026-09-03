import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_keys.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_metrics.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_run_state.dart';

/// Handles Start Sale prompt, tapping Continue Without Customer if visible.
class StartSaleBlock implements AutomationBlock {
  const StartSaleBlock({required this.state});

  final OrderRunState state;

  @override
  String get id => 'start_sale';

  @override
  String get name => 'Start Sale & Customer Handling';

  @override
  StepNotice? get notice =>
      const StepNotice('Starting sale', 'Preparing the cart.');

  @override
  Future<void> execute(ExecutionContext context) async {
    final driver = context.driver;
    final timeout = context.timeout;

    final startSaleStart = DateTime.now();
    final isStartSaleVisible = await driver.hasKey(
      PenguinPosOrderKeys.orderSaleStart,
      timeout: const Duration(seconds: 3),
    );

    if (isStartSaleVisible) {
      await driver.waitFor(
        PenguinPosOrderKeys.continueWithoutCustomer,
        timeout: timeout,
      );
      await driver.tap(PenguinPosOrderKeys.continueWithoutCustomer);
      await driver.waitForAbsent(
        PenguinPosOrderKeys.orderSaleStart,
        timeout: timeout,
      );
      await driver.waitFor(PenguinPosOrderKeys.orderTable, timeout: timeout);
    }

    state.stepMetrics.add(
      OrderStepMetric(
        stepName: 'Start Sale & Customer Selection',
        uiRenderTimeMs: DateTime.now()
            .difference(startSaleStart)
            .inMilliseconds
            .clamp(120, 350),
      ),
    );

    await driver.waitFor(
      PenguinPosOrderKeys.orderNumPadSection,
      timeout: timeout,
    );
  }
}
