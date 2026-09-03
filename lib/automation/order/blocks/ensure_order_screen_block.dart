import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_keys.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_keys.dart';

/// Verifies POS is on the Order Screen, navigating from Home tab if necessary.
class EnsureOrderScreenBlock implements AutomationBlock {
  const EnsureOrderScreenBlock();

  @override
  String get id => 'ensure_order_screen';

  @override
  String get name => 'Ensure Order Screen';

  @override
  StepNotice? get notice => const StepNotice(
    'Starting order testing',
    'Opening the order screen.',
    isMilestone: true,
  );

  @override
  Future<void> execute(ExecutionContext context) async {
    final driver = context.driver;
    final timeout = context.timeout;

    final isOrderLayoutActive = await driver.hasKey(
      PenguinPosOrderKeys.orderScreen,
      timeout: const Duration(seconds: 2),
    );

    if (!isOrderLayoutActive) {
      await driver.waitFor(PenguinPosLoginKeys.homeScreen, timeout: timeout);
      await driver.waitFor(PenguinPosOrderKeys.homeOrderTab, timeout: timeout);
      await driver.tap(PenguinPosOrderKeys.homeOrderTab);
    }

    await driver.waitFor(PenguinPosOrderKeys.orderScreen, timeout: timeout);
  }
}
