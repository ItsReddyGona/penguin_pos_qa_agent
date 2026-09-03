import 'package:penguin_pos_qa_agent/automation/order/order_metrics.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';

/// Mutable per-iteration state shared among order automation blocks during a batch execution.
class OrderRunState {
  OrderRunState({
    required this.orderIndex,
    required this.scenario,
    DateTime? loopStart,
  }) : loopStart = loopStart ?? DateTime.now();

  final int orderIndex;
  final OrderScenario scenario;
  final DateTime loopStart;

  int itemsThisOrder = 0;
  double totalPayableVal = 0.0;
  int roundedPayable = 0;
  final List<OrderStepMetric> stepMetrics = <OrderStepMetric>[];
  final Map<String, double> resolvedWeights = <String, double>{};
  final List<OrderSkuResult> skuResults = <OrderSkuResult>[];

  String weightKey(OrderItem item) =>
      item.rowId.isNotEmpty ? item.rowId : item.skuCode.trim();
}
