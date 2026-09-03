import 'package:penguin_pos_qa_agent/domain/test_cases/test_case_definition.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/test_input_schema.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/test_run_command.dart';

/// Validates a portable test command against a test case's declared schema.
class TestCaseInputValidator {
  const TestCaseInputValidator();

  List<String> validate(TestRunCommand command, TestCaseDefinition definition) {
    final issues = <String>[];
    if (command.testCaseId.trim().isEmpty) {
      issues.add('Test case ID is required.');
    } else if (command.testCaseId != definition.id) {
      issues.add(
        'Command test case does not match definition ${definition.id}.',
      );
    }
    if (command.profileId.trim().isEmpty) {
      issues.add('Target profile ID is required.');
    }
    _validateSchema(definition.inputSchema, command.inputs, '', issues);
    return List<String>.unmodifiable(issues);
  }

  void _validateSchema(
    TestInputSchema schema,
    Map<String, Object?> values,
    String prefix,
    List<String> issues,
  ) {
    for (final field in schema.fields) {
      if (!_isVisible(field, values)) continue;
      final value = values[field.path];
      final path = prefix.isEmpty ? field.path : '$prefix.${field.path}';
      if (value == null) {
        if (field.required) issues.add('$path is required.');
        continue;
      }
      if (!_matchesType(value, field.type)) {
        issues.add('$path must be a ${field.type.name}.');
        continue;
      }
      _validateRules(field, value, path, issues);
      if (field.type == TestInputFieldType.list && field.itemSchema != null) {
        final entries = value as List<Object?>;
        for (var index = 0; index < entries.length; index++) {
          final entry = entries[index];
          if (entry is! Map) {
            issues.add('$path[$index] must be an object.');
            continue;
          }
          _validateSchema(
            field.itemSchema!,
            entry.cast<String, Object?>(),
            '$path[$index]',
            issues,
          );
        }
      }
    }
  }

  bool _isVisible(TestInputField field, Map<String, Object?> values) {
    final condition = field.visibleWhen;
    if (condition == null || condition.isEmpty) return true;
    return condition.entries.every((entry) {
      final actual = values[entry.key];
      // A missing value uses the contract's conventional same-for-all
      // strategy. This keeps the compact JSON payload backwards-compatible.
      return actual == entry.value ||
          (actual == null && entry.value == 'sameForAll');
    });
  }

  bool _matchesType(Object value, TestInputFieldType type) => switch (type) {
    TestInputFieldType.text ||
    TestInputFieldType.singleSelect ||
    TestInputFieldType.multiSelect => value is String,
    TestInputFieldType.integer => value is num && value.toInt() == value,
    TestInputFieldType.decimal => value is num,
    TestInputFieldType.boolean => value is bool,
    TestInputFieldType.object => value is Map,
    TestInputFieldType.list => value is List,
  };

  void _validateRules(
    TestInputField field,
    Object value,
    String path,
    List<String> issues,
  ) {
    final rules = field.validation;
    if (value is num) {
      if (rules.minimum != null && value < rules.minimum!) {
        issues.add('$path must be at least ${rules.minimum}.');
      }
      if (rules.maximum != null && value > rules.maximum!) {
        issues.add('$path must be at most ${rules.maximum}.');
      }
    }
    if (value is String) {
      if (rules.pattern != null && !RegExp(rules.pattern!).hasMatch(value)) {
        issues.add('$path has an invalid format.');
      }
      if (field.choices.isNotEmpty &&
          !field.choices.any((choice) => choice.value == value)) {
        issues.add('$path must be one of the supported values.');
      }
    }
    if (value is List) {
      if (rules.minimumItems != null && value.length < rules.minimumItems!) {
        issues.add(
          '$path must contain at least ${rules.minimumItems} item(s).',
        );
      }
      if (rules.maximumItems != null && value.length > rules.maximumItems!) {
        issues.add('$path must contain at most ${rules.maximumItems} item(s).');
      }
    }
  }
}
