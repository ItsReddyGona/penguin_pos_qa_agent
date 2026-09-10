import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_driver/flutter_driver.dart';
import 'dart:convert';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/core/pos_automation_contract.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_state_snapshot.dart';

/// Reusable wrapper for FlutterDriver connection, key, and text finder UI interactions.
class DriverEngine implements Driver {
  FlutterDriver? _driver;
  Timer? _qaNoticeDismissTimer;

  @override
  Future<FlutterDriver> connect(
    Uri vmServiceUri, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    _driver = await FlutterDriver.connect(
      dartVmServiceUrl: vmServiceUri.toString(),
      timeout: timeout,
      // Driver command transcripts include text-entry payloads. Disable them
      // because credentials and PINs are runtime-only secrets.
      logCommunicationToFile: false,
    );
    return _driver!;
  }

  @override
  Future<void> waitFor(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final driver = _driver;
    if (driver == null) throw StateError('Driver is not connected');

    final deadline = DateTime.now().add(timeout);
    const probeTimeout = Duration(milliseconds: 500);
    var probeCount = 0;

    debugPrint('[DriverEngine] waitFor("$key") started, timeout=$timeout');
    while (_driver != null && DateTime.now().isBefore(deadline)) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;

      probeCount++;
      final found = await hasKey(
        key,
        timeout: remaining < probeTimeout ? remaining : probeTimeout,
      );
      if (found) {
        debugPrint(
          '[DriverEngine] waitFor("$key") FOUND after $probeCount probes',
        );
        return;
      }
    }

