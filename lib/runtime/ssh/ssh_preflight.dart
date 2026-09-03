import 'dart:async';
import 'dart:io';

import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_askpass.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_connection_config.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_process.dart';

class SshPreflight {
  SshPreflight({
    SshProcessStarter? processStarter,
    SshAskpassFactory? askpassFactory,
  }) : processStarter = processStarter ?? const SystemSshProcessStarter().call,
       askpassFactory = askpassFactory ?? const SystemSshAskpassFactory();

  final SshProcessStarter processStarter;
  final SshAskpassFactory askpassFactory;

  Future<void> verify(SshConnectionConfig config) async {
    config.validate();
    final askpass = await askpassFactory.create(config.password);
    SshProcess? process;
    final output = <String>[];
    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();
    StreamSubscription<String>? stdoutSubscription;
    StreamSubscription<String>? stderrSubscription;
    try {
      process = await processStarter(
        SshProcessSpec(
          executable: 'ssh',
          arguments: buildSshPreflightArguments(config),
          environment: askpass?.environment ?? const <String, String>{},
        ),
      );
      stdoutSubscription = process.stdoutLines.listen(
        output.add,
        onDone: stdoutDone.complete,
      );
      stderrSubscription = process.stderrLines.listen(
        output.add,
        onDone: stderrDone.complete,
      );
      final exitCode = await process.exitCode.timeout(
        config.connectTimeout,
        onTimeout: () {
          process!.kill(ProcessSignal.sigterm);
          return -1;
        },
      );
      await Future.wait(<Future<void>>[
        stdoutDone.future,
        stderrDone.future,
      ]).timeout(const Duration(seconds: 1), onTimeout: () => <void>[]);
      await stdoutSubscription.cancel();
      await stderrSubscription.cancel();
      stdoutSubscription = null;
      stderrSubscription = null;

      if (exitCode != 0 || !output.contains('QA_PREFLIGHT_OK')) {
        final detail = output
            .where((line) => line.trim().isNotEmpty)
            .take(6)
            .join(' | ');
        throw StateError(
          detail.isEmpty
              ? 'SSH preflight failed with exit code $exitCode.'
              : 'SSH preflight failed: $detail',
        );
      }
    } finally {
      await stdoutSubscription?.cancel();
      await stderrSubscription?.cancel();
      if (process != null) {
        try {
          await process.closeStdin();
        } catch (_) {}
      }
      await askpass?.dispose();
    }
  }
}

List<String> buildSshPreflightArguments(SshConnectionConfig config) {
  final flutterCheck = config.remoteFlutterExecutable.contains('/')
      ? 'test -x ${_shellQuote(config.remoteFlutterExecutable)}'
      : 'command -v ${_shellQuote(config.remoteFlutterExecutable)} >/dev/null 2>&1';
  final appRootError = _shellQuote(
    'Remote app root does not exist: ${config.remoteAppRoot}',
  );
  final flutterError = _shellQuote(
    'Remote Flutter executable is missing or not executable: '
    '${config.remoteFlutterExecutable}',
  );
  final script =
      '''
set -eu
test -d ${_shellQuote(config.remoteAppRoot)} || { echo $appRootError >&2; exit 21; }
$flutterCheck || { echo $flutterError >&2; exit 22; }
remote_uid=\$(id -u)
runtime_dir="\${XDG_RUNTIME_DIR:-/run/user/\$remote_uid}"
if [ ! -S /tmp/.X11-unix/X0 ] && [ ! -S "\$runtime_dir/wayland-0" ]; then
  echo "No active Linux graphical session was found for the SSH user. Log in to the Linux desktop first." >&2
  exit 23
fi
echo QA_PREFLIGHT_OK
'''
          .trim();

  return <String>[
    '-T',
    '-o',
    'BatchMode=no',
    '-o',
    'ConnectTimeout=${config.connectTimeout.inSeconds}',
    '-p',
    '${config.port}',
    if (config.identityFile != null) ...<String>['-i', config.identityFile!],
    config.destination,
    'sh -lc ${_shellQuote(script)}',
  ];
}

String _shellQuote(String value) => "'${value.replaceAll("'", "'\"'\"'")}'";
