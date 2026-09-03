import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';

class QaOrderTestCase {
  const QaOrderTestCase({
    required this.id,
    required this.title,
    required this.description,
    required this.loginCaseId,
    required this.orderCount,
    required this.items,
  });

  final String id;
  final String title;
  final String description;
  final String loginCaseId;
  final int orderCount;
  final List<OrderItem> items;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'description': description,
    'loginCaseId': loginCaseId,
    'orderCount': orderCount,
    'items': items.map((item) => item.toJson()).toList(growable: false),
  };

  factory QaOrderTestCase.fromJson(Map<String, Object?> json) {
    final rawItems = json['items'];
    return QaOrderTestCase(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      loginCaseId: (json['loginCaseId'] as String?) ?? '',
      orderCount: (json['orderCount'] as num?)?.toInt() ?? 1,
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map((item) => OrderItem.fromJson(item.cast<String, Object?>()))
                .toList(growable: false)
          : const <OrderItem>[],
    );
  }
}

abstract interface class QaOrderInputRepository {
  Future<List<OrderItem>> read(String profileId);
  Future<void> write(String profileId, List<OrderItem> items);
  Future<void> clear(String profileId);
  Future<List<QaOrderTestCase>> readCases(String profileId);
  Future<void> writeCases(String profileId, List<QaOrderTestCase> cases);
}

class SharedPreferencesQaOrderInputRepository
    implements QaOrderInputRepository {
  SharedPreferencesQaOrderInputRepository({
    Future<SharedPreferences> Function()? preferencesProvider,
  }) : _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance;
  final Future<SharedPreferences> Function() _preferencesProvider;
  String _key(String id) => 'qa.profile.$id.order.inputs.v1';
  String _casesKey(String id) => 'qa.profile.$id.order.cases.v1';
  @override
  Future<List<OrderItem>> read(String profileId) async {
    if (profileId.trim().isEmpty) return const <OrderItem>[];
    final prefs = await _preferencesProvider();
    final raw = prefs.getString(_key(profileId));
    if (raw == null || raw.isEmpty) return const <OrderItem>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <OrderItem>[];
      return List<OrderItem>.unmodifiable(
        decoded.whereType<Map>().map(
          (row) => OrderItem.fromJson(row.cast<String, Object?>()),
        ),
      );
    } catch (_) {
      return const <OrderItem>[];
    }
  }

  @override
  Future<void> write(String profileId, List<OrderItem> items) async {
    if (profileId.trim().isEmpty) {
      throw ArgumentError.value(profileId, 'profileId');
    }
    final seen = <String>{};
    for (final item in items) {
      final code = item.skuCode.trim();
      if (code.isEmpty) throw ArgumentError('Every SKU must have a code.');
      if (item.isWeighed &&
          item.weightInputMode != WeightInputMode.auto &&
          (item.weight == null || item.weight! <= 0)) {
        throw ArgumentError('Weighed SKUs need a positive weight.');
      }
      if (!seen.add(code)) throw ArgumentError('SKU codes must be unique.');
    }
    final prefs = await _preferencesProvider();
    await prefs.setString(
      _key(profileId),
      jsonEncode(items.map((item) => item.toJson()).toList(growable: false)),
    );
  }

  @override
  Future<void> clear(String profileId) async {
    if (profileId.trim().isNotEmpty) {
      await (await _preferencesProvider()).remove(_key(profileId));
    }
  }

  @override
  Future<List<QaOrderTestCase>> readCases(String profileId) async {
    if (profileId.trim().isEmpty) return const <QaOrderTestCase>[];
    final raw = (await _preferencesProvider()).getString(_casesKey(profileId));
    if (raw == null || raw.isEmpty) return const <QaOrderTestCase>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <QaOrderTestCase>[];
      return List<QaOrderTestCase>.unmodifiable(
        decoded.whereType<Map>().map(
          (row) => QaOrderTestCase.fromJson(row.cast<String, Object?>()),
        ),
      );
    } catch (_) {
      return const <QaOrderTestCase>[];
    }
  }

  @override
  Future<void> writeCases(String profileId, List<QaOrderTestCase> cases) async {
    if (profileId.trim().isEmpty) {
      throw ArgumentError.value(profileId, 'profileId');
    }
    for (final testCase in cases) {
      if (testCase.id.trim().isEmpty || testCase.title.trim().isEmpty) {
        throw ArgumentError('Order test cases need an ID and title.');
      }
      if (testCase.items.isEmpty) {
        throw ArgumentError('Each order test case needs at least one SKU.');
      }
    }
    await (await _preferencesProvider()).setString(
      _casesKey(profileId),
      jsonEncode(
        cases.map((testCase) => testCase.toJson()).toList(growable: false),
      ),
    );
  }
}
