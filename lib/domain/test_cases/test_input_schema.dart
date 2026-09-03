enum TestInputFieldType {
  text,
  integer,
  decimal,
  boolean,
  singleSelect,
  multiSelect,
  object,
  list,
}

extension TestInputFieldTypeJson on TestInputFieldType {
  static TestInputFieldType fromJson(Object? value) => switch (value) {
    'integer' => TestInputFieldType.integer,
    'decimal' => TestInputFieldType.decimal,
    'boolean' => TestInputFieldType.boolean,
    'singleSelect' => TestInputFieldType.singleSelect,
    'multiSelect' => TestInputFieldType.multiSelect,
    'object' => TestInputFieldType.object,
    'list' => TestInputFieldType.list,
    _ => TestInputFieldType.text,
  };
}

/// A fixed choice offered by a [TestInputField].
class TestInputChoice {
  const TestInputChoice({required this.value, required this.label});

  final String value;
  final String label;

  Map<String, Object?> toJson() => <String, Object?>{
    'value': value,
    'label': label,
  };

  factory TestInputChoice.fromJson(Map<String, Object?> json) =>
      TestInputChoice(
        value: (json['value'] as String?) ?? '',
        label: (json['label'] as String?) ?? '',
      );
}

/// Validation rules which can be shared by manual and AI-created plans.
class TestInputValidation {
  const TestInputValidation({
    this.minimum,
    this.maximum,
    this.pattern,
    this.minimumItems,
    this.maximumItems,
  });

  final num? minimum;
  final num? maximum;
  final String? pattern;
  final int? minimumItems;
  final int? maximumItems;

  Map<String, Object?> toJson() => <String, Object?>{
    if (minimum != null) 'minimum': minimum,
    if (maximum != null) 'maximum': maximum,
    if (pattern != null) 'pattern': pattern,
    if (minimumItems != null) 'minimumItems': minimumItems,
    if (maximumItems != null) 'maximumItems': maximumItems,
  };

  factory TestInputValidation.fromJson(Map<String, Object?> json) =>
      TestInputValidation(
        minimum: json['minimum'] as num?,
        maximum: json['maximum'] as num?,
        pattern: json['pattern'] as String?,
        minimumItems: (json['minimumItems'] as num?)?.toInt(),
        maximumItems: (json['maximumItems'] as num?)?.toInt(),
      );
}

/// A schema-owned, deterministic update applied after a text field changes.
class TestInputAutoFillRule {
  const TestInputAutoFillRule({
    required this.pattern,
    required this.values,
    this.caseSensitive = false,
  });

  final String pattern;
  final Map<String, Object?> values;
  final bool caseSensitive;

  Map<String, Object?> toJson() => <String, Object?>{
    'pattern': pattern,
    'values': values,
    'caseSensitive': caseSensitive,
  };

  factory TestInputAutoFillRule.fromJson(Map<String, Object?> json) =>
      TestInputAutoFillRule(
        pattern: (json['pattern'] as String?) ?? '',
        values:
            (json['values'] as Map?)?.cast<String, Object?>() ??
            const <String, Object?>{},
        caseSensitive: (json['caseSensitive'] as bool?) ?? false,
      );
}

/// One input in a test case's portable input contract.
class TestInputField {
  const TestInputField({
    required this.path,
    required this.label,
    required this.type,
    this.helpText,
    this.required = false,
    this.sensitive = false,
    this.choices = const <TestInputChoice>[],
    this.validation = const TestInputValidation(),
    this.visibleWhen,
    this.itemSchema,
    this.layoutGroup,
    this.defaultValue,
    this.autoFillRules = const <TestInputAutoFillRule>[],
  });

  final String path;
  final String label;
  final TestInputFieldType type;
  final String? helpText;
  final bool required;
  final bool sensitive;
  final List<TestInputChoice> choices;
  final TestInputValidation validation;
  final Map<String, Object?>? visibleWhen;
  final TestInputSchema? itemSchema;
  final String? layoutGroup;
  final Object? defaultValue;
  final List<TestInputAutoFillRule> autoFillRules;

  Map<String, Object?> toJson() => <String, Object?>{
    'path': path,
    'label': label,
    'type': type.name,
    if (helpText != null) 'helpText': helpText,
    'required': required,
    'sensitive': sensitive,
    if (choices.isNotEmpty)
      'choices': choices.map((choice) => choice.toJson()).toList(),
    if (validation.toJson().isNotEmpty) 'validation': validation.toJson(),
    if (visibleWhen != null) 'visibleWhen': visibleWhen,
    if (itemSchema != null) 'itemSchema': itemSchema!.toJson(),
    if (layoutGroup != null) 'layoutGroup': layoutGroup,
    if (defaultValue != null) 'defaultValue': defaultValue,
    if (autoFillRules.isNotEmpty)
      'autoFillRules': autoFillRules.map((rule) => rule.toJson()).toList(),
  };

  factory TestInputField.fromJson(Map<String, Object?> json) {
    final choices = (json['choices'] as List<Object?>? ?? const <Object?>[])
        .whereType<Map>()
        .map(
          (choice) => TestInputChoice.fromJson(choice.cast<String, Object?>()),
        )
        .toList(growable: false);
    final validation = json['validation'];
    final itemSchema = json['itemSchema'];
    final autoFillRules =
        (json['autoFillRules'] as List<Object?>? ?? const <Object?>[])
            .whereType<Map>()
            .map(
              (rule) =>
                  TestInputAutoFillRule.fromJson(rule.cast<String, Object?>()),
            )
            .toList(growable: false);
    return TestInputField(
      path: (json['path'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      type: TestInputFieldTypeJson.fromJson(json['type']),
      helpText: json['helpText'] as String?,
      required: (json['required'] as bool?) ?? false,
      sensitive: (json['sensitive'] as bool?) ?? false,
      choices: choices,
      validation: validation is Map
          ? TestInputValidation.fromJson(validation.cast<String, Object?>())
          : const TestInputValidation(),
      visibleWhen: (json['visibleWhen'] as Map?)?.cast<String, Object?>(),
      itemSchema: itemSchema is Map
          ? TestInputSchema.fromJson(itemSchema.cast<String, Object?>())
          : null,
      layoutGroup: json['layoutGroup'] as String?,
      defaultValue: json['defaultValue'],
      autoFillRules: autoFillRules,
    );
  }
}

/// The full portable input contract for a test case.
class TestInputSchema {
  const TestInputSchema({required this.fields, this.title, this.description});

  final String? title;
  final String? description;
  final List<TestInputField> fields;

  Map<String, Object?> toJson() => <String, Object?>{
    if (title != null) 'title': title,
    if (description != null) 'description': description,
    'fields': fields.map((field) => field.toJson()).toList(),
  };

  factory TestInputSchema.fromJson(Map<String, Object?> json) =>
      TestInputSchema(
        title: json['title'] as String?,
        description: json['description'] as String?,
        fields: (json['fields'] as List<Object?>? ?? const <Object?>[])
            .whereType<Map>()
            .map(
              (field) => TestInputField.fromJson(field.cast<String, Object?>()),
            )
            .toList(growable: false),
      );
}
