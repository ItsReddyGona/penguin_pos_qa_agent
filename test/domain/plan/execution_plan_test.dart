import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/domain/plan/execution_plan.dart';

void main() {
  test('login plans do not accept order configuration', () {
    const plan = ExecutionPlan(
      profileId: 'kpn-stage',
      suiteId: QaSuiteId.loginTerminal,
      orderConfiguration: OrderExecutionConfiguration(),
    );

    expect(
      plan.validate(),
      contains('Login plans cannot contain order configuration.'),
    );
  });

  test('requires every per-order allocation to have an item', () {
    const plan = ExecutionPlan(
      profileId: 'kpn-stage',
      suiteId: QaSuiteId.orderCheckout,
      orderConfiguration: OrderExecutionConfiguration(
        ordersCount: 2,
        itemStrategy: ExecutionItemStrategy.perOrder,
        perIterationItems: <int, List<OrderItem>>{
          1: <OrderItem>[OrderItem(skuCode: '22')],
        },
      ),
    );

    expect(plan.validate(), contains('Add at least one item for order 2.'));
  });

  test('accepts a valid weighed order plan', () {
    const plan = ExecutionPlan(
      profileId: 'kpn-stage',
      suiteId: QaSuiteId.orderCheckout,
      orderConfiguration: OrderExecutionConfiguration(
        items: <OrderItem>[
          OrderItem(
            skuCode: '10000002',
            type: SkuItemType.weighed,
            weight: 2.345,
          ),
        ],
      ),
    );

    expect(plan.validate(), isEmpty);
    expect(plan.toJson()['suiteId'], 'order_checkout');
  });
}
