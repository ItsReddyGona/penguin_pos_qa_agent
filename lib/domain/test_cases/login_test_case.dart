/// The observable outcome that a configured login test case must prove.
enum LoginExpectedResult {
  authenticationRejected,
  requiredFieldValidation,
  successfulLogin,
  idlePinRejected,
  idlePinAccepted;

  String get storageValue => switch (this) {
    LoginExpectedResult.authenticationRejected => 'authentication_rejected',
    LoginExpectedResult.requiredFieldValidation => 'required_field_validation',
    LoginExpectedResult.successfulLogin => 'successful_login',
    LoginExpectedResult.idlePinRejected => 'idle_pin_rejected',
    LoginExpectedResult.idlePinAccepted => 'idle_pin_accepted',
  };

  String get label => switch (this) {
    LoginExpectedResult.authenticationRejected => 'Invalid credentials',
    LoginExpectedResult.requiredFieldValidation => 'Validation error',
    LoginExpectedResult.successfulLogin => 'Successful login',
    LoginExpectedResult.idlePinRejected => 'Idle PIN rejected',
    LoginExpectedResult.idlePinAccepted => 'Idle PIN accepted',
  };

  static LoginExpectedResult? tryParse(Object? value) {
    if (value is! String) return null;
    // Versions before the complete-login lifecycle treated reaching the
    // terminal or home screen as separate successful outcomes. Both now mean
    // the atomic successful-login flow (authenticate, reach home, log out).
    if (value == 'terminal_selection_shown' ||
        value == 'terminalSelectionShown' ||
        value == 'home_screen_reached' ||
        value == 'homeScreenReached') {
      return LoginExpectedResult.successfulLogin;
    }
    for (final result in values) {
      if (result.storageValue == value || result.name == value) return result;
    }
    return null;
  }
}

/// A user-configured row in the profile-scoped login test suite.
///
/// Credentials are runtime-only model fields. [toJson] intentionally exports
/// only safe metadata so callers cannot accidentally include secrets in plans,
/// logs, reports, model prompts, or telemetry.
class LoginTestCaseDefinition {
  const LoginTestCaseDefinition({
    required this.id,
    required this.name,
    required this.expectedResult,
    this.description = '',
    this.username = '',
    this.password = '',
    this.pin = '',
    this.enabled = true,
  });

  final String id;
  final String name;
  final String description;
  final String username;
  final String password;
  final String pin;
  final LoginExpectedResult expectedResult;
  final bool enabled;

  bool get hasUsername => username.isNotEmpty;
  bool get hasPassword => password.isNotEmpty;
  bool get hasPin => pin.isNotEmpty;

  /// A report-safe representation of the configured credentials.
  String get credentialsSummary => <String>[
    'Username: ${_masked(username, preserveEdges: true)}',
    'Password: ${_masked(password)}',
    if (pin.isNotEmpty) 'PIN: ${_masked(pin)}',
  ].join(', ');

  LoginTestCaseDefinition copyWith({
    String? id,
    String? name,
    String? description,
    String? username,
    String? password,
    String? pin,
    LoginExpectedResult? expectedResult,
    bool? enabled,
  }) => LoginTestCaseDefinition(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    username: username ?? this.username,
    password: password ?? this.password,
    pin: pin ?? this.pin,
    expectedResult: expectedResult ?? this.expectedResult,
    enabled: enabled ?? this.enabled,
  );

  /// Safe metadata export. Raw credential fields are deliberately omitted.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'description': description,
    'expectedResult': expectedResult.storageValue,
    'enabled': enabled,
  };

  @override
  String toString() => 'LoginTestCaseDefinition(${toJson()})';

  static String _masked(String value, {bool preserveEdges = false}) {
    if (value.isEmpty) return '<empty>';
    if (!preserveEdges || value.length < 5) return _bullets(value.length);
    return '${value.substring(0, 2)}${_bullets(value.length - 4)}'
        '${value.substring(value.length - 2)}';
  }

  static String _bullets(int count) => List.filled(count, '•').join();
}

