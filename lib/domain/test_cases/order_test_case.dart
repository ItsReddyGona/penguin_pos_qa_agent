import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';

export 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart'
    show OrderCustomerMode;

/// Payment method used by an order test case.
enum OrderPaymentMethod {
  cash('Cash');

  const OrderPaymentMethod(this.label);
  final String label;

  static OrderPaymentMethod fromString(String? value) {
    if (value == 'cash') return OrderPaymentMethod.cash;
    return OrderPaymentMethod.cash;
  }
}

/// A saved, reportable order flow definition.
///
/// This is configuration metadata and intentionally contains no credentials.
/// [loginTestCaseId] refers to a row in the profile's login test-case suite;
/// the runner resolves that row at execution time.
class OrderTestCaseDefinition {
  const OrderTestCaseDefinition({
    required this.id,
    required this.title,
    this.description = '',
    required this.loginTestCaseId,
    this.customerMode = OrderCustomerMode.continueWithoutCustomer,
    this.customerPhoneNumber,
    this.customerName,
    this.customerOtp,
    this.paymentMethod = OrderPaymentMethod.cash,
    this.orderCount = 1,
    this.items = const <OrderItem>[],
    this.uiCustomMode = UiCustomMode.common,
    this.perIterationItems = const <int, List<OrderItem>>{},
    this.enabled = true,
  });

  final String id;
  final String title;
  final String description;
  final String loginTestCaseId;
  final OrderCustomerMode customerMode;
  final String? customerPhoneNumber;
  final String? customerName;
  final String? customerOtp;
  final OrderPaymentMethod paymentMethod;
  final int orderCount;
  final List<OrderItem> items;
  final UiCustomMode uiCustomMode;
  final Map<int, List<OrderItem>> perIterationItems;
  final bool enabled;

  /// Produces the runtime object consumed by the existing order runner.
  /// Credentials are supplied by the referenced login row at runtime.
  OrderScenario toScenario({
    String? loginId,
    String? password,
    String? unlockPin,
    int? ordersCount,
  }) => OrderScenario(
    id: id,
    name: title,
    loginId: loginId,
    password: password,
    unlockPin: unlockPin,
    items: List<OrderItem>.unmodifiable(items),
    ordersCount: (ordersCount != null && ordersCount > 0)
        ? ordersCount
        : (orderCount < 1 ? 1 : orderCount),
    uiCustomMode: ((ordersCount != null && ordersCount <= 1) || orderCount <= 1)
        ? UiCustomMode.common
        : uiCustomMode,
    perIterationItems: perIterationItems,
    customerMode: customerMode,
    customerPhoneNumber: customerPhoneNumber,
    customerName: customerName,
    customerOtp: customerOtp,
  );

  OrderTestCaseDefinition copyWith({
    String? id,
    String? title,
    String? description,
    String? loginTestCaseId,
    OrderCustomerMode? customerMode,
    String? customerPhoneNumber,
    String? customerName,
    String? customerOtp,
    OrderPaymentMethod? paymentMethod,
    int? orderCount,
    List<OrderItem>? items,
    UiCustomMode? uiCustomMode,
    Map<int, List<OrderItem>>? perIterationItems,
    bool? enabled,
  }) => OrderTestCaseDefinition(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    loginTestCaseId: loginTestCaseId ?? this.loginTestCaseId,
    customerMode: customerMode ?? this.customerMode,
    customerPhoneNumber: customerPhoneNumber ?? this.customerPhoneNumber,
    customerName: customerName ?? this.customerName,
    customerOtp: customerOtp ?? this.customerOtp,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    orderCount: orderCount ?? this.orderCount,
    items: items ?? this.items,
    uiCustomMode: uiCustomMode ?? this.uiCustomMode,
    perIterationItems: perIterationItems ?? this.perIterationItems,
    enabled: enabled ?? this.enabled,
  );

  /// Safe persistence/report representation. No login credentials are stored.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'description': description,
    'loginTestCaseId': loginTestCaseId,
    'customerMode': customerMode.name,
    if (customerPhoneNumber != null) 'customerPhoneNumber': customerPhoneNumber,
    if (customerName != null) 'customerName': customerName,
    if (customerOtp != null) 'customerOtp': customerOtp,
    'paymentMethod': paymentMethod.name,
    'orderCount': orderCount,
    'items': items.map((item) => item.toJson()).toList(growable: false),
    'uiCustomMode': uiCustomMode.name,
    'perIterationItems': perIterationItems.map(
      (key, value) => MapEntry(
        key.toString(),
        value.map((item) => item.toJson()).toList(growable: false),
      ),
    ),
    'enabled': enabled,
  };

  factory OrderTestCaseDefinition.fromJson(Map<String, Object?> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => OrderItem.fromJson(item.cast<String, Object?>()))
              .toList(growable: false)
        : const <OrderItem>[];
    final rawPerIteration = json['perIterationItems'];
    final perIterationItems = <int, List<OrderItem>>{};
    if (rawPerIteration is Map) {
      for (final entry in rawPerIteration.entries) {
        final iteration = int.tryParse(entry.key.toString());
        final rawList = entry.value;
        if (iteration == null || rawList is! List) continue;
        perIterationItems[iteration] = rawList
            .whereType<Map>()
            .map((item) => OrderItem.fromJson(item.cast<String, Object?>()))
            .toList(growable: false);
      }
    }
    return OrderTestCaseDefinition(
      id: (json['id'] as String?)?.trim() ?? '',
      title: (json['title'] as String?) ?? (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      loginTestCaseId:
          (json['loginTestCaseId'] as String?)?.trim() ??
          (json['loginCaseId'] as String?)?.trim() ??
          '',
      customerMode: OrderCustomerMode.fromString(
        json['customerMode'] as String?,
      ),
      customerPhoneNumber: json['customerPhoneNumber'] as String?,
      customerName: json['customerName'] as String?,
      customerOtp: json['customerOtp'] as String?,
      paymentMethod: OrderPaymentMethod.fromString(
        json['paymentMethod'] as String?,
      ),
      orderCount:
          (json['orderCount'] as num?)?.toInt() ??
          (json['ordersCount'] as num?)?.toInt() ??
          1,
      items: items,
      uiCustomMode: UiCustomMode.fromString(json['uiCustomMode'] as String?),
      perIterationItems: perIterationItems,
      enabled: (json['enabled'] as bool?) ?? true,
    );
  }
}
