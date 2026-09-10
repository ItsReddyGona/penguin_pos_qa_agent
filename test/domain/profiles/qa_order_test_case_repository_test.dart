import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_order_test_case_repository.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/order_test_case.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('round trips order metadata and SKU items per profile', () async {
    final repository = SharedPreferencesQaOrderTestCaseRepository();
    const definition = OrderTestCaseDefinition(
      id: 'order-001',
      title: 'Cash order',
      description: 'Places one order without a customer.',
      loginTestCaseId: 'login-valid',
      items: <OrderItem>[
        OrderItem(skuCode: '123', entryMode: ItemEntryMode.manualNumpad),
      ],
    );

    await repository.write('profile-a', <OrderTestCaseDefinition>[definition]);
    final restored = await repository.read('profile-a');

    expect(restored, hasLength(1));
    expect(restored.single.id, definition.id);
    expect(restored.single.title, definition.title);
    expect(restored.single.description, definition.description);
    expect(restored.single.loginTestCaseId, definition.loginTestCaseId);
    expect(
      restored.single.items.single.skuCode,
      definition.items.single.skuCode,
    );
    expect(
      restored.single.items.single.effectiveEntryMode,
      definition.items.single.effectiveEntryMode,
    );
    expect(await repository.read('profile-b'), isEmpty);
  });

  test('rejects duplicate and invalid definitions', () async {
    final repository = SharedPreferencesQaOrderTestCaseRepository();
    const definition = OrderTestCaseDefinition(
      id: 'duplicate',
      title: 'Order',
      loginTestCaseId: 'login-valid',
    );

    expect(
      () => repository.write('profile-a', <OrderTestCaseDefinition>[
        definition,
        definition,
      ]),
      throwsArgumentError,
    );
    expect(
      () => repository.write('profile-a', <OrderTestCaseDefinition>[
        definition.copyWith(orderCount: 0),
      ]),
      throwsArgumentError,
    );
  });

  test('converts to the existing OrderScenario runtime object', () {
    const definition = OrderTestCaseDefinition(
      id: 'order-001',
      title: 'Cash order',
      loginTestCaseId: 'login-valid',
      items: <OrderItem>[OrderItem(skuCode: '123')],
      orderCount: 2,
    );

    final scenario = definition.toScenario(
      loginId: 'user',
      password: 'secret',
      unlockPin: '1234',
    );
    expect(scenario.id, 'order-001');
    expect(scenario.name, 'Cash order');
    expect(scenario.loginId, 'user');
    expect(scenario.password, 'secret');
    expect(scenario.unlockPin, '1234');
    expect(scenario.ordersCount, 2);
    expect(scenario.items.single.skuCode, '123');
  });

  test('persists custom payload per iteration and runtime selection', () async {
    final repository = SharedPreferencesQaOrderTestCaseRepository();
    final definition = OrderTestCaseDefinition(
      id: 'order-custom',
      title: 'Custom orders',
      loginTestCaseId: 'login-valid',
      orderCount: 2,
      uiCustomMode: UiCustomMode.perIteration,
      items: const <OrderItem>[OrderItem(skuCode: 'common')],
      perIterationItems: const <int, List<OrderItem>>{
        1: <OrderItem>[OrderItem(skuCode: '111')],
        2: <OrderItem>[OrderItem(skuCode: '222')],
      },
    );

    await repository.write('profile-custom', <OrderTestCaseDefinition>[
      definition,
    ]);
    final restored = (await repository.read('profile-custom')).single;
    final scenario = restored.toScenario();

    expect(restored.uiCustomMode, UiCustomMode.perIteration);
    expect(restored.perIterationItems[1]!.single.skuCode, '111');
    expect(restored.perIterationItems[2]!.single.skuCode, '222');
    expect(scenario.getItemsForIteration(1).single.skuCode, '111');
    expect(scenario.getItemsForIteration(2).single.skuCode, '222');
  });
}
