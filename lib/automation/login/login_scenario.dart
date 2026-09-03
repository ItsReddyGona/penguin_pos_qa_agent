import 'package:penguin_pos_qa_agent/automation/login/login_keys.dart';

/// Data payload model for a login scenario execution.
class LoginScenario {
  const LoginScenario({
    required this.id,
    required this.name,
    required this.loginId,
    required this.password,
    this.unlockPin,
    this.terminalContinueKey = PenguinPosLoginKeys.terminalContinue,
    this.expectedKey = PenguinPosLoginKeys.homeScreen,
  });

  final String id;
  final String name;
  final String loginId;
  final String password;

  /// Passcode used only when the app opens with an active idle-timeout lock.
  ///
  /// It is intentionally optional because a fresh app can start on Login, but
  /// no default is used when an existing session is locked.
  final String? unlockPin;
  final String terminalContinueKey;
  final String expectedKey;

  /// Safe scenario metadata for diagnostics. Login credentials and the
  /// terminal unlock PIN intentionally remain runtime-only.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'terminalContinueKey': terminalContinueKey,
    'expectedKey': expectedKey,
  };
}
