import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/search_and_add_items_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_keys.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_run_state.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_state_snapshot.dart';

class _FakeSearchDriver implements Driver {
  final List<String> tappedKeys = <String>[];
  final List<String> tappedTexts = <String>[];
  final List<String> tappedTypes = <String>[];
  final Map<String, bool> activeKeys = <String, bool>{};
  final Map<String, bool> activeTexts = <String, bool>{};
  final Map<String, bool> activeTypes = <String, bool>{};

  @override
  Future<void> connect(
    Uri vmServiceUri, {
    Duration timeout = const Duration(seconds: 45),
  }) async {}

  @override
  Future<void> waitFor(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    if (activeKeys[key] != true) {
      throw StateError('Key not found: $key');
    }
  }

  @override
  Future<void> waitForAbsent(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  }) async {}

  @override
  Future<String> waitForAnyKey(
    Iterable<String> keys, {
    Duration timeout = const Duration(seconds: 45),
  }) async => keys.first;

  @override
  Future<void> waitForText(
    String text, {
    Duration timeout = const Duration(seconds: 45),
  }) async {}

  @override
  Future<bool> hasKey(
    String key, {
    Duration timeout = const Duration(seconds: 2),
  }) async => activeKeys[key] ?? false;

  @override
  Future<bool> hasText(
    String text, {
    Duration timeout = const Duration(seconds: 2),
  }) async => activeTexts[text] ?? false;

  @override
  Future<void> tap(String key) async {
    tappedKeys.add(key);
  }

  @override
  Future<void> tapText(String text) async {
    tappedTexts.add(text);
  }

  @override
  Future<bool> tryTapText(
    String text, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (activeTexts[text] == true) {
      tappedTexts.add(text);
      return true;
    }
    return false;
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
  Future<void> tapByType(
    String type, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    tappedTypes.add(type);
  }

  @override
  Future<bool> tryTapByType(
    String type, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (activeTypes[type] == true) {
      tappedTypes.add(type);
      return true;
    }
    return false;
  }

  final List<String> enteredTexts = <String>[];

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
  }) async {}

  @override
  Future<String?> tryGetText(
    String key, {
    Duration timeout = const Duration(seconds: 3),
  }) async => null;

  @override
  Future<String> getText(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  }) async => '';

  @override
  Future<String?> requestData(
    String message, {
    Duration timeout = const Duration(seconds: 5),
  }) async => 'ok';

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

  @override
  Future<void> close() async {}
}

