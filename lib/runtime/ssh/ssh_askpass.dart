import 'dart:io';

typedef AskpassExecutableSetter = Future<void> Function(String path);

abstract interface class SshAskpassFactory {
  Future<SshAskpassSession?> create(String? password);
}

abstract interface class SshAskpassSession {
  Map<String, String> get environment;

  bool get isDisposed;

  Future<void> dispose();
}

class SystemSshAskpassFactory implements SshAskpassFactory {
  const SystemSshAskpassFactory({this.setExecutable = _setExecutable});

  final AskpassExecutableSetter setExecutable;

  @override
  Future<SshAskpassSession?> create(String? password) async {
    if (password == null) return null;

    final directory = await Directory.systemTemp.createTemp('qa-agent-ssh-');
    final script = File('${directory.path}/askpass.sh');
    await script.writeAsString(_askpassScript);
    await setExecutable(script.path);

    return SystemSshAskpassSession(
      directory: directory,
      environment: <String, String>{
        'SSH_ASKPASS': script.path,
        'SSH_ASKPASS_REQUIRE': 'force',
        // OpenSSH requires a display context before invoking SSH_ASKPASS on
        // some versions, even when SSH_ASKPASS_REQUIRE is force.
        'DISPLAY': Platform.environment['DISPLAY'] ?? ':0',
        'QA_AGENT_SSH_PASSWORD': password,
      },
    );
  }

  static Future<void> _setExecutable(String path) async {
    final result = await Process.run('chmod', <String>['700', path]);
    if (result.exitCode != 0) {
      throw StateError('Unable to make SSH askpass helper executable.');
    }
  }
}

class SystemSshAskpassSession implements SshAskpassSession {
  SystemSshAskpassSession({required this.directory, required this.environment});

  final Directory directory;
  @override
  final Map<String, String> environment;
  bool _disposed = false;

  @override
  bool get isDisposed => _disposed;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await directory.delete(recursive: true);
    } on FileSystemException {
      // Cleanup is best effort; no secret is written into the script itself.
    }
  }
}

const _askpassScript = '''#!/bin/sh
printf '%s\\n' "\$QA_AGENT_SSH_PASSWORD"
''';

class NoopSshAskpassFactory implements SshAskpassFactory {
  const NoopSshAskpassFactory();

  @override
  Future<SshAskpassSession?> create(String? password) async => null;
}
