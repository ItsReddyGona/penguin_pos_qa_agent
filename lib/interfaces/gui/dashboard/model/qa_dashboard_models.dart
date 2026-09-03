export 'package:penguin_pos_qa_agent/domain/profiles/qa_target_mode.dart';

enum QaActivityKind { info, success, error }

class QaActivityMessage {
  QaActivityMessage(this.title, this.body, this.kind, {DateTime? at})
    : at = at ?? DateTime.now();

  final String title;
  final String body;
  final QaActivityKind kind;
  final DateTime at;
}

/// Persisted SSH target configuration.
///
/// Secrets are intentionally kept out of this value object. The SSH password
/// is loaded through the credential-vault abstraction by the preferences
/// repository.
class QaSshTarget {
  const QaSshTarget({
    this.enabled = false,
    this.host = '',
    this.username = '',
    this.port = '',
    this.identityFile = '',
    this.appRoot = '',
    this.flutterPath = '',
  });

  final bool enabled;
  final String host;
  final String username;
  final String port;
  final String identityFile;
  final String appRoot;
  final String flutterPath;

  QaSshTarget copyWith({
    bool? enabled,
    String? host,
    String? username,
    String? port,
    String? identityFile,
    String? appRoot,
    String? flutterPath,
  }) {
    return QaSshTarget(
      enabled: enabled ?? this.enabled,
      host: host ?? this.host,
      username: username ?? this.username,
      port: port ?? this.port,
      identityFile: identityFile ?? this.identityFile,
      appRoot: appRoot ?? this.appRoot,
      flutterPath: flutterPath ?? this.flutterPath,
    );
  }
}
