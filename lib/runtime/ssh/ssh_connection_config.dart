/// Configuration for a Linux PenguinPOS target reached through system SSH.
///
/// [password] is runtime-only input. It is never included in SSH arguments,
/// JSON messages, metadata, or diagnostics. Prefer an identity file for
/// unattended execution; the password exists to support saved settings when
/// key authentication is not available.
class SshConnectionConfig {
  const SshConnectionConfig({
    required this.host,
    required this.username,
    this.port = 22,
    this.identityFile,
    required this.remoteAppRoot,
    this.remoteFlutterExecutable = 'flutter',
    this.password,
    this.connectTimeout = const Duration(seconds: 15),
    this.startupTimeout = const Duration(minutes: 2),
    this.stopTimeout = const Duration(seconds: 5),
  });

  final String host;
  final String username;
  final int port;
  final String? identityFile;
  final String remoteAppRoot;
  final String remoteFlutterExecutable;
  final String? password;
  final Duration connectTimeout;
  final Duration startupTimeout;
  final Duration stopTimeout;

  String get destination => '$username@$host';

  void validate() {
    if (host.trim().isEmpty) {
      throw ArgumentError.value(host, 'host', 'SSH host must not be empty.');
    }
    if (username.trim().isEmpty) {
      throw ArgumentError.value(
        username,
        'username',
        'SSH username must not be empty.',
      );
    }
    if (port < 1 || port > 65535) {
      throw ArgumentError.value(port, 'port', 'SSH port must be 1-65535.');
    }
    if (remoteAppRoot.trim().isEmpty) {
      throw ArgumentError.value(
        remoteAppRoot,
        'remoteAppRoot',
        'Remote app root must not be empty.',
      );
    }
    if (remoteFlutterExecutable.trim().isEmpty) {
      throw ArgumentError.value(
        remoteFlutterExecutable,
        'remoteFlutterExecutable',
        'Remote Flutter executable must not be empty.',
      );
    }
  }

  Map<String, Object?> toMetadata() => <String, Object?>{
    'host': host,
    'username': username,
    'port': port,
    'remoteAppRoot': remoteAppRoot,
    'remoteFlutterExecutable': remoteFlutterExecutable,
    'transport': 'flutter-machine',
  };
}
