import 'dart:async';
import 'dart:io';

import 'package:penguin_pos_qa_agent/runtime/ssh/flutter_machine_protocol.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_app_target_handle.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_askpass.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_connection_config.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_flutter_run_session.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_port_forward.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_process.dart';

typedef VmServiceTunnelProbe = Future<void> Function(Uri uri, Duration timeout);

/// Starts PenguinPOS through Flutter's machine protocol over SSH.
class SshRemoteAppLauncher {
  SshRemoteAppLauncher({
    SshProcessStarter? processStarter,
    SshAskpassFactory? askpassFactory,
    LocalPortAllocator? localPortAllocator,
    this.portForwardStarter,
    VmServiceTunnelProbe? tunnelProbe,
  }) : processStarter = processStarter ?? const SystemSshProcessStarter().call,
       askpassFactory = askpassFactory ?? const SystemSshAskpassFactory(),
       localPortAllocator = localPortAllocator ?? allocateEphemeralLocalPort,
       tunnelProbe = tunnelProbe ?? _probeVmServiceTunnel;

  final SshProcessStarter processStarter;
  final SshAskpassFactory askpassFactory;
  final LocalPortAllocator localPortAllocator;
  final SshPortForwardStarter? portForwardStarter;
  final VmServiceTunnelProbe tunnelProbe;

  Future<SshAppTargetHandle> launch({
    required SshConnectionConfig config,
    required String entity,
    required String environment,
  }) async {
    config.validate();
    if (entity.trim().isEmpty) {
      throw ArgumentError.value(entity, 'entity', 'Entity must not be empty.');
    }
    if (environment.trim().isEmpty) {
      throw ArgumentError.value(
        environment,
        'environment',
        'Environment must not be empty.',
      );
    }

    final askpassSession = await askpassFactory.create(config.password);
    final flutterSession = SshFlutterRunSession(
      config: config,
      processStarter: processStarter,
      askpassSession: askpassSession,
      entity: entity,
      environment: environment,
    );
    SshPortForward? forward;
    try {
      await flutterSession.start();
      final debugPort = await flutterSession
          .waitFor<FlutterMachineDebugPortEvent>(
            (event) => event is FlutterMachineDebugPortEvent,
            timeout: config.startupTimeout,
            description: 'Flutter VM Service endpoint',
          );
      await flutterSession.waitFor<FlutterMachineAppStartedEvent>(
        (event) => event is FlutterMachineAppStartedEvent,
        timeout: config.startupTimeout,
        description: 'PenguinPOS to finish starting',
      );

      final localPort = await localPortAllocator();
      final remoteVmServiceUri = debugPort.wsUri;
      final remoteHost = _remoteForwardHost(remoteVmServiceUri?.host);
      final remotePort =
          remoteVmServiceUri != null && remoteVmServiceUri.hasPort
          ? remoteVmServiceUri.port
          : debugPort.port;
      final forwardedVmServiceUri = _forwardedVmServiceUri(
        remoteVmServiceUri: remoteVmServiceUri,
        localPort: localPort,
      );
      final starter = portForwardStarter;
      forward = starter == null
          ? await SshPortForward.open(
              config: config,
              remoteHost: remoteHost,
              remotePort: remotePort,
              localPort: localPort,
              processStarter: processStarter,
              askpassSession: askpassSession,
            )
          : await starter(
              config: config,
              remoteHost: remoteHost,
              remotePort: remotePort,
              localPort: localPort,
              askpassSession: askpassSession,
            );

      try {
        await tunnelProbe(forwardedVmServiceUri, config.connectTimeout);
      } on Object catch (error) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final sshDetail = forward.diagnosticSummary;
        throw StateError(
          'SSH tunnel opened, but the remote Flutter VM Service could not be '
          'reached at $forwardedVmServiceUri. ${error.toString()}'
          '${sshDetail.isEmpty ? '' : ' SSH: $sshDetail'}',
        );
      }

      return SshAppTargetHandle(
        config: config,
        flutterSession: flutterSession,
        portForward: forward,
        askpassSession: askpassSession,
        remoteAppId: debugPort.appId,
        vmServiceUri: forwardedVmServiceUri,
      );
    } catch (_) {
      await forward?.close();
      await flutterSession.stop();
      await askpassSession?.dispose();
      rethrow;
    }
  }
}

Uri _forwardedVmServiceUri({
  required Uri? remoteVmServiceUri,
  required int localPort,
}) {
  if (remoteVmServiceUri == null) {
    return Uri.parse('ws://127.0.0.1:$localPort/ws');
  }
  return remoteVmServiceUri.replace(host: '127.0.0.1', port: localPort);
}

String _remoteForwardHost(String? host) => switch (host) {
  null || '' || 'localhost' || '0.0.0.0' => '127.0.0.1',
  '::' => '::1',
  final host => host,
};

Future<void> _probeVmServiceTunnel(Uri uri, Duration timeout) async {
  WebSocket? socket;
  try {
    socket = await WebSocket.connect(uri.toString()).timeout(timeout);
  } finally {
    await socket?.close();
  }
}
