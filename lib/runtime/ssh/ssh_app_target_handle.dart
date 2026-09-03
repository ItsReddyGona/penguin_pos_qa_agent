import 'dart:async';

import 'package:penguin_pos_qa_agent/runtime/app_target_handle.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/flutter_machine_protocol.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_askpass.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_connection_config.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_flutter_run_session.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_port_forward.dart';

/// Owns the remote Flutter machine session and VM Service tunnel.
class SshAppTargetHandle implements AppTargetHandle {
  SshAppTargetHandle({
    required this.config,
    required this.flutterSession,
    required this.portForward,
    required this.askpassSession,
    required this.remoteAppId,
    required this.vmServiceUri,
  }) {
    _sessionSubscription = flutterSession.events.listen(_onMachineEvent);
    unawaited(_watchPortForward());
    _emit(const AppTargetLifecycleEvent(AppTargetLifecycleState.ready));
  }

  final SshConnectionConfig config;
  final SshFlutterRunSession flutterSession;
  final SshPortForward portForward;
  final SshAskpassSession? askpassSession;
  final String remoteAppId;

  @override
  final Uri vmServiceUri;

  final StreamController<AppTargetLifecycleEvent> _lifecycleController =
      StreamController<AppTargetLifecycleEvent>.broadcast();
  StreamSubscription<FlutterMachineEvent>? _sessionSubscription;
  bool _closed = false;
  bool _unexpectedCleanupStarted = false;

  @override
  Stream<AppTargetLifecycleEvent> get lifecycleEvents =>
      _lifecycleController.stream;

  @override
  Stream<AppTargetLifecycleEvent> get healthEvents => lifecycleEvents;

  @override
  bool get isClosed => _closed;

  @override
  Map<String, Object?> get metadata => <String, Object?>{
    ...config.toMetadata(),
    'mode': 'ssh',
    'transport': 'flutter-machine',
    'remoteAppId': remoteAppId,
    'localForwardPort': portForward.localPort,
    'remoteVmServicePort': portForward.remotePort,
  };

  void _onMachineEvent(FlutterMachineEvent event) {
    if (_closed) return;
    switch (event) {
      case FlutterMachineAppStartedEvent():
        _emit(const AppTargetLifecycleEvent(AppTargetLifecycleState.ready));
        break;
      case FlutterMachineAppStopEvent():
        _emit(
          const AppTargetLifecycleEvent(
            AppTargetLifecycleState.stopped,
            message: 'Remote PenguinPOS was closed.',
          ),
        );
        unawaited(_cleanupAfterUnexpectedEvent());
        break;
      case FlutterMachineProcessExitEvent(:final exitCode):
        _emit(
          AppTargetLifecycleEvent(
            exitCode == 0
                ? AppTargetLifecycleState.exited
                : AppTargetLifecycleState.failed,
            exitCode: exitCode,
            message: exitCode == 0
                ? 'Remote PenguinPOS exited.'
                : 'Remote PenguinPOS or its SSH session exited unexpectedly.',
          ),
        );
        unawaited(_cleanupAfterUnexpectedEvent());
        break;
      case FlutterMachineDaemonErrorEvent(:final message):
        _emit(
          AppTargetLifecycleEvent(
            AppTargetLifecycleState.failed,
            message: message,
          ),
        );
        break;
      case FlutterMachineAppStartEvent():
      case FlutterMachineDebugPortEvent():
      case FlutterMachineAppLogEvent():
        break;
    }
  }

  void _emit(AppTargetLifecycleEvent event) {
    if (!_lifecycleController.isClosed) _lifecycleController.add(event);
  }

  Future<void> _watchPortForward() async {
    int? exitCode;
    try {
      exitCode = await portForward.exitCode;
    } catch (_) {
      // A failed exit-code future still means the tunnel is gone. Lifecycle
      // reporting and cleanup below remain best effort.
    }
    if (_closed) return;
    final detail = portForward.diagnosticSummary;
    _emit(
      AppTargetLifecycleEvent(
        AppTargetLifecycleState.disconnected,
        exitCode: exitCode,
        message:
            'SSH VM Service tunnel closed unexpectedly.'
            '${detail.isEmpty ? '' : ' $detail'}',
      ),
    );
    await _cleanupAfterUnexpectedEvent();
  }

  Future<void> _cleanupAfterUnexpectedEvent() async {
    if (_unexpectedCleanupStarted) return;
    _unexpectedCleanupStarted = true;
    _closed = true;
    try {
      await _closeResources();
    } catch (_) {}
    try {
      await _sessionSubscription?.cancel();
    } catch (_) {}
    if (!_lifecycleController.isClosed) {
      try {
        await _lifecycleController.close();
      } catch (_) {}
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _emit(const AppTargetLifecycleEvent(AppTargetLifecycleState.stopping));
    await _closeResources();
    await _sessionSubscription?.cancel();
    _emit(const AppTargetLifecycleEvent(AppTargetLifecycleState.stopped));
    await _lifecycleController.close();
  }

  Future<void> _closeResources() async {
    try {
      await portForward.close();
    } catch (_) {}
    try {
      await flutterSession.stop();
    } catch (_) {}
    try {
      await askpassSession?.dispose();
    } catch (_) {}
  }
}
