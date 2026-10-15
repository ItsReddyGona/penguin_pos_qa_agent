import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/domain/plan/execution_plan.dart';
import 'package:penguin_pos_qa_agent/domain/suites/qa_suite_registry.dart';
import 'package:penguin_pos_qa_agent/domain/suites/search_n_order_suite_definition.dart';
import 'package:penguin_pos_qa_agent/domain/suites/search_n_order_suite_scenarios.dart';

void main() {
  test('SearchNOrderSuiteDefinition is registered in QaSuiteRegistry', () {
    final suite = QaSuiteRegistry.instance.get(QaSuiteId.searchNOrder);
    expect(suite, isNotNull);
    expect(suite, isA<SearchNOrderSuiteDefinition>());
    expect(suite?.title, 'SearchNOrder');
  });

  test('ExecutionPlan recognizes searchNOrder as order suite', () {
    const plan = ExecutionPlan(
      profileId: 'kpn-stage',
      suiteId: QaSuiteId.searchNOrder,
      orderConfiguration: OrderExecutionConfiguration(
        items: <OrderItem>[OrderItem(skuCode: '10000001')],
      ),
    );

    expect(plan.isOrder, isTrue);
    expect(plan.validate(), isEmpty);
    expect(plan.toJson()['suiteId'], 'search_n_order');
  });

  test('SearchNOrderSuiteScenarios lists all required stages', () {
    expect(SearchNOrderSuiteScenarios.all.length, 6);
    expect(
      SearchNOrderSuiteScenarios.all,
      contains(SearchNOrderSuiteScenarios.searchItems),
    );
    expect(
      SearchNOrderSuiteScenarios.all,
      contains(SearchNOrderSuiteScenarios.addProductToCart),
    );
  });

  test('OrderItem supports name for SearchNOrder and serialization', () {
    final item = OrderItem.draft(skuCode: '10000001', name: 'Fresh Apples');
    expect(item.name, 'Fresh Apples');
    expect(item.skuCode, '10000001');

    final json = item.toJson();
    expect(json['name'], 'Fresh Apples');
    expect(json['skuCode'], '10000001');

    final revived = OrderItem.fromJson(json);
    expect(revived.name, 'Fresh Apples');
    expect(revived.skuCode, '10000001');
  });
}
