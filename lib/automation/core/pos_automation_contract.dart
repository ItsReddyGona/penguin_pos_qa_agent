import 'dart:convert';

import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_keys.dart';

class IncompatibleAppException implements Exception {
  final String message;
  const IncompatibleAppException(this.message);

  @override
  String toString() => 'IncompatibleAppException: $message';
}

/// PosAutomationContract handles mode-aware preflight key verification and key builder helpers against PenguinPOS targets.
abstract final class PosAutomationContract {
  static const version = '1.2.0';

  static Future<Set<String>> probeCapabilities(Driver driver) async {
    final capabilities = <String>{};
    try {
      final response = await driver.requestData(
        'qa_contract_version',
        timeout: const Duration(seconds: 3),
      );
      if (response == null ||
          response.isEmpty ||
          response.contains('No requestData')) {
        return capabilities;
      }
      final decoded = jsonDecode(response);
      if (decoded is! Map) return capabilities;
      capabilities.add('contract_version');
      if (decoded['orderStateQuery'] == true) {
        capabilities.add('order_state_query');
      }
      if (decoded['version'] is String) {
        capabilities.add('version:${decoded['version']}');
      }
    } catch (_) {
      // Older targets do not expose capability probing.
    }
    return capabilities;
  }

  // Generic global Snackbar keys across all POS feature modules
  static const snackBar = 'global.snackbar';
  static const snackBarDismiss = 'global.snackbar_dismiss';

  // Key builders for CustomQwertyPad
  static String qwertyKey(String prefix, String char) => '$prefix.key.$char';
  static String qwertyShift(String prefix) => '$prefix.shift';
  static String qwertySpace(String prefix) => '$prefix.space';
  static String qwertyBackspace(String prefix) => '$prefix.backspace';
  static String qwertyDelete(String prefix) => '$prefix.delete';
  static String qwertyEnter(String prefix) => '$prefix.enter';

  // Key builders for CustomNumPad
  static String numpadDigit(String prefix, String digit) =>
      '$prefix.digit.$digit';
  static String numpadBackspace(String prefix) => '$prefix.backspace';
  static String numpadClear(String prefix) => '$prefix.clear';
  static String numpadEnter(String prefix) => '$prefix.enter';

  /// Performs preflight key presence verification matching the active [mode].
  static Future<void> verifyContract(
    Driver driver, {
    TextInputMode mode = TextInputMode.customQwertyPad,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    // 1. Verify core login screen controls
    final hasLoginId = await driver.hasKey(
      PenguinPosLoginKeys.loginId,
      timeout: timeout,
    );
    if (!hasLoginId) {
      throw const IncompatibleAppException(
        'Target PenguinPOS build does not implement QA Contract v1 (missing key "${PenguinPosLoginKeys.loginId}").',
      );
    }

    // 2. Mode-aware key verification
    if (mode == TextInputMode.customQwertyPad) {
      final sampleKey = qwertyKey('login.qwerty', 'a');
      final hasVirtualKey = await driver.hasKey(
        sampleKey,
        timeout: const Duration(seconds: 2),
      );
      if (!hasVirtualKey) {
        throw IncompatibleAppException(
          'Target PenguinPOS build does not expose custom QWERTY keys (missing key "$sampleKey").',
        );
      }
    }
  }
}
