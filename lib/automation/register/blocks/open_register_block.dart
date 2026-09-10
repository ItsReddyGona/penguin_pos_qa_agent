import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_keys.dart';
import 'package:penguin_pos_qa_agent/automation/register/register_keys.dart';

/// Automates entering opening float cash and submitting the Open Register form.
class OpenRegisterBlock implements AutomationBlock {
  const OpenRegisterBlock({this.openingFloatAmount = 0.0});

  final double openingFloatAmount;

  @override
  String get id => 'open_register';

  @override
  String get name => 'Open Cash Register';

  @override
  StepNotice? get notice => const StepNotice(
    'Opening register',
    'Submitting opening float cash.',
    isMilestone: true,
  );

  @override
  Future<void> execute(ExecutionContext context) async {
    final driver = context.driver;
    final timeout = context.timeout;
    final floatInt = openingFloatAmount.clamp(0.0, 5000.0).toInt();

    // 1. Wait for Register Screen & Opening Float Input Field
    await driver.waitForAnyKey(<String>[
      PenguinPosRegisterKeys.registerScreen,
      PenguinPosRegisterKeys.inputOpeningFloat,
    ], timeout: timeout);

    await driver.waitFor(
      PenguinPosRegisterKeys.inputOpeningFloat,
      timeout: timeout,
    );

    context.emit(
      'Entering Opening Float',
      'Entering opening float amount of ₹$floatInt.',
    );

    // 2. Focus and enter float amount
    await driver.tap(PenguinPosRegisterKeys.inputOpeningFloat);
    await driver.enterText(
      PenguinPosRegisterKeys.inputOpeningFloat,
      floatInt.toString(),
    );

    // 3. Submit opening register (wait until enabled, tap, and retry until transition)
    await driver.waitFor(
      PenguinPosRegisterKeys.registerSubmit,
      timeout: timeout,
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final tapped = await driver.tryTapKey(
      PenguinPosRegisterKeys.registerSubmit,
      timeout: const Duration(milliseconds: 500),
    );
    if (!tapped) {
      await driver.tryTapText(
        'Open Register',
        timeout: const Duration(milliseconds: 300),
      );
    }

    final submitStopwatch = Stopwatch()..start();
    var transitioned = false;
    String? nextTarget;

    while (submitStopwatch.elapsed < timeout) {
      final currentKey = await driver
          .waitForAnyKey(<String>[
            PenguinPosOrderKeys.orderScreen,
            PenguinPosOrderKeys.orderSaleStart,
            PenguinPosRegisterKeys.errorDialogOk,
            PenguinPosRegisterKeys.registerSubmit,
          ], timeout: const Duration(seconds: 2))
          .catchError((_) => '');

      if (currentKey.isNotEmpty &&
          currentKey != PenguinPosRegisterKeys.registerSubmit) {
        transitioned = true;
        nextTarget = currentKey;
        break;
      }

      await driver.tryTapKey(
        PenguinPosRegisterKeys.registerSubmit,
        timeout: const Duration(milliseconds: 500),
      );
      await driver.tryTapText(
        'Open Register',
        timeout: const Duration(milliseconds: 300),
      );

      await Future<void>.delayed(const Duration(milliseconds: 800));
    }

    if (!transitioned) {
      nextTarget = await driver.waitForAnyKey(<String>[
        PenguinPosOrderKeys.orderScreen,
        PenguinPosOrderKeys.orderSaleStart,
        PenguinPosRegisterKeys.errorDialogOk,
      ], timeout: timeout);
    }

    if (nextTarget == PenguinPosRegisterKeys.errorDialogOk) {
      context.emit(
        'Reconciliation Required',
        'Register cannot be reopened until reconciliation is completed. Dismissing dialog.',
        level: ExecutionEventLevel.error,
      );

      // Click on the OK button
      final okTapped = await driver.tryTapKey(
        PenguinPosRegisterKeys.errorDialogOk,
      );
      if (!okTapped) {
        await driver.tryTapText('OK');
      }

      await Future<void>.delayed(const Duration(milliseconds: 300));

      throw const ReconciliationRequiredException(
        'Complete the Reconciliation to open New Register',
      );
    }

    context.emit(
      'Register Opened',
      'Register opened successfully with opening float ₹$floatInt.',
    );
  }
}

/// Thrown when PenguinPOS reports that the register cannot be reopened
/// because previous register reconciliation is pending.
class ReconciliationRequiredException implements Exception {
  const ReconciliationRequiredException([
    this.message = 'Complete the Reconciliation to open New Register',
  ]);

  final String message;

  @override
  String toString() => message;
}
