/// Trusted, non-secret launch profiles for PenguinPOS QA.
///
/// A profile prevents an LLM from repeatedly asking for the same entity and
/// environment. Credentials intentionally do not belong here.
class QaProfile {
  const QaProfile({
    required this.name,
    required this.entity,
    required this.env,
  });

  final String name;
  final String entity;
  final String env;
}

abstract final class QaProfileConfig {
  static const defaultProfile = 'ibo-stage';

  static const profiles = <String, QaProfile>{
    defaultProfile: QaProfile(
      name: defaultProfile,
      entity: 'ibo',
      env: 'stage',
    ),
    'ibo-dev': QaProfile(name: 'ibo-dev', entity: 'ibo', env: 'dev'),
    'kpn-stage': QaProfile(name: 'kpn-stage', entity: 'kpn', env: 'stage'),
    'savomart-stage': QaProfile(
      name: 'savomart-stage',
      entity: 'savomart',
      env: 'stage',
    ),
  };

  static QaProfile resolve(String? name) {
    final profile = profiles[name ?? defaultProfile];
    if (profile == null) throw ArgumentError('Unknown QA profile: $name.');
    return profile;
  }
}
