import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';

/// A QA suite that the desktop agent can execute.
///
/// This deliberately identifies a runnable workflow without carrying any
/// credentials, model prompts, driver commands, or UI-only state.
enum QaSuiteId {
  loginTerminal,
  orderCheckout;

  String get storageValue => switch (this) {
    QaSuiteId.loginTerminal => 'login_terminal',
    QaSuiteId.orderCheckout => 'order_checkout',
  };

  static QaSuiteId? fromStorageValue(String value) => switch (value) {
    'login_terminal' => QaSuiteId.loginTerminal,
    'order_checkout' => QaSuiteId.orderCheckout,
    _ => null,
  };
}

/// Determines whether each order reuses a common item list or provides its
/// own list.
enum ExecutionItemStrategy { sameForAll, perOrder }

/// Declarative order inputs that are safe to show, edit, and persist in a QA
/// plan. Secrets are resolved only at execution time from the credential store.
class OrderExecutionConfiguration {
  const OrderExecutionConfiguration({
    this.ordersCount = 1,
    this.itemStrategy = ExecutionItemStrategy.sameForAll,
    this.items = const <OrderItem>[],
    this.perIterationItems = const <int, List<OrderItem>>{},
  });

  final int ordersCount;
  final ExecutionItemStrategy itemStrategy;
  final List<OrderItem> items;
  final Map<int, List<OrderItem>> perIterationItems;

  Iterable<OrderItem> get allItems sync* {
    yield* items;
    for (final orderItems in perIterationItems.values) {
      yield* orderItems;
    }
  }

  List<String> validate() {
    final issues = <String>[];
    if (ordersCount < 1 || ordersCount > 50) {
      issues.add('Order count must be between 1 and 50.');
    }

    if (itemStrategy == ExecutionItemStrategy.sameForAll && items.isEmpty) {
      issues.add('Add at least one item for the order.');
    }
    if (itemStrategy == ExecutionItemStrategy.perOrder) {
      for (var order = 1; order <= ordersCount; order++) {
        if ((perIterationItems[order] ?? const <OrderItem>[]).isEmpty) {
          issues.add('Add at least one item for order $order.');
        }
      }
    }

    for (final item in allItems) {
      if (item.skuCode.trim().isEmpty) {
        issues.add('Each order item needs an SKU code.');
      }
      if (item.isWeighed &&
          item.weightInputMode != WeightInputMode.auto &&
          (item.weight == null || item.weight! <= 0)) {
        issues.add('Weighed SKU ${item.skuCode} needs a positive weight.');
      }
    }
    return issues.toSet().toList(growable: false);
  }

  OrderExecutionConfiguration copyWith({
    int? ordersCount,
    ExecutionItemStrategy? itemStrategy,
    List<OrderItem>? items,
    Map<int, List<OrderItem>>? perIterationItems,
  }) => OrderExecutionConfiguration(
    ordersCount: ordersCount ?? this.ordersCount,
    itemStrategy: itemStrategy ?? this.itemStrategy,
    items: items ?? this.items,
    perIterationItems: perIterationItems ?? this.perIterationItems,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'ordersCount': ordersCount,
    'itemStrategy': itemStrategy.name,
    'items': items.map((item) => item.toJson()).toList(growable: false),
    'perIterationItems': perIterationItems.map(
      (index, orderItems) => MapEntry(
        index.toString(),
        orderItems.map((item) => item.toJson()).toList(growable: false),
      ),
    ),
  };
}

/// One reviewable request to execute a PenguinPOS QA suite.
class ExecutionPlan {
  const ExecutionPlan({
    required this.profileId,
    required this.suiteId,
    this.orderConfiguration,
  });

  final String profileId;
  final QaSuiteId suiteId;
  final OrderExecutionConfiguration? orderConfiguration;

  bool get isOrder => suiteId == QaSuiteId.orderCheckout;

  List<String> validate() {
    final issues = <String>[];
    if (profileId.trim().isEmpty) {
      issues.add('Choose a target profile before running.');
    }
    if (isOrder) {
      if (orderConfiguration == null) {
        issues.add('Order checkout requires order configuration.');
      } else {
        issues.addAll(orderConfiguration!.validate());
      }
    } else if (orderConfiguration != null) {
      issues.add('Login plans cannot contain order configuration.');
    }
    return issues.toSet().toList(growable: false);
  }

  ExecutionPlan copyWith({
    String? profileId,
    QaSuiteId? suiteId,
    OrderExecutionConfiguration? orderConfiguration,
    bool clearOrderConfiguration = false,
  }) => ExecutionPlan(
    profileId: profileId ?? this.profileId,
    suiteId: suiteId ?? this.suiteId,
    orderConfiguration: clearOrderConfiguration
        ? null
        : (orderConfiguration ?? this.orderConfiguration),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'profileId': profileId,
    'suiteId': suiteId.storageValue,
    if (orderConfiguration != null)
      'orderConfiguration': orderConfiguration!.toJson(),
  };
}