enum LoginTestCaseStatus {
  passed,
  failed,
  notExecuted,
  pending,
  running;

  String get label => switch (this) {
    LoginTestCaseStatus.passed => 'Pass',
    LoginTestCaseStatus.failed => 'Fail',
    LoginTestCaseStatus.notExecuted => 'Not executed',
    LoginTestCaseStatus.pending => 'Pending',
    LoginTestCaseStatus.running => 'Running',
  };
}

/// One report-safe login case outcome shared by Manual and AI surfaces.
class LoginTestCaseResult {
  const LoginTestCaseResult({
    required this.testCaseId,
    required this.testCase,
    required this.description,
    required this.credentials,
    required this.status,
    required this.startedAt,
    required this.finishedAt,
    this.failureReason,
  });

  factory LoginTestCaseResult.fromDefinition({
    required LoginTestCaseDefinition definition,
    required LoginTestCaseStatus status,
    required DateTime startedAt,
    required DateTime finishedAt,
    String? failureReason,
  }) => LoginTestCaseResult(
    testCaseId: definition.id,
    testCase: definition.name,
    description: definition.description,
    credentials: definition.credentialsSummary,
    status: status,
    startedAt: startedAt,
    finishedAt: finishedAt,
    failureReason: _redact(failureReason, <String>[
      definition.username,
      definition.password,
      definition.pin,
    ]),
  );

  final String testCaseId;
  final String testCase;
  final String description;

  /// Already-masked summary. This object never receives raw credentials.
  final String credentials;
  final LoginTestCaseStatus status;
  final DateTime startedAt;
  final DateTime finishedAt;
  final String? failureReason;

  bool get passed => status == LoginTestCaseStatus.passed;
  Duration get duration => finishedAt.difference(startedAt);

  Map<String, Object?> toJson() => <String, Object?>{
    'testCaseId': testCaseId,
    'testCase': testCase,
    'description': description,
    'credentials': credentials,
    'status': status.name,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'finishedAt': finishedAt.toUtc().toIso8601String(),
    if (failureReason != null) 'failureReason': failureReason,
  };

  static String? _redact(String? text, List<String> secrets) {
    var result = text;
    if (result == null) return null;
    for (final secret in secrets.where((value) => value.isNotEmpty)) {
      result = result!.replaceAll(secret, '[REDACTED]');
    }
    return result;
  }
}

/// Aggregate result for an isolated, continue-on-failure login suite run.
class LoginSuiteResult {
  const LoginSuiteResult({
    required this.results,
    required this.startedAt,
    required this.finishedAt,
    this.infrastructureError,
  });

  final List<LoginTestCaseResult> results;
  final DateTime startedAt;
  final DateTime finishedAt;
  final String? infrastructureError;

  int get totalCount => results.length;
  int get passedCount => results
      .where((result) => result.status == LoginTestCaseStatus.passed)
      .length;
  int get failedCount => results
      .where((result) => result.status == LoginTestCaseStatus.failed)
      .length;
  int get notExecutedCount => results
      .where((result) => result.status == LoginTestCaseStatus.notExecuted)
      .length;
  bool get passed =>
      infrastructureError == null &&
      results.isNotEmpty &&
      failedCount == 0 &&
      notExecutedCount == 0;
  Duration get duration => finishedAt.difference(startedAt);

  Map<String, Object?> toJson() => <String, Object?>{
    'passed': passed,
    'totalCount': totalCount,
    'passedCount': passedCount,
    'failedCount': failedCount,
    'notExecutedCount': notExecutedCount,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'finishedAt': finishedAt.toUtc().toIso8601String(),
    if (infrastructureError != null) 'infrastructureError': infrastructureError,
    'results': results.map((result) => result.toJson()).toList(growable: false),
  };
}
