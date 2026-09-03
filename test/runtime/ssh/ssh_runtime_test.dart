import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/runtime/app_target_handle.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/flutter_machine_protocol.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_askpass.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_connection_config.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_port_forward.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_preflight.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_process.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_remote_app_launcher.dart';

void main() {
  group('Flutter machine protocol', () {
    test('parses app lifecycle and VM Service events', () {
      final events = parseFlutterMachineLine(
        jsonEncode(<Object?>[
          <String, Object?>{
            'event': 'app.start',
            'params': <String, Object?>{'appId': 'app-1'},
          },
          <String, Object?>{
            'event': 'app.debugPort',
            'params': <String, Object?>{
              'appId': 'app-1',
              'port': 39123,
              'wsUri': 'ws://127.0.0.1:39123/token/ws',
            },
          },
          <String, Object?>{
            'event': 'app.started',
            'params': <String, Object?>{'appId': 'app-1'},
          },
        ]),
      );

      expect(events, hasLength(3));
      expect(events[0], isA<FlutterMachineAppStartEvent>());
      final debugPort = events[1] as FlutterMachineDebugPortEvent;
      expect(debugPort.appId, 'app-1');
      expect(debugPort.port, 39123);
      expect(debugPort.wsUri.toString(), 'ws://127.0.0.1:39123/token/ws');
      expect(events[2], isA<FlutterMachineAppStartedEvent>());
    });

    test('encodes app.stop as a daemon command', () {
      final decoded =
          jsonDecode(encodeFlutterStopCommand(requestId: 7, appId: 'app-1'))
              as List<Object?>;
      final command = Map<String, Object?>.from(decoded.single! as Map);
      expect(command['id'], 7);
      expect(command['method'], 'app.stop');
      expect(
        Map<String, Object?>.from(command['params']! as Map)['appId'],
        'app-1',
      );
    });
  });

  test(
    'askpass keeps password out of the script and command arguments',
    () async {
      const password = 'test-password';
      final factory = SystemSshAskpassFactory(setExecutable: (_) async {});
      final session = await factory.create(password);
      expect(session, isNotNull);
      final systemSession = session! as SystemSshAskpassSession;
      final script = systemSession.directory.uri
          .resolve('askpass.sh')
          .toFilePath();
      final contents = await File(script).readAsString();
      expect(contents, isNot(contains(password)));
      expect(systemSession.environment['QA_AGENT_SSH_PASSWORD'], password);
      expect(systemSession.environment['SSH_ASKPASS'], script);
      await systemSession.dispose();
      expect(systemSession.isDisposed, isTrue);
    },
  );

  test('preflight verifies paths and a Linux graphical session', () async {
    final process = FakeSshProcess();
    SshProcessSpec? captured;
    final preflight = SshPreflight(
      processStarter: (spec) async {
        captured = spec;
        scheduleMicrotask(() {
          process.emitLine('QA_PREFLIGHT_OK');
          process.completeExit(0);
        });
        return process;
      },
      askpassFactory: FakeAskpassFactory(FakeAskpassSession()),
    );

    await preflight.verify(_config());

    final command = captured!.arguments.last;
    expect(command, contains('/opt/penguin_pos'));
    expect(command, contains('/opt/flutter/bin/flutter'));
    expect(command, contains('/tmp/.X11-unix/X0'));
    expect(command, contains('wayland-0'));
    expect(command, isNot(contains('penguin_pos_qa_helper')));
  });

  test(
    'port forwarding uses a separate SSH process and dynamic local port',
    () async {
      final process = FakeSshProcess();
      SshProcessSpec? captured;
      final forward = await SshPortForward.open(
        config: _config(),
        remotePort: 45678,
        localPort: 41234,
        processStarter: (spec) async {
          captured = spec;
          return process;
        },
        askpassSession: null,
        probe: (_, _, _) async => true,
      );

      expect(forward.localPort, 41234);
      expect(captured!.arguments, contains('-N'));
      expect(captured!.arguments, contains('127.0.0.1:41234:127.0.0.1:45678'));
      await forward.close();
      expect(process.wasKilled, isTrue);
    },
  );

  test(
    'launcher uses flutter --machine directly and creates the VM tunnel',
    () async {
      final runProcess = FakeSshProcess();
      final forwardingProcess = FakeSshProcess();
      final askpass = FakeAskpassSession();
      SshProcessSpec? runSpec;
      final launcher = SshRemoteAppLauncher(
        processStarter: (spec) async {
          runSpec = spec;
          scheduleMicrotask(() {
            runProcess.emitMachineEvent('app.start', <String, Object?>{
              'appId': 'app-1',
            });
            runProcess.emitMachineEvent('app.debugPort', <String, Object?>{
              'appId': 'app-1',
              'port': 40000,
              'wsUri': 'ws://127.0.0.1:45678/token/ws',
            });
            runProcess.emitMachineEvent('app.started', <String, Object?>{
              'appId': 'app-1',
            });
          });
          return runProcess;
        },
        askpassFactory: FakeAskpassFactory(askpass),
        localPortAllocator: () async => 40123,
        tunnelProbe: (_, _) async {},
        portForwardStarter:
            ({
              required config,
              required remoteHost,
              required remotePort,
              required localPort,
              required askpassSession,
            }) async {
              expect(remotePort, 45678);
              expect(remoteHost, '127.0.0.1');
              expect(localPort, 40123);
              expect(identical(askpassSession, askpass), isTrue);
              return SshPortForward(
                process: forwardingProcess,
                localPort: localPort,
                remoteHost: remoteHost,
                remotePort: remotePort,
                config: config,
              );
            },
      );
      runProcess.onWrite = (line) {
        final command = Map<String, Object?>.from(
          (jsonDecode(line) as List).single as Map,
        );
        if (command['method'] == 'app.stop') runProcess.completeExit(0);
      };

      final handle = await launcher.launch(
        config: _config(password: 'test-password'),
        entity: 'ibo',
        environment: 'stage',
      );

      expect(handle.vmServiceUri.toString(), 'ws://127.0.0.1:40123/token/ws');
      expect(handle.metadata['transport'], 'flutter-machine');
      expect(handle.metadata['remoteAppId'], 'app-1');
      final command = runSpec!.arguments.last;
      expect(command, contains('run -d linux --machine'));
      expect(command, contains('ENABLE_FLUTTER_DRIVER=true'));
      expect(command, contains('XDG_RUNTIME_DIR'));
      expect(command, contains('DBUS_SESSION_BUS_ADDRESS'));
      expect(command, isNot(contains('penguin_pos_qa_helper')));
      expect(command, isNot(contains('test-password')));

      await handle.close();
      expect(
        runProcess.writtenLines.any((line) => line.contains('"app.stop"')),
        isTrue,
      );
      expect(askpass.isDisposed, isTrue);
    },
  );

  test(
    'launcher reports remote output when Flutter exits during startup',
    () async {
      final runProcess = FakeSshProcess();
      final launcher = SshRemoteAppLauncher(
        processStarter: (_) async {
          scheduleMicrotask(() {
            runProcess.emitErrorLine('Unable to open display :0');
            runProcess.completeExit(1);
          });
          return runProcess;
        },
        askpassFactory: FakeAskpassFactory(FakeAskpassSession()),
      );

      await expectLater(
        launcher.launch(config: _config(), entity: 'kpn', environment: 'dev'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Unable to open display :0'),
          ),
        ),
      );
    },
  );

  test(
    'launcher rejects a local forward that cannot reach the VM Service',
    () async {
      final runProcess = FakeSshProcess();
      final forwardingProcess = FakeSshProcess();
      runProcess.onWrite = (_) => runProcess.completeExit(0);
      final launcher = SshRemoteAppLauncher(
        processStarter: (_) async {
          scheduleMicrotask(() {
            runProcess.emitMachineEvent('app.debugPort', <String, Object?>{
              'appId': 'app-tunnel-failure',
              'port': 45680,
              'wsUri': 'ws://127.0.0.1:45680/auth/ws',
            });
            runProcess.emitMachineEvent('app.started', <String, Object?>{
              'appId': 'app-tunnel-failure',
            });
          });
          return runProcess;
        },
        askpassFactory: FakeAskpassFactory(FakeAskpassSession()),
        localPortAllocator: () async => 40125,
        portForwardStarter:
            ({
              required config,
              required remoteHost,
              required remotePort,
              required localPort,
              required askpassSession,
            }) async => SshPortForward(
              process: forwardingProcess,
              localPort: localPort,
              remoteHost: remoteHost,
              remotePort: remotePort,
              config: config,
            ),
        tunnelProbe: (_, _) async {
          forwardingProcess.emitErrorLine(
            'channel 2: open failed: connect failed: Connection refused',
          );
          throw const SocketException('WebSocket connection failed');
        },
      );

      await expectLater(
        launcher.launch(config: _config(), entity: 'kpn', environment: 'dev'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('VM Service could not be reached'),
              contains('Connection refused'),
            ),
          ),
        ),
      );
    },
  );

  test('unexpected remote process exit updates target lifecycle', () async {
    final runProcess = FakeSshProcess();
    final forwardingProcess = FakeSshProcess();
    final launcher = SshRemoteAppLauncher(
      processStarter: (_) async {
        scheduleMicrotask(() {
          runProcess.emitMachineEvent('app.debugPort', <String, Object?>{
            'appId': 'app-2',
            'port': 45679,
          });
          runProcess.emitMachineEvent('app.started', <String, Object?>{
            'appId': 'app-2',
          });
        });
        return runProcess;
      },
      askpassFactory: FakeAskpassFactory(FakeAskpassSession()),
      localPortAllocator: () async => 40124,
      tunnelProbe: (_, _) async {},
      portForwardStarter:
          ({
            required config,
            required remoteHost,
            required remotePort,
            required localPort,
            required askpassSession,
          }) async => SshPortForward(
            process: forwardingProcess,
            localPort: localPort,
            remoteHost: remoteHost,
            remotePort: remotePort,
            config: config,
          ),
    );
    final handle = await launcher.launch(
      config: _config(),
      entity: 'kpn',
      environment: 'dev',
    );
    final lifecycle = handle.lifecycleEvents.firstWhere(
      (event) => event.state == AppTargetLifecycleState.failed,
    );

    runProcess.completeExit(17);

    final event = await lifecycle;
    expect(event.exitCode, 17);
    await Future<void>.delayed(Duration.zero);
    expect(handle.isClosed, isTrue);
  });

  test(
    'remote app window close updates lifecycle and releases resources',
    () async {
      final runProcess = FakeSshProcess();
      final forwardingProcess = FakeSshProcess();
      final launcher = SshRemoteAppLauncher(
        processStarter: (_) async {
          scheduleMicrotask(() {
            runProcess.emitMachineEvent('app.debugPort', <String, Object?>{
              'appId': 'app-manual-close',
              'port': 45681,
            });
            runProcess.emitMachineEvent('app.started', <String, Object?>{
              'appId': 'app-manual-close',
            });
          });
          return runProcess;
        },
        askpassFactory: FakeAskpassFactory(FakeAskpassSession()),
        localPortAllocator: () async => 40126,
        tunnelProbe: (_, _) async {},
        portForwardStarter:
            ({
              required config,
              required remoteHost,
              required remotePort,
              required localPort,
              required askpassSession,
            }) async => SshPortForward(
              process: forwardingProcess,
              localPort: localPort,
              remoteHost: remoteHost,
              remotePort: remotePort,
              config: config,
            ),
      );
      final handle = await launcher.launch(
        config: _config(),
        entity: 'kpn',
        environment: 'dev',
      );
      final lifecycle = handle.lifecycleEvents.firstWhere(
        (event) => event.state == AppTargetLifecycleState.stopped,
      );

      runProcess.emitMachineEvent('app.stop', <String, Object?>{
        'appId': 'app-manual-close',
      });

      final event = await lifecycle;
      expect(event.message, 'Remote PenguinPOS was closed.');
      await Future<void>.delayed(Duration.zero);
      expect(handle.isClosed, isTrue);
      expect(forwardingProcess.wasKilled, isTrue);
    },
  );
}

