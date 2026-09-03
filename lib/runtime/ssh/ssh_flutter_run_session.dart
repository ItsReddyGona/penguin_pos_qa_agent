import 'dart:async';
import 'dart:io';

import 'package:penguin_pos_qa_agent/runtime/ssh/flutter_machine_protocol.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_askpass.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_connection_config.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_process.dart';

class SshFlutterRunSession {
  SshFlutterRunSession({
    required this.config,
    required this.processStarter,
    required this.entity,
    required this.environment,
    this.askpassSession,
  });

  final SshConnectionConfig config;
  final SshProcessStarter processStarter;
  final String entity;
  final String environment;
  final SshAskpassSession? askpassSession;

  final StreamController<FlutterMachineEvent> _events =
      StreamController<FlutterMachineEvent>.broadcast();
  final StreamController<String> _diagnostics =
      StreamController<String>.broadcast();
  final List<FlutterMachineEvent> _eventHistory = <FlutterMachineEvent>[];
  final List<String> _recentDiagnostics = <String>[];
  SshProcess? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  bool _closed = false;
  int? _exitCode;
  int _requestId = 1;
  String? _appId;

  Stream<FlutterMachineEvent> get events => _events.stream;

  Stream<String> get diagnostics => _diagnostics.stream;

  bool get isRunning => _process != null && _exitCode == null && !_closed;

  Future<void> start() async {
    if (_process != null) {
      throw StateError('Remote Flutter session is already open.');
    }
    config.validate();
    final process = await processStarter(
      SshProcessSpec(
        executable: 'ssh',
        arguments: buildSshFlutterRunArguments(
          config: config,
          entity: entity,
          environment: environment,
        ),
        environment: askpassSession?.environment ?? const <String, String>{},
      ),
    );
    _process = process;
    _stdoutSubscription = process.stdoutLines.listen(_onStdoutLine);
    _stderrSubscription = process.stderrLines.listen(_addDiagnostic);
    unawaited(_watchExit(process));
  }

  Future<T> waitFor<T extends FlutterMachineEvent>(
    bool Function(FlutterMachineEvent event) predicate, {
    required Duration timeout,
    required String description,
  }) async {
    final completer = Completer<T>();

    void accept(FlutterMachineEvent event) {
      if (completer.isCompleted) return;
      if (event is FlutterMachineProcessExitEvent) {
        completer.completeError(_earlyExitError(description));
        return;
      }
      if (predicate(event)) {
        _eventHistory.remove(event);
        completer.complete(event as T);
      }
    }

    final subscription = events.listen(
      accept,
      onError: completer.completeError,
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError('Remote Flutter event stream closed unexpectedly.'),
          );
        }
      },
    );
    for (final event in List<FlutterMachineEvent>.of(_eventHistory)) {
      accept(event);
      if (completer.isCompleted) break;
    }
    if (!completer.isCompleted && _exitCode != null) {
      completer.completeError(_earlyExitError(description));
    }

    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
          'Timed out waiting for $description.${_diagnosticSuffix()}',
          timeout,
        ),
      );
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> stop() async {
    if (_closed) return;
    _closed = true;
    final process = _process;
    if (process != null && _exitCode == null) {
      final appId = _appId;
      if (appId != null) {
        try {
          await process.writeLine(
            encodeFlutterStopCommand(requestId: _requestId++, appId: appId),
          );
          await process.exitCode.timeout(config.stopTimeout);
        } catch (_) {
          await _terminate(process);
        }
      } else {
        await _terminate(process);
      }
    }
    await _closeStreams();
  }

  void _onStdoutLine(String line) {
    if (_closed || line.trim().isEmpty) return;
    try {
      final parsedEvents = parseFlutterMachineLine(line);
      for (final event in parsedEvents) {
        switch (event) {
          case FlutterMachineAppStartEvent(:final appId):
            _appId = appId;
            break;
          case FlutterMachineDebugPortEvent(:final appId):
            _appId = appId;
            break;
          case FlutterMachineAppLogEvent(:final message):
            _addDiagnostic(message);
            break;
          case FlutterMachineDaemonErrorEvent(:final message):
            _addDiagnostic(message);
            break;
          case FlutterMachineAppStartedEvent():
          case FlutterMachineAppStopEvent():
          case FlutterMachineProcessExitEvent():
            break;
        }
        _eventHistory.add(event);
        if (_eventHistory.length > 64) _eventHistory.removeAt(0);
        _events.add(event);
      }
    } on FormatException {
      // Flutter and the app can print ordinary text around machine events.
      _addDiagnostic(line);
    }
  }

  void _addDiagnostic(String message) {
    final normalized = message.trim();
    if (normalized.isEmpty || _closed) return;
    _recentDiagnostics.add(normalized);
    if (_recentDiagnostics.length > 12) _recentDiagnostics.removeAt(0);
    _diagnostics.add(normalized);
  }

  Future<void> _watchExit(SshProcess process) async {
    final exitCode = await process.exitCode;
    _exitCode = exitCode;
    if (!_closed) {
      _addDiagnostic('Remote Flutter process exited with code $exitCode.');
      final event = FlutterMachineProcessExitEvent(exitCode: exitCode);
      _eventHistory.add(event);
      _events.add(event);
    }
  }

  StateError _earlyExitError(String description) => StateError(
    'Remote Flutter exited before $description (exit code $_exitCode).'
    '${_diagnosticSuffix()}',
  );

  String _diagnosticSuffix() => _recentDiagnostics.isEmpty
      ? ''
      : ' Last output: ${_recentDiagnostics.join(' | ')}';

  Future<void> _terminate(SshProcess process) async {
    try {
      await process.closeStdin();
    } catch (_) {}
    try {
      process.kill(ProcessSignal.sigterm);
      await process.exitCode.timeout(
        config.stopTimeout,
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    } catch (_) {}
  }

  Future<void> _closeStreams() async {
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    if (!_events.isClosed) await _events.close();
    if (!_diagnostics.isClosed) await _diagnostics.close();
  }
}

