import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:penguin_pos_qa_agent/runtime/app_target_handle.dart';

/// Handles launching the PenguinPOS Flutter application process and capturing the VM Service URI.
class PenguinPosAppLauncher {
  Future<LaunchedPenguinPos> launch({
    required String appRoot,
    String flutterExecutable = 'flutter',
    String? device,
    String? entity,
    String? env,
    void Function(String message)? onProgress,
  }) async {
    final targetDevice =
        device ??
        Platform.environment['PENGUIN_POS_DEVICE'] ??
        (Platform.isMacOS
            ? 'macos'
            : Platform.isWindows
            ? 'windows'
            : 'linux');
    final targetEntity =
        entity ?? Platform.environment['PENGUIN_POS_ENTITY'] ?? 'ibo';
    final targetEnv = env ?? Platform.environment['PENGUIN_POS_ENV'] ?? 'stage';

    onProgress?.call('Starting Flutter run on $targetDevice...');

    final process = await Process.start(
      flutterExecutable.isNotEmpty ? flutterExecutable : 'flutter',
      <String>[
        'run',
        '-d',
        targetDevice,
        '--dart-define=ENABLE_FLUTTER_DRIVER=true',
        '--dart-define=ENTITY=$targetEntity',
        '--dart-define=ENV=$targetEnv',
      ],
      workingDirectory: appRoot,
      mode: ProcessStartMode.normal,
    );
    final serviceUri = await _waitForVmServiceUri(
      process,
      onProgress: onProgress,
    );
    return LaunchedPenguinPos(process: process, vmServiceUri: serviceUri);
  }

  Future<Uri> _waitForVmServiceUri(
    Process process, {
    void Function(String message)? onProgress,
  }) async {
    final lines = StreamGroup.merge(<Stream<String>>[
      process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
      process.stderr.transform(utf8.decoder).transform(const LineSplitter()),
    ]);
    final expression = RegExp(r'https?://[^\s]+');
    final serviceUri = Completer<Uri>();
    final buildLogs = <String>[];
    late final StreamSubscription<String> outputSubscription;

    outputSubscription = lines.listen(
      (line) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          if (buildLogs.length >= 20) {
            buildLogs.removeAt(0);
          }
          buildLogs.add(trimmed);
        }

        // Stream build/launch progress events
        if (trimmed.startsWith('Building ') ||
            trimmed.startsWith('Running pod ') ||
            trimmed.startsWith('Launching ') ||
            trimmed.startsWith('Waiting for ') ||
            trimmed.contains('Xcode build') ||
            trimmed.contains('CocoaPods')) {
          onProgress?.call(trimmed);
        }

        // Keep application logs private by forwarding only explicit QA traces.
        if (line.startsWith('[PenguinPOS]') || line.startsWith('[IdleLock]')) {
          stderr.writeln('[PenguinPOS app] $line');
        }

        if (serviceUri.isCompleted) return;
        final match = expression.firstMatch(line);
        if (match == null) return;
        if (line.toLowerCase().contains('vm service') ||
            line.contains('is available at:')) {
          serviceUri.complete(Uri.parse(match.group(0)!));
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!serviceUri.isCompleted) {
          serviceUri.completeError(error, stackTrace);
        }
      },
      onDone: () {
        if (!serviceUri.isCompleted) {
          final errorSnippet = buildLogs.isNotEmpty
              ? '\nLast output:\n${buildLogs.join('\n')}'
              : '';
          serviceUri.completeError(
            StateError(
              'PenguinPOS exited before publishing a Dart VM service URI.$errorSnippet',
            ),
          );
        }
      },
    );

    try {
      return await serviceUri.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          outputSubscription.cancel();
          throw TimeoutException(
            'Timed out waiting for PenguinPOS to publish a Dart VM service URI.',
          );
        },
      );
    } catch (_) {
      await outputSubscription.cancel();
      rethrow;
    }
  }
}

/// Represents a running instance of PenguinPOS launched for QA automation.
class LaunchedPenguinPos implements AppTargetHandle {
  LaunchedPenguinPos({required this.process, required this.vmServiceUri}) {
    unawaited(_watchProcessExit());
  }

  final Process process;
  @override
  final Uri vmServiceUri;
  final StreamController<AppTargetLifecycleEvent> _lifecycleController =
      StreamController<AppTargetLifecycleEvent>.broadcast();
  bool _closed = false;

  @override
  Stream<AppTargetLifecycleEvent> get lifecycleEvents =>
      _lifecycleController.stream;

  @override
  Stream<AppTargetLifecycleEvent> get healthEvents => lifecycleEvents;

  @override
  bool get isClosed => _closed;

  @override
  Map<String, Object?> get metadata => const <String, Object?>{'mode': 'local'};

  Future<void> _watchProcessExit() async {
    try {
      final exitCode = await process.exitCode;
      if (!_closed) {
        _lifecycleController.add(
          AppTargetLifecycleEvent(
            exitCode == 0
                ? AppTargetLifecycleState.exited
                : AppTargetLifecycleState.failed,
            exitCode: exitCode,
            message: 'PenguinPOS exited.',
          ),
        );
      }
    } finally {
      if (!_lifecycleController.isClosed) {
        await _lifecycleController.close();
      }
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (!_lifecycleController.isClosed) {
      _lifecycleController.add(
        const AppTargetLifecycleEvent(AppTargetLifecycleState.stopping),
      );
    }
    try {
      try {
        process.stdin.writeln('q');
      } catch (_) {}
      process.kill(ProcessSignal.sigint);
      await process.exitCode.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          try {
            process.kill(ProcessSignal.sigkill);
          } catch (_) {}
          if (Platform.isMacOS || Platform.isLinux) {
            try {
              Process.runSync('killall', ['-9', 'penguin_pos']);
            } catch (_) {}
          }
          return -1;
        },
      );
    } catch (_) {}
    if (Platform.isMacOS || Platform.isLinux) {
      try {
        Process.runSync('killall', ['-9', 'penguin_pos']);
      } catch (_) {}
    }
    if (!_lifecycleController.isClosed) {
      _lifecycleController.add(
        const AppTargetLifecycleEvent(AppTargetLifecycleState.stopped),
      );
      await _lifecycleController.close();
    }
  }
}

/// Merges multiple streams without external package dependencies.
abstract final class StreamGroup {
  static Stream<T> merge<T>(Iterable<Stream<T>> streams) {
    final controller = StreamController<T>();
    var remaining = 0;
    for (final stream in streams) {
      remaining++;
      stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: () {
          remaining--;
          if (remaining == 0) controller.close();
        },
      );
    }
    return controller.stream;
  }
}
