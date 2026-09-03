import 'dart:async';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_keys.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_runner.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/domain/suites/order_suite_scenarios.dart';
import 'package:penguin_pos_qa_agent/runtime/driver_engine.dart';

class FakeFlutterDriver extends Fake implements FlutterDriver {}

class StatefulFakeDriverEngine extends DriverEngine {
  StatefulFakeDriverEngine({
    required Set<String> initialKeys,
    this.tappedKeys,
    this.onTapKey,
  }) : _availableKeys = Set<String>.from(initialKeys);

  final Set<String> _availableKeys;
  final List<String>? tappedKeys;
  final void Function(String key, Set<String> currentKeys)? onTapKey;

  @override
  Future<FlutterDriver> connect(
    Uri vmServiceUri, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    return FakeFlutterDriver();
  }

  @override
  Future<bool> hasKey(
    String key, {
    Duration timeout = const Duration(seconds: 1),
  }) async {
    return _availableKeys.contains(key);
  }

  @override
  Future<String> waitForAnyKey(
    Iterable<String> keys, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      for (final key in keys) {
        if (_availableKeys.contains(key)) {
          return key;
        }
        if (key.startsWith('order.item.accepted.') &&
            _availableKeys.contains(PenguinPosOrderKeys.orderItemAccepted)) {
          return key;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw TimeoutException(
      'Timed out waiting for one of: ${keys.join(', ')}.',
      timeout,
    );
  }

  @override
  Future<void> waitFor(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_availableKeys.contains(key)) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw TimeoutException('Timed out waiting for key: $key', timeout);
  }

  @override
  Future<void> tap(String key) async {
    tappedKeys?.add(key);
    onTapKey?.call(key, _availableKeys);
  }

  @override
  Future<bool> tryTapKey(
    String key, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (_availableKeys.contains(key)) {
      tappedKeys?.add(key);
      onTapKey?.call(key, _availableKeys);
      return true;
    }
    return false;
  }

  @override
  Future<void> enterText(
    String key,
    String text, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    tappedKeys?.add('enterText:$key:$text');
  }

  @override
  Future<String?> tryGetText(
    String key, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    return '100.00';
  }
}

void main() {
  group('OrderRunner State-Driven Cart Sync Tests', () {
    const scenario = OrderScenario(
      id: 'cart_sync_test',
      name: 'Cart Sync Test',
      items: <OrderItem>[OrderItem(skuCode: '22')],
    );

    Set<String> baseOrderKeys() => <String>{
      PenguinPosOrderKeys.orderScreen,
      PenguinPosOrderKeys.orderTable,
      PenguinPosOrderKeys.orderNumPadSection,
      PenguinPosOrderKeys.orderInputCode,
      PenguinPosOrderKeys.orderEntryReady,
      PenguinPosOrderKeys.orderNumPadEnter,
      PenguinPosOrderKeys.orderItemAccepted,
      PenguinPosOrderKeys.orderCartReady,
      PenguinPosOrderKeys.paymentScreen,
      PenguinPosOrderKeys.billSummaryTotalPayable,
      PenguinPosOrderKeys.paymentCash,
      PenguinPosOrderKeys.paymentCashInput,
      PenguinPosOrderKeys.paymentNumPadEnter,
      PenguinPosOrderKeys.paymentPlaceOrder,
      PenguinPosOrderKeys.orderSuccessScreen,
      PenguinPosOrderKeys.orderSuccessDone,
    };

    test(
      '1. Proceeds to pay immediately when orderProceedToPay is available',
      () async {
        final tapped = <String>[];
        final keys = baseOrderKeys()
          ..add(PenguinPosOrderKeys.orderProceedToPay);
        final engine = StatefulFakeDriverEngine(
          initialKeys: keys,
          tappedKeys: tapped,
        );

        final runner = PenguinPosOrderRunner();
        final result = await runner.run(
          scenario,
          vmServiceUri: Uri.parse('http://127.0.0.1:8080'),
          driverEngine: engine,
          timeout: const Duration(seconds: 5),
        );

        expect(result.passed, isTrue);
        expect(tapped, contains(PenguinPosOrderKeys.orderProceedToPay));
      },
    );

    test('reports all dashboard scenarios as they complete', () async {
      final events = <ExecutionEvent>[];
      final completedScenarios = <String>[];
      final keys = baseOrderKeys()..add(PenguinPosOrderKeys.orderProceedToPay);
      final engine = StatefulFakeDriverEngine(initialKeys: keys);

      final result = await PenguinPosOrderRunner().run(
        scenario,
        vmServiceUri: Uri.parse('http://127.0.0.1:8080'),
        driverEngine: engine,
        timeout: const Duration(seconds: 5),
        onExecutionEvent: events.add,
        onScenarioCompleted: completedScenarios.add,
      );

      expect(result.passed, isTrue);
      expect(completedScenarios, OrderSuiteScenarios.all);
      expect(
        events.map((event) => event.title),
        containsAll(OrderSuiteScenarios.all),
      );
    });

    test(
      'scan-mode Bizerba uses automatic text entry and the order submit control',
      () async {
        final tapped = <String>[];
        final keys = baseOrderKeys()
          ..add(PenguinPosOrderKeys.orderProceedToPay);
        final engine = StatefulFakeDriverEngine(
          initialKeys: keys,
          tappedKeys: tapped,
        );
        const bizerbaScenario = OrderScenario(
          id: 'bizerba_scan_transport',
          name: 'Bizerba Scan Transport',
          items: <OrderItem>[
            OrderItem(skuCode: '10000001W3.709', type: SkuItemType.bizerba),
          ],
        );

        final result = await PenguinPosOrderRunner().run(
          bizerbaScenario,
          vmServiceUri: Uri.parse('http://127.0.0.1:8080'),
          driverEngine: engine,
          timeout: const Duration(seconds: 5),
        );

        expect(result.passed, isTrue);
        expect(
          tapped,
          contains(
            'enterText:${PenguinPosOrderKeys.orderInputCode}:10000001W3.709',
          ),
        );
        expect(tapped, contains(PenguinPosOrderKeys.orderNumPadEnter));
      },
    );

    test(
      '2. Statefully transitions from Update Cart to Proceed to Pay',
      () async {
        final tapped = <String>[];
        final keys = baseOrderKeys()
          ..remove(PenguinPosOrderKeys.orderCartReady)
          ..add(PenguinPosOrderKeys.orderUpdateCart);
        final engine = StatefulFakeDriverEngine(
          initialKeys: keys,
          tappedKeys: tapped,
          onTapKey: (tappedKey, currentKeys) {
            if (tappedKey == PenguinPosOrderKeys.orderUpdateCart) {
              currentKeys.remove(PenguinPosOrderKeys.orderUpdateCart);
              currentKeys.add(PenguinPosOrderKeys.orderCartReady);
              currentKeys.add(PenguinPosOrderKeys.orderProceedToPay);
            }
          },
        );

        final runner = PenguinPosOrderRunner();
        final result = await runner.run(
          scenario,
          vmServiceUri: Uri.parse('http://127.0.0.1:8080'),
          driverEngine: engine,
          timeout: const Duration(seconds: 5),
        );

        expect(result.passed, isTrue);
        expect(tapped, contains(PenguinPosOrderKeys.orderUpdateCart));
        expect(tapped, contains(PenguinPosOrderKeys.orderProceedToPay));
      },
    );

    test(
      '3. Stops after one Update Cart tap when payment readiness never appears',
      () async {
        final events = <ExecutionEvent>[];
        final tapped = <String>[];
        final keys = baseOrderKeys()
          ..remove(PenguinPosOrderKeys.orderCartReady)
          ..add(PenguinPosOrderKeys.orderUpdateCart);
        final engine = StatefulFakeDriverEngine(
          initialKeys: keys,
          tappedKeys: tapped,
        );

        final runner = PenguinPosOrderRunner();
        final result = await runner.run(
          scenario,
          vmServiceUri: Uri.parse('http://127.0.0.1:8080'),
          driverEngine: engine,
          timeout: const Duration(milliseconds: 100),
          onExecutionEvent: (e) => events.add(e),
        );

        expect(result.passed, isFalse);
        final updateCartTaps = tapped
            .where((k) => k == PenguinPosOrderKeys.orderUpdateCart)
            .length;
        expect(updateCartTaps, equals(1));
        expect(
          events.any(
            (e) => e.message.contains(
              'Update Cart was tapped once, but the cart did not expose payment readiness',
            ),
          ),
          isTrue,
        );
        expect(
          events,
          contains(
            isA<ExecutionEvent>()
                .having(
                  (event) => event.title,
                  'title',
                  OrderSuiteScenarios.cartReview,
                )
                .having(
                  (event) => event.level,
                  'level',
                  ExecutionEventLevel.error,
                ),
          ),
        );
      },
    );

    test(
      '4. Emits 0-tap timeout diagnostic when neither action appears',
      () async {
        final events = <ExecutionEvent>[];
        final keys = baseOrderKeys()
          ..remove(PenguinPosOrderKeys.orderCartReady); // no cart action
        final engine = StatefulFakeDriverEngine(initialKeys: keys);

        final runner = PenguinPosOrderRunner();
        final result = await runner.run(
          scenario,
          vmServiceUri: Uri.parse('http://127.0.0.1:8080'),
          driverEngine: engine,
          timeout: const Duration(milliseconds: 100),
          onExecutionEvent: (e) => events.add(e),
        );

        expect(result.passed, isFalse);
        expect(
          events.any(
            (e) => e.message.contains(
              'SKU was submitted, but PenguinPOS did not expose a payment-ready cart before timeout',
            ),
          ),
          isTrue,
        );
      },
    );

    test(
      '5. Does not retry Update Cart when payment readiness is absent',
      () async {
        final events = <ExecutionEvent>[];
        final tapped = <String>[];
        final keys = baseOrderKeys()
          ..remove(PenguinPosOrderKeys.orderCartReady)
          ..add(PenguinPosOrderKeys.orderUpdateCart);

        var tapCount = 0;
        final engine = StatefulFakeDriverEngine(
          initialKeys: keys,
          tappedKeys: tapped,
          onTapKey: (tappedKey, currentKeys) {
            if (tappedKey == PenguinPosOrderKeys.orderUpdateCart) tapCount++;
          },
        );

        final runner = PenguinPosOrderRunner();
        final result = await runner.run(
          scenario,
          vmServiceUri: Uri.parse('http://127.0.0.1:8080'),
          driverEngine: engine,
          timeout: const Duration(milliseconds: 100),
          onExecutionEvent: (e) => events.add(e),
        );

        expect(result.passed, isFalse);
        expect(tapCount, equals(1));
        expect(
          events.any(
            (e) => e.message.contains(
              'Update Cart was tapped once, but the cart did not expose payment readiness',
            ),
          ),
          isTrue,
        );
      },
    );
  });
}
