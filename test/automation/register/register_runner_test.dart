import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_keys.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_state_snapshot.dart';
import 'package:penguin_pos_qa_agent/automation/register/blocks/close_register_block.dart';
import 'package:penguin_pos_qa_agent/automation/register/blocks/open_register_block.dart';
import 'package:penguin_pos_qa_agent/automation/register/register_keys.dart';
import 'package:penguin_pos_qa_agent/automation/register/register_runner.dart';
import 'package:penguin_pos_qa_agent/automation/register/register_scenario.dart';

class FakeRegisterDriver implements Driver {
  final List<String> tappedKeys = <String>[];
  final List<String> enteredTexts = <String>[];
  final Map<String, bool> activeKeys = <String, bool>{};

  @override
  Future<void> connect(
    Uri vmServiceUri, {
    Duration timeout = const Duration(seconds: 45),
  }) async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> waitFor(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  }) async {}

  @override
  Future<void> waitForAbsent(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    activeKeys[key] = false;
  }

  @override
  Future<String> waitForAnyKey(
    Iterable<String> keys, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    for (final key in keys) {
      if (activeKeys[key] == true) return key;
    }
    return keys.first;
  }

  @override
  Future<void> waitForText(
    String text, {
    Duration timeout = const Duration(seconds: 45),
  }) async {}

  @override
  Future<bool> hasKey(
    String key, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    return activeKeys[key] ?? false;
  }

  @override
  Future<bool> hasText(
    String text, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    return false;
  }

  @override
  Future<String?> tryGetText(
    String key, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (key == PenguinPosRegisterKeys.cashTotal) {
      return '₹2000.00';
    }
    return null;
  }

  @override
  Future<String> getText(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    return '';
  }

  @override
  Future<void> tap(String key) async {
    tappedKeys.add(key);
    if (key == PenguinPosOrderKeys.orderOpenRegister) {
      activeKeys[PenguinPosRegisterKeys.registerScreen] = true;
      activeKeys[PenguinPosRegisterKeys.inputOpeningFloat] = true;
    }
  }

  @override
  Future<void> tapText(String text) async {
    tappedKeys.add('text:$text');
  }

  @override
  Future<bool> tryTapKey(
    String key, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (activeKeys[key] == true) {
      tappedKeys.add(key);
      if (key == PenguinPosRegisterKeys.registerSubmit) {
        activeKeys[PenguinPosRegisterKeys.inputOpeningFloat] = true;
      }
      return true;
    }
    return false;
  }

  @override
  Future<bool> tryTapText(
    String text, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    tappedKeys.add('text:$text');
    return true;
  }

  @override
  Future<void> enterText(
    String key,
    String text, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    enteredTexts.add('$key:$text');
  }

  @override
  Future<void> enterTextViaVirtualKeyboard(
    String targetInputKey,
    String text, {
    String keyPrefix = 'login.qwerty',
    TextInputMode mode = TextInputMode.customQwertyPad,
  }) async {
    enteredTexts.add('$targetInputKey:$text');
  }

  @override
  Future<String?> requestData(
    String message, {
    Duration timeout = const Duration(seconds: 5),
  }) async => 'cleared';

  @override
  Future<OrderStateSnapshot?> queryOrderState({
    Duration timeout = const Duration(seconds: 3),
  }) async => null;

  @override
  Future<bool> clearSnackBars() async => true;

  @override
  Future<bool> showQaTestNotice(QaTestNotice notice) async => true;

  @override
  Future<bool> clearQaTestNotice() async => true;
}

