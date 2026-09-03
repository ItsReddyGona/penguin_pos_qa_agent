import 'dart:convert';
import 'dart:io';

import 'package:penguin_pos_qa_agent/automation/login/login_runner.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_scenario.dart';
import 'package:penguin_pos_qa_agent/runtime/app_launcher.dart';

/// Handler encapsulating command-line arguments parsing, interactive stdin fallback, and test execution for login CLI subcommands.
class LoginCliHandler {
  Future<void> execute(List<String> args) async {
    final values = _readOptions(args);
    final rawUri = values['vm-service-uri'];
    var loginId = values['login-id'];
    var password = values['password'];
    final unlockPin =
        values['unlock-pin'] ?? Platform.environment['PENGUIN_POS_UNLOCK_PIN'];
    var appRoot =
        values['app-root'] ??
        Platform.environment['PENGUIN_POS_ROOT'] ??
        '/Users/reddygona/Documents/PenguinPOS/penguin_pos';
    final device = values['device'];
    final entity = values['entity'];
    final env = values['env'];

    final mode = values['mode'] ?? 'full';

    if (loginId == null || loginId.trim().isEmpty) {
      stdout.write('Enter Login ID: ');
      loginId = stdin.readLineSync()?.trim();
    }

    if (loginId == null || loginId.isEmpty) {
      stderr.writeln('Error: Login ID is required.');
      exitCode = 64;
      return;
    }

    if (password == null || password.trim().isEmpty) {
      stdout.write('Enter Password: ');
      password = _readPassword();
    }

    if (password == null || password.isEmpty) {
      stderr.writeln('Error: Password is required.');
      exitCode = 64;
      return;
    }

    LaunchedPenguinPos? launched;
    try {
      Uri? uri = rawUri != null ? Uri.tryParse(rawUri) : null;
      if (uri == null) {
        if (appRoot.isEmpty) {
          stderr.writeln(
            'Provide --vm-service-uri or configure --app-root / PENGUIN_POS_ROOT env var.',
          );
          exitCode = 64;
          return;
        }
        launched = await PenguinPosAppLauncher().launch(
          appRoot: appRoot,
          device: device,
          entity: entity,
          env: env,
        );
        uri = launched.vmServiceUri;
      }

      final scenario = LoginScenario(
        id: 'valid_login',
        name: 'Valid PenguinPOS login',
        loginId: loginId,
        password: password,
        unlockPin: unlockPin,
      );

      final runner = PenguinPosLoginRunner();
      final result = mode == 'single'
          ? await runner.run(scenario, vmServiceUri: uri)
          : await runner.runFullSequence(scenario, vmServiceUri: uri);

      stdout.writeln(
        const JsonEncoder.withIndent('  ').convert(result.toJson()),
      );
      if (!result.passed) exitCode = 1;
    } finally {
      await launched?.close();
    }
  }

  Map<String, String> _readOptions(Iterable<String> args) {
    final values = <String, String>{};
    final iterator = args.iterator;
    while (iterator.moveNext()) {
      final option = iterator.current;
      if (!option.startsWith('--') || !iterator.moveNext()) {
        throw FormatException('Expected a value after $option');
      }
      values[option.substring(2)] = iterator.current;
    }
    return values;
  }

  String? _readPassword() {
    if (stdin.hasTerminal) {
      try {
        stdin.echoMode = false;
        final pwd = stdin.readLineSync()?.trim();
        stdin.echoMode = true;
        stdout.writeln();
        return pwd;
      } catch (_) {
        stdin.echoMode = true;
      }
    }
    return stdin.readLineSync()?.trim();
  }
}
