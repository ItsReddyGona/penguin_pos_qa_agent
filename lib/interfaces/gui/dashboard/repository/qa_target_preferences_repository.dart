import 'dart:convert';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_credential_vault.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores dashboard preferences and the non-secret SSH target configuration.
class QaTargetPreferencesRepository {
  static const _usernameKey = 'ssh.username';
  static const _hostKey = 'ssh.host';
  static const _enabledKey = 'ssh.enabled';
  static const _portKey = 'ssh.port';
  static const _identityFileKey = 'ssh.identity_file';
  static const _sshAppRootKey = 'ssh.app_root';
  static const _sshFlutterPathKey = 'ssh.flutter_path';
  static const _sshTargetsKey = 'qa.ssh_targets.v1';
  static const _defaultSshProfileId = 'default';
  static const _profilesKey = 'qa.target_profiles.v1';
  static const _selectedProfileIdKey = 'qa.selected_profile_id.v1';
  static const _aiModeKey = 'qa.ai_mode.v1';
  static const _aiModelConfigKey = 'qa.ai_model_config.v1';
  static const _initialSetupCompleteKey = 'qa.initial_setup_complete.v1';
  static const _noticeDisplayModeKey = 'qa.notice_display_mode.v1';
  static const _flutterPathKey = 'qa.flutter_path.v1';
  static const _appRootKey = 'qa.app_root.v1';

  final Future<SharedPreferences> Function() _preferencesProvider;
  final QaCredentialVault _credentialVault;

  QaTargetPreferencesRepository({
    Future<SharedPreferences> Function()? preferencesProvider,
    QaCredentialVault? credentialVault,
  }) : _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance,
       _credentialVault = credentialVault ?? QaCredentialVault();

  Future<String?> loadFlutterPath() async {
    final preferences = await _preferencesProvider();
    return preferences.getString(_flutterPathKey);
  }

  Future<void> saveFlutterPath(String path) async {
    final preferences = await _preferencesProvider();
    await preferences.setString(_flutterPathKey, path);
  }

  Future<String?> loadAppRoot() async {
    final preferences = await _preferencesProvider();
    return preferences.getString(_appRootKey);
  }

  Future<void> saveAppRoot(String path) async {
    final preferences = await _preferencesProvider();
    await preferences.setString(_appRootKey, path);
  }

