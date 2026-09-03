import 'dart:async';
import 'dart:io';

import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_askpass.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_connection_config.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_process.dart';

typedef LocalPortAllocator = Future<int> Function();

typedef ForwardReachabilityProbe =
    Future<bool> Function(String host, int port, Duration timeout);

typedef SshPortForwardStarter =
    Future<SshPortForward> Function({
      required SshConnectionConfig config,
      required String remoteHost,
      required int remotePort,
      required int localPort,
      required SshAskpassSession? askpassSession,
    });

/// A system SSH local forward from a loopback port on the QA Agent to the
/// remote Linux VM Service port.
class SshPortForward {
  SshPortForward({
    required this.process,
    required this.localPort,
    required this.remoteHost,
    required this.remotePort,
    required this.config,
  }) {
    _stderrSubscription = process.stderrLines.listen(_recordDiagnostic);
  }

  final SshProcess process;
  final int localPort;
  final String remoteHost;
  final int remotePort;
  final SshConnectionConfig config;
  final List<String> _recentDiagnostics = <String>[];
  StreamSubscription<String>? _stderrSubscription;
  bool _closed = false;

  bool get isClosed => _closed;

  Future<int> get exitCode => process.exitCode;

  String get diagnosticSummary => _recentDiagnostics.join(' | ');

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
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
    await _stderrSubscription?.cancel();
  }

  static Future<SshPortForward> open({
    required SshConnectionConfig config,
    String remoteHost = '127.0.0.1',
    required int remotePort,
    required SshProcessStarter processStarter,
    required SshAskpassSession? askpassSession,
    int? localPort,
    LocalPortAllocator allocateLocalPort = allocateEphemeralLocalPort,
    ForwardReachabilityProbe probe = _probe,
  }) async {
    final resolvedLocalPort = localPort ?? await allocateLocalPort();
    final forwardingHost = _formatForwardHost(remoteHost);
    final process = await processStarter(
      SshProcessSpec(
        executable: 'ssh',
        arguments: <String>[
          '-N',
          '-T',
          '-o',
          'BatchMode=no',
          '-o',
          'ExitOnForwardFailure=yes',
          '-o',
          'ConnectTimeout=${config.connectTimeout.inSeconds}',
          '-o',
          'ServerAliveInterval=5',
          '-o',
          'ServerAliveCountMax=2',
          '-p',
          '${config.port}',
          '-L',
          '127.0.0.1:$resolvedLocalPort:$forwardingHost:$remotePort',
          if (config.identityFile != null) ...<String>[
            '-i',
            config.identityFile!,
          ],
          config.destination,
        ],
        environment: askpassSession?.environment ?? const <String, String>{},
      ),
    );
    final forward = SshPortForward(
      process: process,
      localPort: resolvedLocalPort,
      remoteHost: remoteHost,
      remotePort: remotePort,
      config: config,
    );
    try {
      await _waitUntilReachable(
        host: '127.0.0.1',
        port: resolvedLocalPort,
        timeout: config.connectTimeout,
        probe: probe,
        exitCode: process.exitCode,
      );
      return forward;
    } catch (_) {
      await forward.close();
      rethrow;
    }
  }

  void _recordDiagnostic(String line) {
    final message = line.trim();
    if (message.isEmpty) return;
    _recentDiagnostics.add(message);
    if (_recentDiagnostics.length > 8) _recentDiagnostics.removeAt(0);
  }

  static Future<void> _waitUntilReachable({
    required String host,
    required int port,
    required Duration timeout,
    required ForwardReachabilityProbe probe,
    required Future<int> exitCode,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await probe(host, port, const Duration(milliseconds: 250))) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // A completed process cannot recover, so fail promptly instead of
      // waiting for the complete connection timeout.
      final completed = await Future.any<bool>(<Future<bool>>[
        exitCode.then<bool>((_) => true),
        Future<bool>.delayed(const Duration(milliseconds: 1), () => false),
      ]);
      if (completed) {
        throw StateError('SSH local port forwarding process exited.');
      }
    }
    throw TimeoutException('Timed out waiting for SSH local port forwarding.');
  }

  static Future<bool> _probe(String host, int port, Duration timeout) async {
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      return true;
    } on SocketException {
      return false;
    } finally {
      await socket?.close();
    }
  }
}

String _formatForwardHost(String host) => host.contains(':') ? '[$host]' : host;

Future<int> allocateEphemeralLocalPort() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  await server.close();
  return port;
}