    debugPrint(
      '[DriverEngine] waitFor("$key") TIMEOUT after $probeCount probes',
    );
    throw TimeoutException('Timed out waiting for key "$key".', timeout);
  }

  @override
  Future<void> waitForAbsent(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final driver = _driver;
    if (driver == null) throw StateError('Driver is not connected');

    final deadline = DateTime.now().add(timeout);
    // Flutter Driver has no OR finder. Keep each probe short so an absent
    // candidate does not recreate the old multi-second per-item delay.
    const probeTimeout = Duration(milliseconds: 100);

    debugPrint(
      '[DriverEngine] waitForAbsent("$key") started, timeout=$timeout',
    );
    while (_driver != null && DateTime.now().isBefore(deadline)) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;

      final exists = await hasKey(
        key,
        timeout: remaining < probeTimeout ? remaining : probeTimeout,
      );
      if (!exists) {
        debugPrint(
          '[DriverEngine] waitForAbsent("$key") CLEARED (widget absent)',
        );
        return;
      }
    }

    debugPrint('[DriverEngine] waitForAbsent("$key") TIMEOUT');
    throw TimeoutException(
      'Timed out waiting for key "$key" to disappear.',
      timeout,
    );
  }

  /// Waits until one of [keys] appears and returns the matching key.
  ///
  /// Flutter Driver cannot wait for an OR finder, so this performs short,
  /// bounded probes. The target application's widget state, rather than a
  /// fixed startup delay, determines when the caller proceeds.
  @override
  Future<String> waitForAnyKey(
    Iterable<String> keys, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final candidates = keys.toList(growable: false);
    if (candidates.isEmpty) {
      throw ArgumentError.value(keys, 'keys', 'must not be empty');
    }

    final deadline = DateTime.now().add(timeout);
    const probeTimeout = Duration(milliseconds: 100);
    var cycleCount = 0;

    debugPrint(
      '[DriverEngine] waitForAnyKey(${candidates.join(", ")}) '
      'started, timeout=$timeout',
    );
    while (_driver != null && DateTime.now().isBefore(deadline)) {
      cycleCount++;
      for (final key in candidates) {
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) break;
        final keyFound = await hasKey(
          key,
          timeout: remaining < probeTimeout ? remaining : probeTimeout,
        );
        if (keyFound) {
          debugPrint(
            '[DriverEngine] waitForAnyKey FOUND "$key" '
            'on cycle #$cycleCount',
          );
          return key;
        }
      }
    }

    debugPrint(
      '[DriverEngine] waitForAnyKey TIMEOUT after $cycleCount cycles. '
      'Keys: ${candidates.join(", ")}',
    );
    throw TimeoutException(
      'Timed out waiting for one of: ${candidates.join(', ')}.',
      timeout,
    );
  }

  @override
  Future<void> waitForText(
    String text, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final driver = _driver;
    if (driver == null) throw StateError('Driver is not connected');
    await driver.waitFor(find.text(text), timeout: timeout);
  }

  @override
  Future<bool> hasKey(
    String key, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final driver = _driver;
    if (driver == null) return false;
    try {
      await driver.waitFor(find.byValueKey(key), timeout: timeout);
      return true;
    } catch (error) {
      _throwIfTargetDisconnected(error);
      return false;
    }
  }

  @override
  Future<bool> hasText(
    String text, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final driver = _driver;
    if (driver == null) return false;
    try {
      await driver.waitFor(find.text(text), timeout: timeout);
      return true;
    } catch (error) {
      _throwIfTargetDisconnected(error);
      return false;
    }
  }

  @override
  Future<void> enterText(
    String key,
    String text, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final driver = _driver;
    if (driver == null) throw StateError('Driver is not connected');
    debugPrint('[DriverEngine] enterText("$key", ${text.length} chars)');
    try {
      await driver.scrollIntoView(
        find.byValueKey(key),
        timeout: const Duration(seconds: 1),
      );
    } catch (_) {}
    await driver.tap(find.byValueKey(key), timeout: timeout);
    await driver.enterText(text, timeout: timeout);
  }

  @override
  Future<void> enterTextViaVirtualKeyboard(
    String targetInputKey,
    String text, {
    String keyPrefix = 'login.qwerty',
    TextInputMode mode = TextInputMode.driverDirect,
  }) async {
    final driver = _driver;
    if (driver == null) throw StateError('Driver is not connected');

    if (mode == TextInputMode.driverDirect) {
      await enterText(targetInputKey, text);
      return;
    }

    // 1. Focus target input field for custom virtual keyboards
    await tap(targetInputKey);

    // Clear existing text field content before virtual key entry
    await driver.enterText('');

    var isShiftActive = false;

    for (var i = 0; i < text.length; i++) {
      final char = text[i];

      if (mode == TextInputMode.customQwertyPad) {
        // Validate character compatibility
        if (!RegExp(r'^[a-zA-Z0-9.,_/# ]$').hasMatch(char)) {
          throw UnsupportedKeyboardCharacterException(
            position: i + 1,
            reason:
                'CustomQwertyPad layout cannot represent character at index',
          );
        }

        final isUpper = RegExp(r'^[A-Z]$').hasMatch(char);

        if (isUpper && !isShiftActive) {
          await tap(PosAutomationContract.qwertyShift(keyPrefix));
          isShiftActive = true;
        } else if (!isUpper && isShiftActive) {
          await tap(PosAutomationContract.qwertyShift(keyPrefix));
          isShiftActive = false;
        }

        if (char == ' ') {
          await tap(PosAutomationContract.qwertySpace(keyPrefix));
        } else {
          await tap(
            PosAutomationContract.qwertyKey(keyPrefix, char.toLowerCase()),
          );
        }
      } else if (mode == TextInputMode.customNumPad) {
        if (!RegExp(r'^[0-9.]$').hasMatch(char)) {
          throw UnsupportedKeyboardCharacterException(
            position: i + 1,
            reason: 'CustomNumPad layout cannot represent character at index',
          );
        }
        await tap(PosAutomationContract.numpadDigit(keyPrefix, char));
      }
    }

    // Ensure shift state is left off
    if (isShiftActive) {
      await tap(PosAutomationContract.qwertyShift(keyPrefix));
    }
  }

  @override
  Future<String?> tryGetText(
    String key, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final driver = _driver;
    if (driver == null) return null;
    try {
      await driver.waitFor(find.byValueKey(key), timeout: timeout);
      return await driver.getText(find.byValueKey(key), timeout: timeout);
    } catch (error) {
      _throwIfTargetDisconnected(error);
      return null;
    }
  }

  /// Reads text from a keyed Text, RichText, or editable field.
  ///
  /// Unlike [tryGetText], this preserves driver errors so a required test
  /// value cannot silently become a default value.
  @override
  Future<String> getText(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final driver = _driver;
    if (driver == null) throw StateError('Driver is not connected');
    await driver.waitFor(find.byValueKey(key), timeout: timeout);
    return driver.getText(find.byValueKey(key), timeout: timeout);
  }

  Future<void> enterTextDirect(String text) async {
    final driver = _driver;
    if (driver == null) throw StateError('Driver is not connected');
    await driver.enterText(text);
  }

  @override
  Future<void> tap(String key) async {
    final driver = _driver;
    if (driver == null) throw StateError('Driver is not connected');
    try {
      await driver.scrollIntoView(
        find.byValueKey(key),
        timeout: const Duration(seconds: 1),
      );
    } catch (_) {}
    await driver.tap(find.byValueKey(key));
  }

  @override
  Future<void> tapText(String text) async {
    final driver = _driver;
    if (driver == null) throw StateError('Driver is not connected');
    try {
      await driver.scrollIntoView(
        find.text(text),
        timeout: const Duration(seconds: 1),
      );
    } catch (_) {}
    await driver.tap(find.text(text));
  }

  @override
  Future<bool> tryTapText(
    String text, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final driver = _driver;
    if (driver == null) return false;
    try {
      await driver.waitFor(find.text(text), timeout: timeout);
      try {
        await driver.scrollIntoView(
          find.text(text),
          timeout: const Duration(seconds: 1),
        );
      } catch (_) {}
      await driver.tap(find.text(text));
      return true;
    } catch (error) {
      _throwIfTargetDisconnected(error);
      return false;
    }
  }

  @override
  Future<bool> tryTapKey(
    String key, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final driver = _driver;
    if (driver == null) return false;
    try {
      await driver.waitFor(find.byValueKey(key), timeout: timeout);
      try {
        await driver.scrollIntoView(
          find.byValueKey(key),
          timeout: const Duration(seconds: 1),
        );
      } catch (_) {}
      await driver.tap(find.byValueKey(key));
      return true;
    } catch (error) {
      _throwIfTargetDisconnected(error);
      return false;
    }
  }

  @override
  Future<String?> requestData(
    String message, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final driver = _driver;
    if (driver == null) return null;
    final start = DateTime.now();
    try {
      final res = await driver.requestData(message, timeout: timeout);
      final durationMs = DateTime.now().difference(start).inMilliseconds;
      if (durationMs >= 100) {
        debugPrint('[DriverEngine] requestData slow: ${durationMs}ms');
      }
      return res;
    } catch (error) {
      final durationMs = DateTime.now().difference(start).inMilliseconds;
      debugPrint('[DriverEngine] requestData failed after ${durationMs}ms');
      _throwIfTargetDisconnected(error);
      return null;
    }
  }

  @override
  Future<OrderStateSnapshot?> queryOrderState({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final response = await requestData('qa_order_state', timeout: timeout);
    if (response == null ||
        response.isEmpty ||
        response.contains('No requestData')) {
      return null;
    }

    try {
      final decoded = jsonDecode(response);
      if (decoded is! Map) return null;
      final snapshot = OrderStateSnapshot.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (snapshot.phase == 'unavailable') return null;
      return snapshot;
    } catch (_) {
      debugPrint('[DriverEngine] Failed to parse qa_order_state response');
      return null;
    }
  }

  @override
  Future<bool> clearSnackBars() async {
    final res = await requestData('clear_snackbars');
    final isAcknowledged = res == 'cleared' || res == 'snackbars_cleared';
    if (!isAcknowledged) {
      debugPrint(
        '[DriverEngine] clearSnackBars unacknowledged or extension unsupported (status="${res == null
            ? 'null'
            : res.contains('No requestData')
            ? 'unsupported'
            : 'unrecognized'}")',
      );
    }
    return isAcknowledged;
  }

  @override
  Future<bool> showQaTestNotice(QaTestNotice notice) async {
    _qaNoticeDismissTimer?.cancel();
    final response = await requestData(
      jsonEncode(notice.toJson()),
      // A notice must never consume the automation step timeout when the
      // optional target extension is unavailable.
      timeout: const Duration(milliseconds: 700),
    );
    final acknowledged = response == 'shown' || response == 'notice_shown';
    if (acknowledged) {
      // Notices are progress affordances, not modal gates. Never let one
      // prevent the next automation decision from reaching the target UI.
      _qaNoticeDismissTimer = Timer(const Duration(milliseconds: 700), () {
        unawaited(clearQaTestNotice());
      });
    }
    if (!acknowledged) {
      debugPrint(
        '[DriverEngine] QA notice unacknowledged or extension unsupported',
      );
    }
    return acknowledged;
  }

  @override
  Future<bool> clearQaTestNotice() async {
    _qaNoticeDismissTimer?.cancel();
    _qaNoticeDismissTimer = null;
    final response = await requestData(
      'qa_notice_clear',
      timeout: const Duration(milliseconds: 700),
    );
    final acknowledged = response == 'cleared' || response == 'notice_cleared';
    if (!acknowledged) {
      debugPrint(
        '[DriverEngine] QA notice clear unacknowledged or extension unsupported',
      );
    }
    return acknowledged;
  }

  @override
  Future<void> close() async {
    _qaNoticeDismissTimer?.cancel();
    _qaNoticeDismissTimer = null;
    // Invalidate the handle before awaiting FlutterDriver.close(). Any active
    // polling loop will then stop on its next bounded probe instead of
    // waiting for the full scenario timeout after PenguinPOS quits.
    final driver = _driver;
    _driver = null;
    try {
      await driver?.close().timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  Never _targetDisconnected() {
    _qaNoticeDismissTimer?.cancel();
    _qaNoticeDismissTimer = null;
    throw const TargetAppDisconnectedException();
  }

  void _throwIfTargetDisconnected(Object error) {
    if (isTargetAppDisconnectedError(error)) _targetDisconnected();
  }
}