  Future<QaSshTarget> loadSshTarget({String? profileId}) async {
    final preferences = await _preferencesProvider();
    final id = profileId ?? _defaultSshProfileId;
    final rawTargets = preferences.getString(_sshTargetsKey);
    if (rawTargets != null && rawTargets.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTargets);
        if (decoded is Map) {
          final targetJson = decoded[id];
          if (targetJson is Map) {
            return _sshTargetFromJson(targetJson);
          }
        }
      } catch (_) {
        // Fall back to the legacy single-target keys below.
      }
    }
    if (id != _defaultSshProfileId) {
      final legacy = await loadSshTarget();
      if (!_isEmptySshTarget(legacy)) return legacy;
    }
    return QaSshTarget(
      enabled: preferences.getBool(_enabledKey) ?? false,
      username: preferences.getString(_usernameKey) ?? '',
      host: preferences.getString(_hostKey) ?? '',
      port: preferences.getString(_portKey) ?? '',
      identityFile: preferences.getString(_identityFileKey) ?? '',
      appRoot: preferences.getString(_sshAppRootKey) ?? '',
      flutterPath: preferences.getString(_sshFlutterPathKey) ?? '',
    );
  }

  Future<void> saveSshTarget(QaSshTarget target, {String? profileId}) async {
    final preferences = await _preferencesProvider();
    final id = profileId ?? _defaultSshProfileId;
    final targets = <String, Object?>{};
    final rawTargets = preferences.getString(_sshTargetsKey);
    if (rawTargets != null && rawTargets.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTargets);
        if (decoded is Map) {
          targets.addAll(decoded.cast<String, Object?>());
        }
      } catch (_) {}
    }
    targets[id] = _sshTargetToJson(target);
    await preferences.setString(_sshTargetsKey, jsonEncode(targets));
    if (id == _defaultSshProfileId) {
      await preferences.setBool(_enabledKey, target.enabled);
      await preferences.setString(_usernameKey, target.username);
      await preferences.setString(_hostKey, target.host);
      await preferences.setString(_portKey, target.port);
      await preferences.setString(_identityFileKey, target.identityFile);
      await preferences.setString(_sshAppRootKey, target.appRoot);
      await preferences.setString(_sshFlutterPathKey, target.flutterPath);
    }
  }

  Future<bool> loadSshEnabled({String? profileId}) async =>
      (await loadSshTarget(profileId: profileId)).enabled;

  Future<void> saveSshEnabled(bool enabled, {String? profileId}) async {
    final current = await loadSshTarget(profileId: profileId);
    await saveSshTarget(
      current.copyWith(enabled: enabled),
      profileId: profileId,
    );
  }

  /// Uses the existing credential boundary so the repository never persists
  /// an SSH password directly through SharedPreferences.
  Future<String> loadSshPassword({String? profileId}) async {
    var credentials = await _credentialVault.read(_sshCredentialId(profileId));
    if (credentials.password.isEmpty &&
        (profileId == null || profileId == _defaultSshProfileId)) {
      credentials = await _credentialVault.read('ssh-target');
    }
    return credentials.password;
  }

  Future<void> saveSshPassword(String password, {String? profileId}) async {
    await _credentialVault.write(
      _sshCredentialId(profileId),
      QaStoredCredentials(password: password),
    );
  }

  static String _sshCredentialId(String? profileId) =>
      'ssh-target-${profileId ?? _defaultSshProfileId}';

  static Map<String, Object?> _sshTargetToJson(QaSshTarget target) =>
      <String, Object?>{
        'enabled': target.enabled,
        'host': target.host,
        'username': target.username,
        'port': target.port,
        'identityFile': target.identityFile,
        'appRoot': target.appRoot,
        'flutterPath': target.flutterPath,
      };

  static QaSshTarget _sshTargetFromJson(Map target) => QaSshTarget(
    enabled: target['enabled'] as bool? ?? false,
    host: target['host'] as String? ?? '',
    username: target['username'] as String? ?? '',
    port: target['port'] as String? ?? '',
    identityFile: target['identityFile'] as String? ?? '',
    appRoot: target['appRoot'] as String? ?? '',
    flutterPath: target['flutterPath'] as String? ?? '',
  );

  static bool _isEmptySshTarget(QaSshTarget target) =>
      !target.enabled &&
      target.host.isEmpty &&
      target.username.isEmpty &&
      target.port.isEmpty &&
      target.identityFile.isEmpty &&
      target.appRoot.isEmpty &&
      target.flutterPath.isEmpty;

  Future<List<QaProfile>> loadProfiles() async {
    final preferences = await _preferencesProvider();
    final raw = preferences.getString(_profilesKey);
    if (raw == null || raw.isEmpty) return QaProfile.values;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return QaProfile.values;
      final profiles = decoded
          .whereType<Map>()
          .map((profile) => QaProfile.fromJson(profile.cast<String, Object?>()))
          .where(
            (profile) =>
                profile.id.isNotEmpty &&
                profile.label.isNotEmpty &&
                profile.entity.isNotEmpty &&
                profile.environment.isNotEmpty,
          )
          .toList();
      return profiles.isEmpty ? QaProfile.values : profiles;
    } catch (_) {
      return QaProfile.values;
    }
  }

  Future<void> saveProfiles(List<QaProfile> profiles) async {
    final preferences = await _preferencesProvider();
    await preferences.setString(
      _profilesKey,
      jsonEncode(profiles.map((profile) => profile.toJson()).toList()),
    );
  }

  Future<String?> loadSelectedProfileId() async {
    final preferences = await _preferencesProvider();
    return preferences.getString(_selectedProfileIdKey);
  }

  Future<void> saveSelectedProfileId(String profileId) async {
    final preferences = await _preferencesProvider();
    await preferences.setString(_selectedProfileIdKey, profileId);
  }

  Future<bool> loadAiModeEnabled() async {
    final preferences = await _preferencesProvider();
    return preferences.getBool(_aiModeKey) ?? true;
  }

  Future<void> saveAiModeEnabled(bool enabled) async {
    final preferences = await _preferencesProvider();
    await preferences.setBool(_aiModeKey, enabled);
  }

  Future<QaTestNoticeDisplayMode> loadNoticeDisplayMode() async {
    final preferences = await _preferencesProvider();
    final saved = preferences.getString(_noticeDisplayModeKey);
    return QaTestNoticeDisplayMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => QaTestNoticeDisplayMode.warningsAndErrors,
    );
  }

  Future<void> saveNoticeDisplayMode(QaTestNoticeDisplayMode mode) async {
    final preferences = await _preferencesProvider();
    await preferences.setString(_noticeDisplayModeKey, mode.name);
  }

  Future<AiModelConfig> loadAiModelConfig() async {
    final preferences = await _preferencesProvider();
    final raw = preferences.getString(_aiModelConfigKey);
    if (raw == null || raw.isEmpty) return const AiModelConfig();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const AiModelConfig();
      return AiModelConfig.fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      return const AiModelConfig();
    }
  }

  Future<void> saveAiModelConfig(AiModelConfig config) async {
    final preferences = await _preferencesProvider();
    await preferences.setString(_aiModelConfigKey, config.encode());
  }

  /// Tracks whether the user has saved at least one reusable QA preference.
  /// This is deliberately separate from the built-in profile presets: presets
  /// are examples, while this value records an intentional user setup.
  Future<bool> hasCompletedInitialSetup() async {
    final preferences = await _preferencesProvider();
    return preferences.getBool(_initialSetupCompleteKey) ?? false;
  }

  Future<void> markInitialSetupComplete() async {
    final preferences = await _preferencesProvider();
    await preferences.setBool(_initialSetupCompleteKey, true);
  }
}
