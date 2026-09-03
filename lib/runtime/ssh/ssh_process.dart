import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// The small process surface needed by SSH runtime components.
///
/// Keeping [Process] behind this interface lets protocol and lifecycle tests
/// run without opening an SSH connection.
abstract interface class SshProcess {
  Stream<String> get stdoutLines;

  Stream<String> get stderrLines;

  Future<int> get exitCode;

  Future<void> writeLine(String line);

  Future<void> closeStdin();

  bool kill([ProcessSignal signal = ProcessSignal.sigterm]);
}

class SshProcessSpec {
  const SshProcessSpec({
    required this.executable,
    required this.arguments,
    required this.environment,
  });

  final String executable;
  final List<String> arguments;
  final Map<String, String> environment;
}

typedef SshProcessStarter = Future<SshProcess> Function(SshProcessSpec spec);

/// Starts the host's OpenSSH client without using a shell.
class SystemSshProcessStarter {
  const SystemSshProcessStarter({this.executable = 'ssh'});

  final String executable;

  Future<SshProcess> call(SshProcessSpec spec) async {
    final process = await Process.start(
      spec.executable.isNotEmpty ? spec.executable : executable,
      spec.arguments,
      environment: <String, String>{
        ...Platform.environment,
        ...spec.environment,
      },
      mode: ProcessStartMode.normal,
      runInShell: false,
    );
    return SystemSshProcess(process);
  }
}

class SystemSshProcess implements SshProcess {
  SystemSshProcess(this._process)
    : _stdoutLines = _process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter()),
      _stderrLines = _process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter());

  final Process _process;
  final Stream<String> _stdoutLines;
  final Stream<String> _stderrLines;

  @override
  Stream<String> get stdoutLines => _stdoutLines;

  @override
  Stream<String> get stderrLines => _stderrLines;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  Future<void> writeLine(String line) async {
    _process.stdin.writeln(line);
    await _process.stdin.flush();
  }

  @override
  Future<void> closeStdin() => _process.stdin.close();

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) =>
      _process.kill(signal);
}
