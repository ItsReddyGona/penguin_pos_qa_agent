import 'package:penguin_pos_qa_agent/domain/test_cases/test_input_schema.dart';

/// A JSON-compatible test case feature that interfaces can catalogue, edit,
/// validate, and run without depending on Flutter or an automation runner.
class TestCaseDefinition {
  const TestCaseDefinition({
    required this.id,
    required this.name,
    required this.runnerTemplateId,
    required this.inputSchema,
    this.schemaVersion = 1,
    this.description = '',
    this.category = '',
    this.tags = const <String>[],
    this.preconditions = const <String>[],
    this.expectedOutcomes = const <String>[],
    this.isEnabled = true,
    this.isBuiltIn = false,
    this.customRendererId,
    this.metadata = const <String, Object?>{},
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String id;
  final String name;
  final String description;
  final String category;
  final List<String> tags;
  final List<String> preconditions;
  final List<String> expectedOutcomes;
  final String runnerTemplateId;
  final TestInputSchema inputSchema;
  final bool isEnabled;
  final bool isBuiltIn;
  final String? customRendererId;
  final Map<String, Object?> metadata;

  bool get usesCustomRenderer =>
      customRendererId != null && customRendererId!.trim().isNotEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'id': id,
    'name': name,
    'description': description,
    'category': category,
    'tags': tags,
    'preconditions': preconditions,
    'expectedOutcomes': expectedOutcomes,
    'runnerTemplateId': runnerTemplateId,
    'inputSchema': inputSchema.toJson(),
    'isEnabled': isEnabled,
    'isBuiltIn': isBuiltIn,
    if (customRendererId != null) 'customRendererId': customRendererId,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };

  factory TestCaseDefinition.fromJson(Map<String, Object?> json) {
    final inputSchema = json['inputSchema'];
    return TestCaseDefinition(
      schemaVersion:
          (json['schemaVersion'] as num?)?.toInt() ?? currentSchemaVersion,
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      category: (json['category'] as String?) ?? '',
      tags: _stringList(json['tags']),
      preconditions: _stringList(json['preconditions']),
      expectedOutcomes: _stringList(json['expectedOutcomes']),
      runnerTemplateId: (json['runnerTemplateId'] as String?) ?? '',
      inputSchema: inputSchema is Map
          ? TestInputSchema.fromJson(inputSchema.cast<String, Object?>())
          : const TestInputSchema(fields: <TestInputField>[]),
      isEnabled: (json['isEnabled'] as bool?) ?? true,
      isBuiltIn: (json['isBuiltIn'] as bool?) ?? false,
      customRendererId: json['customRendererId'] as String?,
      metadata:
          (json['metadata'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{},
    );
  }

  static List<String> _stringList(Object? value) =>
      (value as List<Object?>? ?? const <Object?>[]).whereType<String>().toList(
        growable: false,
      );
}
