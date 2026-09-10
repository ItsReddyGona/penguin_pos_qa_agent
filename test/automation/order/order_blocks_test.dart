import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/collect_cash_payment_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/complete_order_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/ensure_order_screen_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/enter_order_items_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/start_sale_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/synchronize_cart_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_keys.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_run_state.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_state_snapshot.dart';
import 'package:penguin_pos_qa_agent/automation/register/register_keys.dart';

class FakeOrderDriver implements Driver {
  final List<String> tappedKeys = <String>[];
  final List<String> enteredTexts = <String>[];
  final Map<String, bool> activeKeys = <String, bool>{};
  final Map<String, String> keyTexts = <String, String>{};
  final List<OrderStateSnapshot?> stateSnapshots = <OrderStateSnapshot?>[];

  @override
  Future<void> connect(
    Uri vmServiceUri, {
    Duration timeout = const Duration(seconds: 45),
  }) async {}

  @override
  Future<void> close() async {}

  @override
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
      if (key.startsWith('order.item.accepted.') &&
          activeKeys[PenguinPosOrderKeys.orderItemAccepted] == true) {
        return key;
      }
    }
    throw TimeoutException(
      'waitForAnyKey: none of the keys are active: ${keys.join(", ")}',
      timeout,
    );
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
    return keyTexts[key];
  }

  @override
  Future<String> getText(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    return keyTexts[key] ?? '';
  }

  @override
  Future<void> tap(String key) async {
    tappedKeys.add(key);
  }

  @override
  Future<bool> tryTapKey(
    String key, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (activeKeys[key] == true) {
      tappedKeys.add(key);
      return true;
    }
    return false;
  }

  @override
  Future<void> tapText(String text) async {
    tappedKeys.add('text:$text');
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
    Duration timeout = const Duration(seconds: 2),
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
  }) async {
    if (stateSnapshots.isEmpty) return null;
    return stateSnapshots.removeAt(0);
  }

  @override
  Future<bool> clearSnackBars() async => true;

  @override
  Future<bool> showQaTestNotice(QaTestNotice notice) async => true;

  @override
  Future<bool> clearQaTestNotice() async => true;
}

