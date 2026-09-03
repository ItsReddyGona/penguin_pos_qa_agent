/// A configured non-production target available to the desktop QA Agent.
///
/// This is domain data used by planning, execution, and the GUI. It is kept
/// separate from `runtime/qa_profile_config.dart`, which remains the CLI/MCP
/// runtime profile configuration.
class QaProfile {
  const QaProfile({
    required this.id,
    required this.label,
    required this.entity,
    required this.environment,
    this.aliases = const <String>[],
  });

  final String id;
  final String label;
  final String entity;
  final String environment;
  final List<String> aliases;

  /// Production targets are never executable from the QA Agent. Check the
  /// configured environment as well as the visible profile identity so a
  /// misconfigured profile cannot bypass the execution guard.
  bool get isProduction {
    final values = <String>[id, label, environment]
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty);
    final productionToken = RegExp(
      r'(^|[-_\s])(prod|production|live)([-_\s]|$)',
    );
    return values.any((value) => productionToken.hasMatch(value));
  }

  QaProfile copyWith({
    String? id,
    String? label,
    String? entity,
    String? environment,
    List<String>? aliases,
  }) => QaProfile(
    id: id ?? this.id,
    label: label ?? this.label,
    entity: entity ?? this.entity,
    environment: environment ?? this.environment,
    aliases: aliases ?? this.aliases,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'label': label,
    'entity': entity,
    'environment': environment,
    'aliases': aliases,
  };

  factory QaProfile.fromJson(Map<String, Object?> json) => QaProfile(
    id: (json['id'] as String?) ?? '',
    label: (json['label'] as String?) ?? '',
    entity: (json['entity'] as String?) ?? '',
    environment: (json['environment'] as String?) ?? '',
    aliases: (json['aliases'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .toList(),
  );

  static const values = <QaProfile>[
    QaProfile(
      id: 'kpn-stage',
      label: 'KPN STAGE',
      entity: 'kpn',
      environment: 'stage',
      aliases: <String>['kpn-stage', 'kpn stage'],
    ),
    QaProfile(
      id: 'kpn-dev',
      label: 'KPN DEV',
      entity: 'kpn',
      environment: 'dev',
      aliases: <String>['kpn-dev', 'kpn dev'],
    ),
    QaProfile(
      id: 'ibo-stage',
      label: 'IBO STAGE',
      entity: 'ibo',
      environment: 'stage',
      aliases: <String>['ibo-stage', 'ibo stage'],
    ),
    QaProfile(
      id: 'ibo-dev',
      label: 'IBO DEV',
      entity: 'ibo',
      environment: 'dev',
      aliases: <String>['ibo-dev', 'ibo dev'],
    ),
    QaProfile(
      id: 'savomart-stage',
      label: 'SAVO STAGE',
      entity: 'savomart',
      environment: 'stage',
      aliases: <String>['savomart-stage', 'savo-stage', 'savomart stage'],
    ),
    QaProfile(
      id: 'savomart-dev',
      label: 'SAVO DEV',
      entity: 'savomart',
      environment: 'dev',
      aliases: <String>['savomart-dev', 'savo-dev', 'savomart dev'],
    ),
  ];
}
