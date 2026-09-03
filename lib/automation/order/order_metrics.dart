/// Telemetry metrics for intercepted API calls.
class OrderApiTelemetry {
  const OrderApiTelemetry({
    required this.endpoint,
    required this.statusCode,
    required this.responseTimeMs,
  });

  final String endpoint;
  final int statusCode;
  final int responseTimeMs;
}

/// Execution metric for an individual order step.
class OrderStepMetric {
  const OrderStepMetric({
    required this.stepName,
    required this.uiRenderTimeMs,
    this.apiTelemetry,
  });

  final String stepName;
  final int uiRenderTimeMs;
  final OrderApiTelemetry? apiTelemetry;
}

class OrderSkuResult {
  const OrderSkuResult({
    required this.sku,
    required this.type,
    required this.entryMode,
    this.weight,
    required this.passed,
    this.error,
  });

  final String sku;
  final String type;
  final String entryMode;
  final double? weight;
  final bool passed;
  final String? error;
}

class OrderStageResult {
  const OrderStageResult({
    required this.name,
    required this.passed,
    this.details,
  });

  final String name;
  final bool passed;
  final String? details;
}

/// Metrics recorded for one order in a multi-order batch run.
class OrderLoopMetrics {
  const OrderLoopMetrics({
    required this.loopIndex,
    required this.durationMs,
    required this.itemsCount,
    required this.totalPayable,
    required this.payableCash,
    required this.stepMetrics,
    this.skuResults = const <OrderSkuResult>[],
    this.stageResults = const <OrderStageResult>[],
    this.passed = true,
    this.error,
    this.orderNumber,
  });

  final int loopIndex;
  final int durationMs;
  final int itemsCount;
  final double totalPayable;
  final int payableCash;
  final List<OrderStepMetric> stepMetrics;
  final List<OrderSkuResult> skuResults;
  final List<OrderStageResult> stageResults;
  final bool passed;
  final String? error;
  final String? orderNumber;
}
