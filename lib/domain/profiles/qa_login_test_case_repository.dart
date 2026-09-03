import 'dart:convert';

import 'package:penguin_pos_qa_agent/domain/profiles/qa_credential_vault.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/login_test_case.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Profile-scoped persistence boundary for configurable login test cases.
abstract interface class QaLoginTestCaseRepository {
  Future<List<LoginTestCaseDefinition>> read(String profileId);

  Future<void> write(String profileId, List<LoginTestCaseDefinition> testCases);

  Future<void> clear(String profileId);

  /// One-time bridge for profiles configured before row-based login cases.
  /// Existing credential values are reused and never replaced with defaults.
  Future<List<LoginTestCaseDefinition>> readOrMigrateLegacy(
    String profileId,
    QaStoredCredentials legacyCredentials,
  );
}

/// Stores safe row metadata separately from credential values.
///
/// SharedPreferences matches the existing [QaCredentialVault] persistence
/// boundary. It is not platform-secure storage; separating values here prevents
/// secrets from entering the JSON metadata consumed by generic app surfaces and
/// keeps a later secure-storage migration isolated to this repository.
class SharedPreferencesQaLoginTestCaseRepository
    implements QaLoginTestCaseRepository {
  SharedPreferencesQaLoginTestCaseRepository({
    Future<SharedPreferences> Function()? preferencesProvider,
  }) : _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance;

  static const int _schemaVersion = 1;
  final Future<SharedPreferences> Function() _preferencesProvider;

  String _metadataKey(String profileId) =>
      'qa.profile.$profileId.suite.login.test_cases.v1';

  String _credentialKey(String profileId, String caseId, String field) {
    final encodedId = base64Url.encode(utf8.encode(caseId)).replaceAll('=', '');
    return 'qa.profile.$profileId.suite.login.case.$encodedId.$field';
  }

  @override
  Future<List<LoginTestCaseDefinition>> read(String profileId) async {
    if (profileId.trim().isEmpty) return const <LoginTestCaseDefinition>[];
    final preferences = await _preferencesProvider();
    final raw = preferences.getString(_metadataKey(profileId));
    if (raw == null || raw.isEmpty) return const <LoginTestCaseDefinition>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const <LoginTestCaseDefinition>[];
      final rows = decoded['testCases'];
      if (rows is! List) return const <LoginTestCaseDefinition>[];

      final result = <LoginTestCaseDefinition>[];
      final seenIds = <String>{};
      for (final row in rows.whereType<Map>()) {
        final metadata = row.cast<String, Object?>();
        final id = (metadata['id'] as String?)?.trim() ?? '';
        final name = (metadata['name'] as String?) ?? '';
        final expected = LoginExpectedResult.tryParse(
          metadata['expectedResult'],
        );
        if (id.isEmpty || !seenIds.add(id) || expected == null) continue;

        result.add(
          LoginTestCaseDefinition(
            id: id,
            name: name,
            description: (metadata['description'] as String?) ?? '',
            username:
                preferences.getString(
                  _credentialKey(profileId, id, 'username'),
                ) ??
                '',
            password:
                preferences.getString(
                  _credentialKey(profileId, id, 'password'),
                ) ??
                '',
            pin:
                preferences.getString(_credentialKey(profileId, id, 'pin')) ??
                '',
            expectedResult: expected,
            enabled: (metadata['enabled'] as bool?) ?? true,
          ),
        );
      }
      return List<LoginTestCaseDefinition>.unmodifiable(result);
    } on FormatException {
      return const <LoginTestCaseDefinition>[];
    } on TypeError {
      return const <LoginTestCaseDefinition>[];
    }
  }

  @override
  Future<void> write(
    String profileId,
    List<LoginTestCaseDefinition> testCases,
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
    }

    final preferences = await _preferencesProvider();
    final previous = await read(profileId);
    final removedIds = previous
        .map((testCase) => testCase.id)
        .where((id) => !ids.contains(id));
    for (final id in removedIds) {
      await _removeCredentials(preferences, profileId, id);
    }

    for (final testCase in testCases) {
      await preferences.setString(
        _credentialKey(profileId, testCase.id, 'username'),
        testCase.username,
      );
      await preferences.setString(
        _credentialKey(profileId, testCase.id, 'password'),
        testCase.password,
      );
      await preferences.setString(
        _credentialKey(profileId, testCase.id, 'pin'),
        testCase.pin,
      );
    }

    await preferences.setString(
      _metadataKey(profileId),
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
    final previous = await read(profileId);
    for (final testCase in previous) {
      await _removeCredentials(preferences, profileId, testCase.id);
    }
    await preferences.remove(_metadataKey(profileId));
  }

  @override
  Future<List<LoginTestCaseDefinition>> readOrMigrateLegacy(
    String profileId,
    QaStoredCredentials legacyCredentials,
  ) async {
    final configured = await read(profileId);
    if (configured.isNotEmpty || !legacyCredentials.hasLoginCredentials) {
      return configured;
    }

    final migrated = <LoginTestCaseDefinition>[
      LoginTestCaseDefinition(
        id: 'legacy-valid-login',
        name: 'Valid login',
        description:
            'Sign in with the credentials previously saved for this profile.',
        username: legacyCredentials.loginId,
        password: legacyCredentials.password,
        pin: legacyCredentials.unlockPin,
        expectedResult: LoginExpectedResult.successfulLogin,
      ),
    ];
    await write(profileId, migrated);
    return List<LoginTestCaseDefinition>.unmodifiable(migrated);
  }

  Future<void> _removeCredentials(
    SharedPreferences preferences,
    String profileId,
    String caseId,
  ) async {
    for (final field in const <String>['username', 'password', 'pin']) {
      await preferences.remove(_credentialKey(profileId, caseId, field));
    }
  }
}