List<String> buildSshFlutterRunArguments({
  required SshConnectionConfig config,
  required String entity,
  required String environment,
}) {
  return <String>[
    '-T',
    '-o',
    'BatchMode=no',
    '-o',
    'ConnectTimeout=${config.connectTimeout.inSeconds}',
    '-o',
    'ServerAliveInterval=5',
    '-o',
    'ServerAliveCountMax=2',
    '-p',
    '${config.port}',
    if (config.identityFile != null) ...<String>['-i', config.identityFile!],
    config.destination,
    'sh -lc ${_shellQuote(_remoteFlutterCommand(config: config, entity: entity, environment: environment))}',
  ];
}

String _remoteFlutterCommand({
  required SshConnectionConfig config,
  required String entity,
  required String environment,
}) {
  final appRoot = _shellQuote(config.remoteAppRoot);
  final flutter = _shellQuote(config.remoteFlutterExecutable);
  return '''
remote_uid=\$(id -u)
export XDG_RUNTIME_DIR="\${XDG_RUNTIME_DIR:-/run/user/\$remote_uid}"
if [ -z "\${DISPLAY:-}" ] && [ -S /tmp/.X11-unix/X0 ]; then export DISPLAY=:0; fi
if [ -z "\${WAYLAND_DISPLAY:-}" ] && [ -S "\$XDG_RUNTIME_DIR/wayland-0" ]; then export WAYLAND_DISPLAY=wayland-0; fi
if [ -z "\${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "\$XDG_RUNTIME_DIR/bus" ]; then export DBUS_SESSION_BUS_ADDRESS="unix:path=\$XDG_RUNTIME_DIR/bus"; fi
if [ -z "\${XAUTHORITY:-}" ] && [ -f "\$HOME/.Xauthority" ]; then export XAUTHORITY="\$HOME/.Xauthority"; fi
remote_build_commit=\$(git -C $appRoot rev-parse --short HEAD 2>/dev/null || printf unknown)
cd -- $appRoot && exec $flutter run -d linux --machine --dart-define=ENABLE_FLUTTER_DRIVER=true --dart-define=PENGUINPOS_BUILD_COMMIT=\$remote_build_commit --dart-define=ENTITY=${_shellQuote(entity)} --dart-define=ENV=${_shellQuote(environment)}
'''
      .trim();
}

String _shellQuote(String value) => "'${value.replaceAll("'", "'\"'\"'")}'";