SshConnectionConfig _config({String? password}) => SshConnectionConfig(
  host: 'linux.example.test',
  username: 'qa',
  remoteAppRoot: '/opt/penguin_pos',
  remoteFlutterExecutable: '/opt/flutter/bin/flutter',
  password: password,
);

class FakeSshProcess implements SshProcess {
  final StreamController<String> _stdout = StreamController<String>();
  final StreamController<String> _stderr = StreamController<String>();
  final Completer<int> _exitCode = Completer<int>();
  final List<String> writtenLines = <String>[];
  void Function(String line)? onWrite;
  bool wasKilled = false;

  @override
  Stream<String> get stdoutLines => _stdout.stream;

  @override
  Stream<String> get stderrLines => _stderr.stream;

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  Future<void> writeLine(String line) async {
    writtenLines.add(line);
    onWrite?.call(line);
  }

  @override
  Future<void> closeStdin() async {}

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    wasKilled = true;
    completeExit(0);
    return true;
  }

  void emitLine(String line) => _stdout.add(line);

  void emitErrorLine(String line) => _stderr.add(line);

  void emitMachineEvent(String event, Map<String, Object?> params) => emitLine(
    jsonEncode(<Object?>[
      <String, Object?>{'event': event, 'params': params},
    ]),
  );

  void completeExit(int exitCode) {
    if (_exitCode.isCompleted) return;
    _stdout.close();
    _stderr.close();
    _exitCode.complete(exitCode);
  }
}

class FakeAskpassFactory implements SshAskpassFactory {
  FakeAskpassFactory(this.session);

  final FakeAskpassSession session;

  @override
  Future<SshAskpassSession?> create(String? password) async => session;
}

class FakeAskpassSession implements SshAskpassSession {
  @override
  final Map<String, String> environment = const <String, String>{};
  bool disposed = false;

  @override
  bool get isDisposed => disposed;

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