void main() {
  group('Register Automation Suite', () {
    late FakeRegisterDriver driver;
    late ExecutionContext context;

    setUp(() {
      driver = FakeRegisterDriver();
      context = ExecutionContext(driver: driver);
    });

    test('RegisterScenario clamps float amount between 0 and 5000', () {
      const scenario1 = RegisterScenario(openingFloatAmount: -100);
      expect(scenario1.effectiveFloatAmount, equals(0));

      const scenario2 = RegisterScenario(openingFloatAmount: 6000);
      expect(scenario2.effectiveFloatAmount, equals(5000));

      const scenario3 = RegisterScenario(openingFloatAmount: 2500);
      expect(scenario3.effectiveFloatAmount, equals(2500));
    });

    test(
      'OpenRegisterBlock enters opening float and taps submit on register screen',
      () async {
        driver.activeKeys[PenguinPosRegisterKeys.registerScreen] = true;
        driver.activeKeys[PenguinPosRegisterKeys.inputOpeningFloat] = true;
        driver.activeKeys[PenguinPosRegisterKeys.registerSubmit] = true;
        driver.activeKeys[PenguinPosOrderKeys.orderScreen] = true;

        const block = OpenRegisterBlock(openingFloatAmount: 2000.0);
        await block.execute(context);

        expect(
          driver.tappedKeys,
          contains(PenguinPosRegisterKeys.inputOpeningFloat),
        );
        expect(
          driver.enteredTexts,
          contains('${PenguinPosRegisterKeys.inputOpeningFloat}:2000'),
        );
        expect(
          driver.tappedKeys,
          contains(PenguinPosRegisterKeys.registerSubmit),
        );
      },
    );

    test(
      'RegisterRunner runs full register opening flow successfully',
      () async {
        driver.activeKeys[PenguinPosRegisterKeys.registerScreen] = true;
        driver.activeKeys[PenguinPosRegisterKeys.inputOpeningFloat] = true;
        driver.activeKeys[PenguinPosRegisterKeys.registerSubmit] = true;
        driver.activeKeys[PenguinPosOrderKeys.orderScreen] = true;

        final runner = RegisterRunner(driverEngine: driver);
        const scenario = RegisterScenario(
          id: 'reg_1',
          name: 'Register Run Test',
          openingFloatAmount: 750.0,
        );

        final result = await runner.run(
          scenario,
          vmServiceUri: Uri.parse('http://127.0.0.1:8181/ws'),
        );

        expect(result.passed, isTrue);
        expect(result.floatAmount, equals(750));
        expect(
          driver.enteredTexts,
          contains('${PenguinPosRegisterKeys.inputOpeningFloat}:750'),
        );
        expect(
          driver.tappedKeys,
          contains(PenguinPosRegisterKeys.registerSubmit),
        );
      },
    );

    test(
      'RegisterRunner taps order.open_register when on closed Order screen',
      () async {
        driver.activeKeys[PenguinPosOrderKeys.orderScreen] = true;
        driver.activeKeys[PenguinPosOrderKeys.orderOpenRegister] = true;
        driver.activeKeys[PenguinPosRegisterKeys.registerScreen] = false;
        driver.activeKeys[PenguinPosRegisterKeys.registerSubmit] = true;

        final runner = RegisterRunner(driverEngine: driver);
        const scenario = RegisterScenario(
          id: 'reg_2',
          name: 'Order Screen to Register Test',
          openingFloatAmount: 1200.0,
        );

        final result = await runner.run(
          scenario,
          vmServiceUri: Uri.parse('http://127.0.0.1:8181/ws'),
        );

        expect(result.passed, isTrue);
        expect(result.floatAmount, equals(1200));
        expect(
          driver.tappedKeys,
          contains(PenguinPosOrderKeys.orderOpenRegister),
        );
        expect(
          driver.tappedKeys,
          contains(PenguinPosRegisterKeys.registerSubmit),
        );
      },
    );

    test(
      'RegisterRunner gracefully recognizes when register is already open on Order screen',
      () async {
        driver.activeKeys[PenguinPosOrderKeys.orderScreen] = true;
        driver.activeKeys[PenguinPosOrderKeys.orderOpenRegister] = false;
        driver.activeKeys[PenguinPosOrderKeys.orderSaleStart] = true;

        final runner = RegisterRunner(driverEngine: driver);
        const scenario = RegisterScenario(
          id: 'reg_3',
          name: 'Already Open Test',
          openingFloatAmount: 500.0,
        );

        final result = await runner.run(
          scenario,
          vmServiceUri: Uri.parse('http://127.0.0.1:8181/ws'),
        );

        expect(result.passed, isTrue);
        expect(result.floatAmount, equals(500));
        expect(
          driver.tappedKeys,
          isNot(contains(PenguinPosRegisterKeys.registerSubmit)),
        );
      },
    );

    test(
      'RegisterRunner handles reconciliation required popup, clicks OK, and reports reconciliation message',
      () async {
        driver.activeKeys[PenguinPosRegisterKeys.registerScreen] = true;
        driver.activeKeys[PenguinPosRegisterKeys.inputOpeningFloat] = true;
        driver.activeKeys[PenguinPosRegisterKeys.registerSubmit] = true;
        driver.activeKeys[PenguinPosOrderKeys.orderScreen] = false;
        driver.activeKeys[PenguinPosOrderKeys.orderSaleStart] = false;
        driver.activeKeys[PenguinPosRegisterKeys.errorDialogOk] = true;

        final runner = RegisterRunner(driverEngine: driver);
        const scenario = RegisterScenario(
          id: 'reg_recon',
          name: 'Reconciliation Popup Test',
          openingFloatAmount: 100.0,
        );

        final result = await runner.run(
          scenario,
          vmServiceUri: Uri.parse('http://127.0.0.1:8181/ws'),
        );

        expect(result.passed, isFalse);
        expect(result.requiresReconciliation, isTrue);
        expect(
          result.error,
          equals('Complete the Reconciliation to open New Register'),
        );
        expect(
          driver.tappedKeys,
          contains(PenguinPosRegisterKeys.registerSubmit),
        );
        expect(
          driver.tappedKeys,
          contains(PenguinPosRegisterKeys.errorDialogOk),
        );
      },
    );

    test(
      'RegisterRunner runClose evaluates total cash, taps submit, and closes register successfully',
      () async {
        driver.activeKeys[PenguinPosRegisterKeys.registerScreen] = true;
        driver.activeKeys[PenguinPosRegisterKeys.inputOpeningFloat] = false;
        driver.activeKeys[PenguinPosRegisterKeys.registerSubmit] = true;
        driver.activeKeys[PenguinPosRegisterKeys.cashTotal] = true;
        driver.activeKeys[PenguinPosOrderKeys.orderScreen] = true;

        final runner = RegisterRunner(driverEngine: driver);
        const scenario = RegisterScenario(
          id: 'close_reg_1',
          name: 'Close Register Test',
          closeTotalAmount: 2000.0,
        );

        final result = await runner.runClose(
          scenario,
          vmServiceUri: Uri.parse('http://127.0.0.1:8181/ws'),
        );

        expect(result.passed, isTrue);
        expect(result.totalAmount, equals(2000));
        expect(
          driver.tappedKeys,
          contains(PenguinPosRegisterKeys.registerSubmit),
        );
      },
    );

    test(
      'CloseRegisterBlock concurrently probes and populates only active gateway and denomination fields',
      () async {
        driver.activeKeys[PenguinPosRegisterKeys.registerScreen] = true;
        driver.activeKeys[PenguinPosRegisterKeys.inputOpeningFloat] = false;
        driver.activeKeys[PenguinPosRegisterKeys.registerSubmit] = true;
        driver.activeKeys[PenguinPosRegisterKeys.cashTotal] = true;

        // Activate only Razorpay Card gateway fields (others absent)
        driver.activeKeys[PenguinPosRegisterKeys.inputRazorpayCardAmount] =
            true;
        driver.activeKeys[PenguinPosRegisterKeys.inputRazorpayCardCount] = true;

        // Activate only ₹500 notes denomination field
        driver.activeKeys[PenguinPosRegisterKeys.cashNotes(500)] = true;

        const block = CloseRegisterBlock(totalAmount: 1000.0);
        final context = ExecutionContext(driver: driver);

        await block.execute(context);

        // Only active gateway fields were tapped and filled
        expect(
          driver.enteredTexts,
          contains('${PenguinPosRegisterKeys.inputRazorpayCardAmount}:0'),
        );
        expect(
          driver.enteredTexts,
          contains('${PenguinPosRegisterKeys.inputRazorpayCardCount}:0'),
        );

        // Absent gateways were NOT filled
        expect(
          driver.enteredTexts,
          isNot(
            contains('${PenguinPosRegisterKeys.inputPinelabsCardAmount}:0'),
          ),
        );
        expect(
          driver.enteredTexts,
          isNot(contains('${PenguinPosRegisterKeys.inputPaytmCardAmount}:0')),
        );

        // Denomination 500 (1000 / 500 = 2) was filled
        expect(
          driver.enteredTexts,
          contains('${PenguinPosRegisterKeys.cashNotes(500)}:2'),
        );

        // Absent denomination notes were NOT filled
        expect(
          driver.enteredTexts,
          isNot(contains('${PenguinPosRegisterKeys.cashNotes(2000)}:0')),
        );
      },
    );
  });
}
