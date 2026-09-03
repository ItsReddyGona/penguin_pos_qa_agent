import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_runner.dart';

void main() {
  group('Order & Cash Payment Automation Tests', () {
    test(
      'calculateRoundOff rounds amounts correctly per POS specifications',
      () {
        expect(PenguinPosOrderRunner.calculateRoundOff(100.40), equals(100));
        expect(PenguinPosOrderRunner.calculateRoundOff(100.50), equals(101));
        expect(PenguinPosOrderRunner.calculateRoundOff(100.75), equals(101));
        expect(PenguinPosOrderRunner.calculateRoundOff(50.00), equals(50));
        expect(PenguinPosOrderRunner.calculateRoundOff(99.49), equals(99));
      },
    );

    test('OrderItem and OrderScenario json serialization with ordersCount', () {
      const item = OrderItem(
        skuCode: '102',
        type: SkuItemType.weighed,
        weight: 2.5,
      );
      final itemJson = item.toJson();
      expect(itemJson['skuCode'], equals('102'));
      expect(itemJson['isWeighed'], equals(true));
      expect(itemJson['weight'], equals(2.5));

      final restoredItem = OrderItem.fromJson(itemJson);
      expect(restoredItem.skuCode, equals('102'));
      expect(restoredItem.isWeighed, equals(true));
      expect(restoredItem.weight, equals(2.5));

      const scenario = OrderScenario(
        id: 'multi_order_scenario',
        name: 'Batch Order Test',
        items: <OrderItem>[item],
        ordersCount: 5,
      );

      final scenarioJson = scenario.toJson();
      expect(scenarioJson['ordersCount'], equals(5));

      final restoredScenario = OrderScenario.fromJson(scenarioJson);
      expect(restoredScenario.ordersCount, equals(5));
      expect(restoredScenario.items.length, equals(1));
    });

    test('OrderRunResult constructs multi-order metrics correctly', () {
      final now = DateTime.now();
      final result = OrderRunResult(
        passed: true,
        startedAt: now,
        finishedAt: now,
        ordersCompleted: 3,
        ordersTarget: 3,
        totalItemsProcessed: 6,
        aggregateTotalPayable: 225.50,
        aggregatePayableAmount: 226,
      );

      expect(result.ordersCompleted, equals(3));
      expect(result.totalItemsProcessed, equals(6));
      expect(result.aggregatePayableAmount, equals(226));

      final json = result.toJson();
      expect(json['ordersCompleted'], equals(3));
      expect(json['aggregatePayableAmount'], equals(226));
    });

    test('individual-order item payload survives scenario serialization', () {
      final individualItem = OrderItem.draft(
        skuCode: '2001',
        type: SkuItemType.weighed,
        weight: 1.25,
      );
      final scenario = OrderScenario(
        id: 'individual_orders',
        name: 'Individual orders',
        items: const <OrderItem>[],
        ordersCount: 2,
        uiCustomMode: UiCustomMode.perIteration,
        perIterationItems: <int, List<OrderItem>>{
          1: <OrderItem>[individualItem],
          2: <OrderItem>[OrderItem.draft(skuCode: '2002')],
        },
      );

      final restored = OrderScenario.fromJson(scenario.toJson());
      expect(restored.uiCustomMode, UiCustomMode.perIteration);
      expect(restored.getItemsForIteration(1).single.skuCode, '2001');
      expect(restored.getItemsForIteration(1).single.weight, 1.25);
      expect(
        restored.getItemsForIteration(1).single.rowId,
        individualItem.rowId,
      );
    });

    test('single-order per-iteration payload is executable', () {
      const scenario = OrderScenario(
        id: 'single_per_iteration',
        name: 'Single order custom payload',
        items: <OrderItem>[],
        ordersCount: 1,
        uiCustomMode: UiCustomMode.perIteration,
        perIterationItems: <int, List<OrderItem>>{
          1: <OrderItem>[OrderItem(skuCode: '22')],
        },
      );

      expect(scenario.getItemsForIteration(1).single.skuCode, '22');
    });

    test('CSV and JSON accept the UI item type and entry mode values', () {
      const csv = '''Order,SKU,ItemType,Weight,EntryMode
1,101,nonWeighed,,scan
1,102,weighed,1.250,manual
2,2000011017354,bizerba,,scan''';
      final parsedCsv = OrderScenario.parseCsvOrders(csv);
      expect(parsedCsv[1]![0].type, SkuItemType.nonWeighed);
      expect(parsedCsv[1]![0].effectiveEntryMode, ItemEntryMode.manualNumpad);
      expect(parsedCsv[1]![1].type, SkuItemType.weighed);
      expect(parsedCsv[1]![1].weight, 1.25);
      expect(parsedCsv[1]![1].effectiveEntryMode, ItemEntryMode.manualNumpad);
      expect(parsedCsv[2]!.single.type, SkuItemType.bizerba);

      const json = '''[
        {"order": 1, "items": [
          {"skuCode": "103", "type": "weighed", "weight": 0.5, "entryMode": "manual"}
        ]}
      ]''';
      final parsedJson = OrderScenario.parseJsonOrders(json);
      expect(parsedJson[1]!.single.type, SkuItemType.weighed);
      expect(
        parsedJson[1]!.single.effectiveEntryMode,
        ItemEntryMode.manualNumpad,
      );
    });

    test(
      'normalizes Bizerba formats and forces scan mode at import boundaries',
      () {
        final fromJson = OrderItem.fromJson(<String, Object?>{
          'skuCode': ' 10000001W3.709 ',
          // A model or import can supply a conflicting type/mode. The barcode
          // contract must still win before the runner sees the item.
          'type': 'nonWeighed',
          'entryMode': 'manualQwerty',
        });

        expect(fromJson.type, SkuItemType.bizerba);
        expect(fromJson.effectiveType, SkuItemType.bizerba);
        expect(fromJson.effectiveEntryMode, ItemEntryMode.scan);
        expect(fromJson.toJson()['type'], 'bizerba');
        expect(fromJson.toJson()['entryMode'], 'scan');

        final fromCsv = OrderScenario.parseCsvOrders(
          '''Order,SKU,ItemType,EntryMode
1,12345678.123,nonWeighed,manual''',
        );
        final numericBizerba = fromCsv[1]!.single;
        expect(numericBizerba.type, SkuItemType.bizerba);
        expect(numericBizerba.effectiveEntryMode, ItemEntryMode.scan);
      },
    );

    test('enforces short-code numpad entry and preserves SKU mode choices', () {
      final shortCode = OrderItem.fromJson(<String, Object?>{
        'skuCode': '105',
        'entryMode': 'scan',
      });
      expect(shortCode.effectiveEntryMode, ItemEntryMode.manualNumpad);

      final legacyManual = OrderItem.fromJson(<String, Object?>{
        'skuCode': '10000002',
        'entryMode': 'manual',
      });
      expect(legacyManual.entryMode, ItemEntryMode.manualNumpad);
      expect(legacyManual.effectiveEntryMode, ItemEntryMode.manualNumpad);

      final qwertySku = OrderItem.fromJson(<String, Object?>{
        'skuCode': 'OFFER123',
        'entryMode': 'qwerty',
      });
      expect(qwertySku.effectiveEntryMode, ItemEntryMode.manualQwerty);

      final defaultSku = OrderItem.fromJson(<String, Object?>{
        'skuCode': '8901058000123',
      });
      expect(defaultSku.effectiveEntryMode, ItemEntryMode.scan);
    });
  });
}