void main() {
  group('Order Automation Blocks Unit Tests', () {
    late FakeOrderDriver driver;
    late ExecutionContext context;

    setUp(() {
      driver = FakeOrderDriver();
      driver.activeKeys[PenguinPosOrderKeys.orderEntryReady] = true;
      driver.activeKeys[PenguinPosOrderKeys.orderItemAccepted] = true;
      context = ExecutionContext(
        driver: driver,
        timeout: const Duration(seconds: 5),
      );
    });

    test(
      'EnsureOrderScreenBlock navigates from home tab when orderScreen inactive',
      () async {
        driver.activeKeys[PenguinPosOrderKeys.orderScreen] = false;

        const block = EnsureOrderScreenBlock();
        await block.execute(context);

        expect(driver.tappedKeys, contains(PenguinPosOrderKeys.homeOrderTab));
      },
    );

    test(
      'StartSaleBlock handles continueWithoutCustomer when start sale is visible',
      () async {
        driver.activeKeys[PenguinPosOrderKeys.orderSaleStart] = true;
        final scenario = const OrderScenario(id: 's1', name: 'Test', items: []);
        final state = OrderRunState(orderIndex: 1, scenario: scenario);

        final block = StartSaleBlock(state: state);
        await block.execute(context);

        expect(
          driver.tappedKeys,
          contains(PenguinPosOrderKeys.continueWithoutCustomer),
        );
        expect(state.stepMetrics.length, equals(1));
        expect(
          state.stepMetrics.first.stepName,
          equals('Start Sale & Customer Selection'),
        );
      },
    );

    test(
      'StartSaleBlock detects register closed, clicks open register, runs OpenRegisterBlock, and proceeds to start sale',
      () async {
        driver.activeKeys[PenguinPosOrderKeys.orderOpenRegister] = true;
        driver.activeKeys[PenguinPosRegisterKeys.registerScreen] = true;
        driver.activeKeys[PenguinPosRegisterKeys.inputOpeningFloat] = true;
        driver.activeKeys[PenguinPosRegisterKeys.registerSubmit] = true;
        driver.activeKeys[PenguinPosOrderKeys.orderScreen] = true;
        driver.activeKeys[PenguinPosOrderKeys.orderSaleStart] = true;

        final scenario = const OrderScenario(
          id: 's_reg',
          name: 'Register Recovery Test',
          items: [],
          openingFloatAmount: 1500.0,
        );
        final state = OrderRunState(orderIndex: 1, scenario: scenario);

        final block = StartSaleBlock(state: state);
        await block.execute(context);

        expect(
          driver.tappedKeys,
          contains(PenguinPosOrderKeys.orderOpenRegister),
        );
        expect(
          driver.tappedKeys,
          contains(PenguinPosRegisterKeys.inputOpeningFloat),
        );
        expect(
          driver.enteredTexts,
          contains('${PenguinPosRegisterKeys.inputOpeningFloat}:1500'),
        );
        expect(
          driver.tappedKeys,
          contains(PenguinPosRegisterKeys.registerSubmit),
        );
        expect(
          driver.tappedKeys,
          contains(PenguinPosOrderKeys.continueWithoutCustomer),
        );
      },
    );

    test(
      'EnterOrderItemsBlock enters item SKU and updates state count',
      () async {
        final scenario = const OrderScenario(
          id: 's2',
          name: 'Item Test',
          items: [
            OrderItem(skuCode: '101', entryMode: ItemEntryMode.manualNumpad),
          ],
        );
        final state = OrderRunState(orderIndex: 1, scenario: scenario);

        final block = EnterOrderItemsBlock(state: state);
        await block.execute(context);

        expect(state.itemsThisOrder, equals(1));
        expect(
          driver.tappedKeys,
          contains(PenguinPosOrderKeys.orderNumPadDigit('1')),
        );
        expect(
          driver.tappedKeys,
          contains(PenguinPosOrderKeys.orderNumPadDigit('0')),
        );
        expect(
          driver.tappedKeys,
          contains(PenguinPosOrderKeys.orderNumPadEnter),
        );
      },
    );

    test(
      'EnterOrderItemsBlock waits for a new structured cart revision',
      () async {
        driver.stateSnapshots.addAll([
          const OrderStateSnapshot(
            phase: 'idle',
            cartRevision: 4,
            mutationId: 4,
            entryReady: true,
            weightRequired: false,
            cartReady: false,
            cartItemCount: 1,
            lastMutationSku: '100',
            lastMutationStatus: 'accepted',
          ),
          const OrderStateSnapshot(
            phase: 'accepted',
            cartRevision: 5,
            mutationId: 5,
            entryReady: true,
            weightRequired: false,
            cartReady: true,
            cartItemCount: 2,
            scanStatus: 'success',
            resolvedSku: '10000021',
            lastMutationSku: '10000021',
            lastMutationStatus: 'accepted',
          ),
        ]);
        const scenario = OrderScenario(
          id: 'structured-state',
          name: 'Structured State',
          items: [
            OrderItem(skuCode: '22', entryMode: ItemEntryMode.manualNumpad),
          ],
        );
        final state = OrderRunState(orderIndex: 1, scenario: scenario);

        await EnterOrderItemsBlock(state: state).execute(context);

        expect(state.itemsThisOrder, equals(1));
        expect(state.skuResults.single.passed, isTrue);
        expect(driver.stateSnapshots, isEmpty);
      },
    );

    test(
      'auto weight observes POS weight numpad dismissal without touching weight field',
      () async {
        driver.activeKeys[PenguinPosOrderKeys.orderInputWeight] = true;
        const scenario = OrderScenario(
          id: 'auto-weight',
          name: 'Auto Weight',
          items: [
            OrderItem(
              skuCode: 'SKU-1',
              type: SkuItemType.weighed,
              weightInputMode: WeightInputMode.auto,
            ),
          ],
        );
        final state = OrderRunState(orderIndex: 1, scenario: scenario);

        // Simulate weight modal closing after a brief moment
        Future<void>.delayed(const Duration(milliseconds: 50), () {
          driver.activeKeys[PenguinPosOrderKeys.orderInputWeight] = false;
        });

        await EnterOrderItemsBlock(state: state).execute(context);

        expect(state.resolvedWeights, isEmpty);
        expect(state.itemsThisOrder, 1);
        expect(state.skuResults.single.passed, isTrue);
      },
    );

    test(
      'auto weight captures user-entered weight from POS before modal closes',
      () async {
        driver.activeKeys[PenguinPosOrderKeys.orderInputWeight] = true;
        driver.keyTexts[PenguinPosOrderKeys.orderInputWeight] = '2.500';
        const scenario = OrderScenario(
          id: 'auto-weight-capture',
          name: 'Auto Weight Capture',
          items: [
            OrderItem(
              skuCode: 'SKU-1',
              type: SkuItemType.weighed,
              weightInputMode: WeightInputMode.auto,
            ),
          ],
        );
        final state = OrderRunState(orderIndex: 1, scenario: scenario);

        Future<void>.delayed(const Duration(milliseconds: 50), () {
          driver.activeKeys[PenguinPosOrderKeys.orderInputWeight] = false;
        });

        await EnterOrderItemsBlock(state: state).execute(context);

        expect(
          state.resolvedWeights[state.weightKey(scenario.items.first)],
          equals(2.5),
        );
        expect(state.skuResults.single.weight, equals(2.5));
        expect(state.skuResults.single.passed, isTrue);
      },
    );

    test(
      'target weight prompt overrides non-weighed configuration and waits for user input',
      () async {
        driver.activeKeys[PenguinPosOrderKeys.orderInputWeight] = true;
        driver.keyTexts[PenguinPosOrderKeys.orderInputWeight] = '2.500';
        const scenario = OrderScenario(
          id: 'non-weighed-mismatch',
          name: 'Non Weighed Mismatch',
          items: [
            OrderItem(
              skuCode: 'SKU-NW',
              type: SkuItemType.nonWeighed,
              entryMode: ItemEntryMode.scan,
            ),
          ],
        );
        final state = OrderRunState(orderIndex: 1, scenario: scenario);

        Future<void>.delayed(const Duration(milliseconds: 50), () {
          driver.activeKeys[PenguinPosOrderKeys.orderInputWeight] = false;
        });

        await EnterOrderItemsBlock(state: state).execute(context);

        expect(state.skuResults, hasLength(1));
        expect(state.skuResults[0].passed, isTrue);
        expect(state.skuResults[0].error, isNull);
        expect(state.skuResults[0].weight, equals(2.5));
        expect(state.itemsThisOrder, 1);
        expect(
          driver.tappedKeys,
          isNot(contains(PenguinPosOrderKeys.orderNumPadDecimal)),
        );
      },
    );

    test(
      'target acceptance overrides weighed configuration without a mismatch failure',
      () async {
        const scenario = OrderScenario(
          id: 'weighed-config-accepted',
          name: 'Weighed Config Accepted',
          items: [
            OrderItem(
              skuCode: 'SKU-W',
              type: SkuItemType.weighed,
              weightInputMode: WeightInputMode.auto,
              entryMode: ItemEntryMode.scan,
            ),
          ],
        );
        final state = OrderRunState(orderIndex: 1, scenario: scenario);

        await EnterOrderItemsBlock(state: state).execute(context);

        expect(state.itemsThisOrder, 1);
        expect(state.skuResults.single.passed, isTrue);
        expect(state.skuResults.single.error, isNull);
      },
    );

    test('manual decimal weight taps the PenguinPOS decimal key', () async {
      driver.activeKeys[PenguinPosOrderKeys.orderInputWeight] = true;
      const scenario = OrderScenario(
        id: 'manual-decimal-weight',
        name: 'Manual Decimal Weight',
        items: [
          OrderItem(
            skuCode: 'SKU-W',
            type: SkuItemType.weighed,
            weightInputMode: WeightInputMode.manual,
            weight: 0.001,
            entryMode: ItemEntryMode.scan,
          ),
        ],
      );
      final state = OrderRunState(orderIndex: 1, scenario: scenario);

      await EnterOrderItemsBlock(state: state).execute(context);

      final zero = PenguinPosOrderKeys.orderNumPadDigit('0');
      final one = PenguinPosOrderKeys.orderNumPadDigit('1');
      expect(
        driver.tappedKeys,
        containsAllInOrder(<String>[
          zero,
          PenguinPosOrderKeys.orderNumPadDecimal,
          zero,
          zero,
          one,
          PenguinPosOrderKeys.orderNumPadEnter,
        ]),
      );
      expect(state.skuResults.single.passed, isTrue);
      expect(state.skuResults.single.weight, 0.001);
    });

    test('ignores stale weight-required state from the previous SKU', () async {
      driver.stateSnapshots.addAll([
        const OrderStateSnapshot(
          phase: 'weightRequired',
          cartRevision: 4,
          mutationId: 4,
          entryReady: true,
          weightRequired: true,
          cartReady: false,
          cartItemCount: 1,
          scanStatus: 'success',
          resolvedSku: 'OLD-SKU',
          lastMutationSku: 'OLD-SKU',
          lastMutationStatus: 'weightRequired',
        ),
        const OrderStateSnapshot(
          phase: 'weightRequired',
          cartRevision: 4,
          mutationId: 4,
          entryReady: true,
          weightRequired: true,
          cartReady: false,
          cartItemCount: 1,
          scanStatus: 'success',
          resolvedSku: 'OLD-SKU',
          lastMutationSku: 'OLD-SKU',
          lastMutationStatus: 'weightRequired',
        ),
        const OrderStateSnapshot(
          phase: 'accepted',
          cartRevision: 5,
          mutationId: 5,
          entryReady: true,
          weightRequired: false,
          cartReady: true,
          cartItemCount: 2,
          scanStatus: 'success',
          resolvedSku: 'NEW-SKU',
          lastMutationSku: 'NEW-SKU',
          lastMutationStatus: 'accepted',
          lastMutationQuantity: 1,
        ),
      ]);
      const scenario = OrderScenario(
        id: 'stale-weight-state',
        name: 'Stale Weight State',
        items: [OrderItem(skuCode: 'NEW-SKU', entryMode: ItemEntryMode.scan)],
      );
      final state = OrderRunState(orderIndex: 1, scenario: scenario);

      await EnterOrderItemsBlock(state: state).execute(context);

      expect(state.itemsThisOrder, 1);
      expect(state.skuResults.single.passed, isTrue);
    });

    test(
      'treats a fresh current-SKU quantity of zero as weight pending',
      () async {
        driver.activeKeys[PenguinPosOrderKeys.orderInputWeight] = true;
        driver.keyTexts[PenguinPosOrderKeys.orderInputWeight] = '1.250';
        driver.stateSnapshots.addAll([
          const OrderStateSnapshot(
            phase: 'idle',
            cartRevision: 1,
            mutationId: 1,
            entryReady: true,
            weightRequired: false,
            cartReady: true,
            cartItemCount: 1,
            lastMutationSku: 'OLD-SKU',
            lastMutationStatus: 'accepted',
            lastMutationQuantity: 1,
          ),
          const OrderStateSnapshot(
            phase: 'scanning',
            cartRevision: 2,
            mutationId: 2,
            entryReady: false,
            weightRequired: false,
            cartReady: false,
            cartItemCount: 2,
            scanStatus: 'success',
            resolvedSku: 'WEIGHT-SKU',
            lastMutationSku: 'WEIGHT-SKU',
            lastMutationStatus: 'pending',
            lastMutationQuantity: 0,
          ),
          const OrderStateSnapshot(
            phase: 'accepted',
            cartRevision: 3,
            mutationId: 3,
            entryReady: true,
            weightRequired: false,
            cartReady: true,
            cartItemCount: 2,
            scanStatus: 'success',
            resolvedSku: 'WEIGHT-SKU',
            lastMutationSku: 'WEIGHT-SKU',
            lastMutationStatus: 'accepted',
            lastMutationQuantity: 1.25,
          ),
        ]);
        const scenario = OrderScenario(
          id: 'quantity-zero-weight',
          name: 'Quantity Zero Weight',
          items: [
            OrderItem(
              skuCode: 'WEIGHT-SKU',
              type: SkuItemType.nonWeighed,
              entryMode: ItemEntryMode.scan,
            ),
          ],
        );
        final state = OrderRunState(orderIndex: 1, scenario: scenario);

        Future<void>.delayed(const Duration(milliseconds: 50), () {
          driver.activeKeys[PenguinPosOrderKeys.orderInputWeight] = false;
        });

        await EnterOrderItemsBlock(state: state).execute(context);

        expect(state.itemsThisOrder, 1);
        expect(state.skuResults.single.passed, isTrue);
        expect(state.skuResults.single.weight, 1.25);
      },
    );

    test(
      'auto weight timeout records failure when numpad remains open',
      () async {
        context = ExecutionContext(
          driver: driver,
          timeout: const Duration(milliseconds: 30),
        );
        driver.activeKeys[PenguinPosOrderKeys.orderInputWeight] = true;
        const scenario = OrderScenario(
          id: 'auto-weight-timeout',
          name: 'Auto Weight Timeout',
          items: [
            OrderItem(
              skuCode: 'SKU-1',
              type: SkuItemType.weighed,
              weightInputMode: WeightInputMode.auto,
            ),
          ],
        );
        final state = OrderRunState(orderIndex: 1, scenario: scenario);

        await expectLater(
          EnterOrderItemsBlock(state: state).execute(context),
          throwsA(
            predicate(
              (error) =>
                  error.toString() ==
                  'Exception: All SKU items failed to enter for order 1.',
            ),
          ),
        );
        expect(state.skuResults.single.passed, isFalse);
        expect(
          state.skuResults.single.error,
          contains('failed to input weight'),
        );
      },
    );

    test('SynchronizeCartBlock proceeds to pay when ready', () async {
      driver.activeKeys[PenguinPosOrderKeys.orderCartReady] = true;
      final scenario = const OrderScenario(
        id: 's3',
        name: 'Cart Test',
        items: [],
      );
      final state = OrderRunState(orderIndex: 1, scenario: scenario);

      final events = <ExecutionEvent>[];
      final eventContext = ExecutionContext(
        driver: driver,
        timeout: const Duration(seconds: 5),
        onEvent: events.add,
      );

      final block = SynchronizeCartBlock(state: state);
      await block.execute(eventContext);

      expect(
        driver.tappedKeys,
        contains(PenguinPosOrderKeys.orderProceedToPay),
      );
      expect(events.any((e) => e.title == 'Checkout Started'), isTrue);
    });

    test(
      'CollectCashPaymentBlock reads balance, rounds amount, and submits cash',
      () async {
        driver.keyTexts[PenguinPosOrderKeys.billSummaryTotalPayable] =
            '₹150.75';
        final scenario = const OrderScenario(
          id: 's4',
          name: 'Payment Test',
          items: [],
        );
        final state = OrderRunState(orderIndex: 1, scenario: scenario);

        final block = CollectCashPaymentBlock(state: state);
        await block.execute(context);

        expect(state.totalPayableVal, equals(150.75));
        expect(state.roundedPayable, equals(151));
        expect(driver.tappedKeys, contains(PenguinPosOrderKeys.paymentCash));
        expect(
          driver.tappedKeys,
          contains(PenguinPosOrderKeys.paymentNumPadDigit('1')),
        );
        expect(
          driver.tappedKeys,
          contains(PenguinPosOrderKeys.paymentNumPadDigit('5')),
        );
        expect(
          driver.tappedKeys,
          contains(PenguinPosOrderKeys.paymentNumPadEnter),
        );
      },
    );

    test('CompleteOrderBlock taps done and completes order', () async {
      driver.activeKeys[PenguinPosOrderKeys.orderSuccessScreen] = true;
      driver.activeKeys[PenguinPosOrderKeys.orderSuccessDone] = true;
      final scenario = const OrderScenario(
        id: 's5',
        name: 'Done Test',
        items: [],
      );
      final state = OrderRunState(orderIndex: 1, scenario: scenario);

      final block = CompleteOrderBlock(state: state);
      await block.execute(context);

      expect(driver.tappedKeys, contains(PenguinPosOrderKeys.orderSuccessDone));
      expect(state.stepMetrics.length, equals(1));
    });
  });
}
