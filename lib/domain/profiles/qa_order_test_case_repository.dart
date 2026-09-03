import 'dart:convert';

import 'package:penguin_pos_qa_agent/domain/test_cases/order_test_case.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Profile-scoped persistence for order test-case definitions.
abstract interface class QaOrderTestCaseRepository {
  Future<List<OrderTestCaseDefinition>> read(String profileId);

  Future<void> write(String profileId, List<OrderTestCaseDefinition> testCases);

  Future<void> clear(String profileId);
}

class SharedPreferencesQaOrderTestCaseRepository
    implements QaOrderTestCaseRepository {
  SharedPreferencesQaOrderTestCaseRepository({
    Future<SharedPreferences> Function()? preferencesProvider,
  }) : _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance;

  static const int _schemaVersion = 1;
  final Future<SharedPreferences> Function() _preferencesProvider;

  String _key(String profileId) =>
      'qa.profile.$profileId.suite.order.test_cases.v1';

  @override
  Future<List<OrderTestCaseDefinition>> read(String profileId) async {
    if (profileId.trim().isEmpty) return const <OrderTestCaseDefinition>[];
    final preferences = await _preferencesProvider();
    final raw = preferences.getString(_key(profileId));
    if (raw == null || raw.isEmpty) return const <OrderTestCaseDefinition>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const <OrderTestCaseDefinition>[];
      final rows = decoded['testCases'];
      if (rows is! List) return const <OrderTestCaseDefinition>[];
      final result = <OrderTestCaseDefinition>[];
      final seenIds = <String>{};
      for (final row in rows.whereType<Map>()) {
        final definition = OrderTestCaseDefinition.fromJson(
          row.cast<String, Object?>(),
        );
        if (definition.id.isEmpty || !seenIds.add(definition.id)) continue;
        result.add(definition);
      }
      return List<OrderTestCaseDefinition>.unmodifiable(result);
    } on FormatException {
      return const <OrderTestCaseDefinition>[];
    } on TypeError {
      return const <OrderTestCaseDefinition>[];
    }
  }

  @override
  Future<void> write(
    String profileId,
    List<OrderTestCaseDefinition> testCases,
  ) async {
    if (profileId.trim().isEmpty) {
      throw ArgumentError.value(profileId, 'profileId', 'Must not be empty.');
    }
    final ids = <String>{};
    for (final testCase in testCases) {
      if (testCase.id.trim().isEmpty) {
        throw ArgumentError.value(
          testCase.id,
          'testCases',
          'Every test case must have a non-empty id.',
        );
      }
      if (!ids.add(testCase.id)) {
        throw ArgumentError.value(
          testCase.id,
          'testCases',
          'Test case ids must be unique.',
        );
      }
      if (testCase.orderCount < 1) {
        throw ArgumentError.value(
          testCase.orderCount,
          'orderCount',
          'Order count must be at least one.',
        );
      }
    }
    final preferences = await _preferencesProvider();
    await preferences.setString(
      _key(profileId),
      jsonEncode(<String, Object?>{
        'schemaVersion': _schemaVersion,
        'testCases': testCases
            .map((testCase) => testCase.toJson())
            .toList(growable: false),
      }),
    );
  }

  @override
  Future<void> clear(String profileId) async {
    if (profileId.trim().isEmpty) return;
    final preferences = await _preferencesProvider();
    await preferences.remove(_key(profileId));
  }
}