void main() {
  group('SearchAndAddItemsBlock', () {
    late _FakeSearchDriver driver;
    late ExecutionContext context;
    late OrderScenario scenario;
    late OrderRunState state;

    setUp(() {
      driver = _FakeSearchDriver();
      context = ExecutionContext(
        driver: driver,
        timeout: const Duration(seconds: 5),
      );
      scenario = const OrderScenario(
        id: 'test_scenario',
        name: 'Test Scenario',
        items: <OrderItem>[OrderItem(skuCode: '4011', name: 'Banana')],
      );
      state = OrderRunState(orderIndex: 1, scenario: scenario);
    });

    test(
      'types on virtual keyboard, taps magnifier AppButton, and clicks ADD',
      () async {
        driver.activeKeys[PenguinPosOrderKeys.orderEntryReady] = true;
        driver.activeKeys[PenguinPosOrderKeys.orderSearchItemsButton] = true;
        driver.activeTexts['Search (SKU, Name or Barcode)'] = true;

        // Virtual keyboard keys (via text fallback)
        driver.activeTexts['4'] = true;
        driver.activeTexts['0'] = true;
        driver.activeTexts['1'] = true;

        // Magnifier search button
        driver.activeTypes['AppButton'] = true;

        // Product ADD button
        driver.activeTexts['ADD'] = true;

        // Cart return & item acceptance
        driver.activeKeys[PenguinPosOrderKeys.orderItemAcceptedForSku('4011')] =
            true;

        final block = SearchAndAddItemsBlock(state: state);
        await block.execute(context);

        expect(
          driver.tappedKeys,
          contains(PenguinPosOrderKeys.orderSearchItemsButton),
        );
        expect(driver.tappedTexts, containsAll(<String>['4', '0', '1', 'ADD']));
        expect(driver.tappedTypes, contains('AppButton'));
        expect(state.skuResults.length, 1);
        expect(state.skuResults.first.passed, isTrue);
      },
    );

    test(
      'types via QWERTY keyPrefix keys, taps search.action.submit, and taps search.product.add key',
      () async {
        driver.activeKeys[PenguinPosOrderKeys.orderEntryReady] = true;
        driver.activeKeys[PenguinPosOrderKeys.orderSearchItemsButton] = true;
        driver.activeKeys[PenguinPosOrderKeys.searchTextInput] = true;

        // QWERTY keys via search.qwerty.key.*
        driver.activeKeys['search.qwerty.key.4'] = true;
        driver.activeKeys['search.qwerty.key.0'] = true;
        driver.activeKeys['search.qwerty.key.1'] = true;

        // Magnifier submit key
        driver.activeKeys[PenguinPosOrderKeys.searchSubmitButton] = true;

        // Product ADD key
        driver.activeKeys[PenguinPosOrderKeys.searchProductAdd('4011')] = true;

        // Acceptance
        driver.activeKeys[PenguinPosOrderKeys.orderItemAcceptedForSku('4011')] =
            true;

        final block = SearchAndAddItemsBlock(state: state);
        await block.execute(context);

        expect(
          driver.tappedKeys,
          containsAll(<String>[
            PenguinPosOrderKeys.orderSearchItemsButton,
            PenguinPosOrderKeys.searchTextInput,
            'search.qwerty.key.4',
            'search.qwerty.key.0',
            'search.qwerty.key.1',
            PenguinPosOrderKeys.searchSubmitButton,
            PenguinPosOrderKeys.searchProductAdd('4011'),
          ]),
        );
        expect(state.skuResults.first.passed, isTrue);
      },
    );

    test(
      'searches by Item Name via QWERTY keys, clicks magnifier, and adds first result',
      () async {
        final nameScenario = const OrderScenario(
          id: 'name_search_scenario',
          name: 'Item Name Search',
          items: <OrderItem>[
            OrderItem(
              skuCode: '',
              name: 'Apple',
              entryMode: ItemEntryMode.manualQwerty,
            ),
          ],
        );
        final nameState = OrderRunState(orderIndex: 1, scenario: nameScenario);

        driver.activeKeys[PenguinPosOrderKeys.orderEntryReady] = true;
        driver.activeKeys[PenguinPosOrderKeys.orderSearchItemsButton] = true;
        driver.activeKeys[PenguinPosOrderKeys.searchTextInput] = true;

        // QWERTY keys for 'apple'
        driver.activeKeys['search.qwerty.key.a'] = true;
        driver.activeKeys['search.qwerty.key.p'] = true;
        driver.activeKeys['search.qwerty.key.l'] = true;
        driver.activeKeys['search.qwerty.key.e'] = true;

        driver.activeKeys[PenguinPosOrderKeys.searchSubmitButton] = true;
        driver.activeKeys[PenguinPosOrderKeys.searchProductAddFirst] = true;
        driver.activeKeys[PenguinPosOrderKeys.orderItemAccepted] = true;

        final block = SearchAndAddItemsBlock(state: nameState);
        await block.execute(context);

        expect(
          driver.tappedKeys,
          containsAll(<String>[
            'search.qwerty.key.a',
            'search.qwerty.key.p',
            'search.qwerty.key.l',
            'search.qwerty.key.e',
            PenguinPosOrderKeys.searchSubmitButton,
            PenguinPosOrderKeys.searchProductAddFirst,
          ]),
        );
        expect(nameState.skuResults.first.passed, isTrue);
      },
    );

    test(
      'searches by Short Code (<= 4 digits) via QWERTY keys and adds product without length error',
      () async {
        final shortScenario = const OrderScenario(
          id: 'short_code_scenario',
          name: 'Short Code Search',
          items: <OrderItem>[OrderItem(skuCode: '12', name: '')],
        );
        final shortState = OrderRunState(
          orderIndex: 1,
          scenario: shortScenario,
        );

        driver.activeKeys[PenguinPosOrderKeys.orderEntryReady] = true;
        driver.activeKeys[PenguinPosOrderKeys.orderSearchItemsButton] = true;
        driver.activeKeys[PenguinPosOrderKeys.searchTextInput] = true;

        // QWERTY keys for '12'
        driver.activeKeys['search.qwerty.key.1'] = true;
        driver.activeKeys['search.qwerty.key.2'] = true;

        driver.activeKeys[PenguinPosOrderKeys.searchSubmitButton] = true;
        driver.activeKeys[PenguinPosOrderKeys.searchProductAdd('12')] = true;
        driver.activeKeys[PenguinPosOrderKeys.orderItemAcceptedForSku('12')] =
            true;

        final block = SearchAndAddItemsBlock(state: shortState);
        await block.execute(context);

        expect(
          driver.tappedKeys,
          containsAll(<String>[
            'search.qwerty.key.1',
            'search.qwerty.key.2',
            PenguinPosOrderKeys.searchSubmitButton,
            PenguinPosOrderKeys.searchProductAdd('12'),
          ]),
        );
        expect(shortState.skuResults.first.passed, isTrue);
      },
    );

    test(
      'fails immediately when virtual keyboard character cannot be typed',
      () async {
        driver.activeKeys[PenguinPosOrderKeys.orderEntryReady] = true;
        driver.activeKeys[PenguinPosOrderKeys.orderSearchItemsButton] = true;
        driver.activeTexts['Search (SKU, Name or Barcode)'] = true;

        // Missing '4' on virtual keyboard
        driver.activeTexts['4'] = false;

        final block = SearchAndAddItemsBlock(state: state);
        expect(
          () => block.execute(context),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Step 2 Failed'),
            ),
          ),
        );
      },
    );

    test(
      'fails immediately when magnifier search button cannot be clicked',
      () async {
        driver.activeKeys[PenguinPosOrderKeys.orderEntryReady] = true;
        driver.activeKeys[PenguinPosOrderKeys.orderSearchItemsButton] = true;
        driver.activeTexts['Search (SKU, Name or Barcode)'] = true;

        driver.activeTexts['4'] = true;
        driver.activeTexts['0'] = true;
        driver.activeTexts['1'] = true;

        // Neither AppButton nor ElevatedButton is available
        driver.activeTypes['AppButton'] = false;
        driver.activeTypes['ElevatedButton'] = false;

        final block = SearchAndAddItemsBlock(state: state);
        expect(
          () => block.execute(context),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Step 3 Failed'),
            ),
          ),
        );
      },
    );

    test('fails immediately when ADD button does not appear', () async {
      driver.activeKeys[PenguinPosOrderKeys.orderEntryReady] = true;
      driver.activeKeys[PenguinPosOrderKeys.orderSearchItemsButton] = true;
      driver.activeTexts['Search (SKU, Name or Barcode)'] = true;

      driver.activeTexts['4'] = true;
      driver.activeTexts['0'] = true;
      driver.activeTexts['1'] = true;

      driver.activeTypes['AppButton'] = true;

      // ADD button not visible
      driver.activeTexts['ADD'] = false;

      final block = SearchAndAddItemsBlock(state: state);
      expect(
        () => block.execute(context),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Step 4 Failed'),
          ),
        ),
      );
    });

    test(
      'types multi-word search query containing space via search.qwerty.space',
      () async {
        const multiWordItem = OrderItem(
          skuCode: 'Apple Fugi',
          name: 'Apple Fugi',
          entryMode: ItemEntryMode.manualQwerty,
        );
        const multiWordScenario = OrderScenario(
          id: 'test_multi_word',
          name: 'Multi Word Test',
          items: <OrderItem>[multiWordItem],
        );
        final multiWordState = OrderRunState(
          orderIndex: 1,
          scenario: multiWordScenario,
        );

        driver.activeKeys[PenguinPosOrderKeys.orderEntryReady] = true;
        driver.activeKeys[PenguinPosOrderKeys.orderSearchItemsButton] = true;
        driver.activeKeys[PenguinPosOrderKeys.searchTextInput] = true;
        driver.activeKeys['search.qwerty.space'] = true;

        for (final char in ['a', 'p', 'l', 'e', 'f', 'u', 'g', 'i']) {
          driver.activeKeys['search.qwerty.key.$char'] = true;
        }

        driver.activeKeys[PenguinPosOrderKeys.searchSubmitButton] = true;
        driver.activeKeys[PenguinPosOrderKeys.searchProductAddFirst] = true;
        driver.activeKeys[PenguinPosOrderKeys.orderItemAcceptedForSku(
              'Apple Fugi',
            )] =
            true;

        final block = SearchAndAddItemsBlock(state: multiWordState);
        await block.execute(context);

        expect(driver.tappedKeys, contains('search.qwerty.space'));
        expect(
          driver.tappedKeys,
          contains(PenguinPosOrderKeys.searchSubmitButton),
        );
        expect(
          driver.tappedKeys,
          contains(PenguinPosOrderKeys.searchProductAddFirst),
        );
        expect(multiWordState.skuResults.length, 1);
        expect(multiWordState.skuResults.first.passed, isTrue);
      },
    );

    test(
      'types space via fallback qwerty.space when search.qwerty.space missing',
      () async {
        const multiWordItem = OrderItem(
          skuCode: 'Apple Fugi',
          name: 'Apple Fugi',
          entryMode: ItemEntryMode.manualQwerty,
        );
        const multiWordScenario = OrderScenario(
          id: 'test_multi_word_fallback',
          name: 'Multi Word Fallback Test',
          items: <OrderItem>[multiWordItem],
        );
        final multiWordState = OrderRunState(
          orderIndex: 1,
          scenario: multiWordScenario,
        );

        driver.activeKeys[PenguinPosOrderKeys.orderEntryReady] = true;
        driver.activeKeys[PenguinPosOrderKeys.orderSearchItemsButton] = true;
        driver.activeKeys[PenguinPosOrderKeys.searchTextInput] = true;
        driver.activeKeys['qwerty.space'] = true; // Fallback space key

        for (final char in ['a', 'p', 'l', 'e', 'f', 'u', 'g', 'i']) {
          driver.activeKeys['search.qwerty.key.$char'] = true;
        }

        driver.activeKeys[PenguinPosOrderKeys.searchSubmitButton] = true;
        driver.activeKeys[PenguinPosOrderKeys.searchProductAddFirst] = true;
        driver.activeKeys[PenguinPosOrderKeys.orderItemAcceptedForSku(
              'Apple Fugi',
            )] =
            true;

        final block = SearchAndAddItemsBlock(state: multiWordState);
        await block.execute(context);

        expect(driver.tappedKeys, contains('qwerty.space'));
        expect(multiWordState.skuResults.first.passed, isTrue);
      },
    );

    test(
      'falls back to direct entry if virtual space key cannot be tapped',
      () async {
        const multiWordItem = OrderItem(
          skuCode: 'Apple Fugi',
          name: 'Apple Fugi',
          entryMode: ItemEntryMode.manualQwerty,
        );
        const multiWordScenario = OrderScenario(
          id: 'test_multi_word_direct_entry',
          name: 'Multi Word Direct Entry Test',
          items: <OrderItem>[multiWordItem],
        );
        final multiWordState = OrderRunState(
          orderIndex: 1,
          scenario: multiWordScenario,
        );

        driver.activeKeys[PenguinPosOrderKeys.orderEntryReady] = true;
        driver.activeKeys[PenguinPosOrderKeys.orderSearchItemsButton] = true;
        driver.activeKeys[PenguinPosOrderKeys.searchTextInput] = true;
        // Letters active, but NO space keys active anywhere
        for (final char in ['a', 'p', 'l', 'e']) {
          driver.activeKeys['search.qwerty.key.$char'] = true;
        }

        driver.activeKeys[PenguinPosOrderKeys.searchSubmitButton] = true;
        driver.activeKeys[PenguinPosOrderKeys.searchProductAddFirst] = true;
        driver.activeKeys[PenguinPosOrderKeys.orderItemAcceptedForSku(
              'Apple Fugi',
            )] =
            true;

        final block = SearchAndAddItemsBlock(state: multiWordState);
        await block.execute(context);

        expect(
          driver.enteredTexts,
          contains('${PenguinPosOrderKeys.searchTextInput}:Apple Fugi'),
        );
        expect(multiWordState.skuResults.first.passed, isTrue);
      },
    );
  });
}
