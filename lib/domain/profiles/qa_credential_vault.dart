import 'package:shared_preferences/shared_preferences.dart';

class QaStoredCredentials {
  const QaStoredCredentials({
    this.loginId = '',
    this.password = '',
    this.unlockPin = '',
  });

  final String loginId;
  final String password;
  final String unlockPin;

  bool get hasLoginCredentials => loginId.isNotEmpty && password.isNotEmpty;
}

/// Stores local QA credentials by profile.
///
/// This desktop agent intentionally uses SharedPreferences so local debug
/// builds do not depend on macOS Keychain entitlements or code signing.
class QaCredentialVault {
  String _key(String profileId, String field) => 'qa.profile.$profileId.$field';

  Future<QaStoredCredentials> read(String profileId) async {
    final preferences = await SharedPreferences.getInstance();
    return QaStoredCredentials(
      loginId: preferences.getString(_key(profileId, 'login_id')) ?? '',
      password: preferences.getString(_key(profileId, 'password')) ?? '',
      unlockPin: preferences.getString(_key(profileId, 'unlock_pin')) ?? '',
    );
  }

  Future<void> write(String profileId, QaStoredCredentials credentials) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key(profileId, 'login_id'),
      credentials.loginId,
    );
    await preferences.setString(
      _key(profileId, 'password'),
      credentials.password,
    );
    await preferences.setString(
      _key(profileId, 'unlock_pin'),
      credentials.unlockPin,
    );
  }

  Future<String> readAiApiKey() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString('qa.ai.api_key') ?? '';
  }

  Future<void> writeAiApiKey(String apiKey) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('qa.ai.api_key', apiKey);
  }
}
