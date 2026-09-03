import 'dart:async';

import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_state_snapshot.dart';

/// Signals that the target PenguinPOS VM Service is no longer reachable.
///
/// Optional finder and extension helpers must preserve this condition instead
/// of converting it into a normal "not found" result. Runners use it to stop
/// immediately when the target application is closed.
class TargetAppDisconnectedException implements Exception {
  const TargetAppDisconnectedException();

  @override
  String toString() => 'PenguinPOS target disconnected.';
}

bool isTargetAppDisconnectedError(Object error) {
  if (error is TargetAppDisconnectedException) return true;
  final message = error.toString().toLowerCase();

  // Do not classify generic WebSocket, SocketException, or command timeout
  // wording as a target exit. Flutter Driver uses those transports for normal
  // commands too, so an ordinary command/API timeout may include those terms
  // while the target application is still healthy.
  return message.contains('service has disappeared') ||
      message.contains('rpcerror 112') ||
      message.contains('service protocol connection closed') ||
      (message.contains('vm service') &&
          (message.contains('disappeared') ||
              message.contains('disconnected') ||
              message.contains('connection closed')));
}

/// Defines supported text input strategies for UI testing.
enum TextInputMode {
  /// Direct Flutter Driver text injection.
  driverDirect,

  /// Virtual key tapping on CustomQwertyPad.
  customQwertyPad,

  /// Virtual key tapping on CustomNumPad.
  customNumPad,
}

/// Security-hardened exception thrown when a string contains a character unmappable on the virtual keyboard.
///
/// To prevent secret disclosure (e.g. leaking password characters), the exception message intentionally
/// specifies position index and character classification rather than raw symbol payload.
class UnsupportedKeyboardCharacterException implements Exception {
  final int position;
  final String reason;

  const UnsupportedKeyboardCharacterException({
    required this.position,
    this.reason = 'Virtual keyboard layout cannot represent character',
  });

  @override
  String toString() =>
      'UnsupportedKeyboardCharacterException: $reason at position $position.';
}

/// Abstract driver interface decoupling test blocks from Flutter Driver execution.
abstract interface class Driver {
  Future<void> connect(
    Uri vmServiceUri, {
    Duration timeout = const Duration(seconds: 45),
  });

  Future<void> waitFor(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  });

  Future<void> waitForAbsent(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  });

  Future<String> waitForAnyKey(
    Iterable<String> keys, {
    Duration timeout = const Duration(seconds: 45),
  });

  Future<void> waitForText(
    String text, {
    Duration timeout = const Duration(seconds: 45),
  });

  Future<bool> hasKey(
    String key, {
    Duration timeout = const Duration(seconds: 2),
  });

  Future<bool> hasText(
    String text, {
    Duration timeout = const Duration(seconds: 2),
  });

  Future<void> enterText(
    String key,
    String text, {
    Duration timeout = const Duration(seconds: 10),
  });

  Future<void> enterTextViaVirtualKeyboard(
    String targetInputKey,
    String text, {
    String keyPrefix = 'login.qwerty',
    TextInputMode mode = TextInputMode.customQwertyPad,
  });

  Future<String?> tryGetText(
    String key, {
    Duration timeout = const Duration(seconds: 3),
  });

  Future<String> getText(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  });

  Future<void> tap(String key);

  Future<void> tapText(String text);

  Future<bool> tryTapText(
    String text, {
    Duration timeout = const Duration(seconds: 3),
  });

  Future<bool> tryTapKey(
    String key, {
    Duration timeout = const Duration(seconds: 3),
  });

  /// Sends a custom text command message to the target app's Flutter Driver extension handler.
  Future<String?> requestData(
    String message, {
    Duration timeout = const Duration(seconds: 5),
  });

  /// Reads the target's structured order state. Returns null for older targets.
  Future<OrderStateSnapshot?> queryOrderState({
    Duration timeout = const Duration(seconds: 3),
  });

  /// Instantly requests the target application to clear active SnackBars.
  /// Returns `true` if acknowledged by the target app extension, `false` otherwise.
  Future<bool> clearSnackBars();

  /// Displays a QA status overlay in the target app.
  ///
  /// Returns `false` when the target does not expose the optional QA extension.
  Future<bool> showQaTestNotice(QaTestNotice notice);

  /// Clears the active QA status overlay, if the target supports it.
  Future<bool> clearQaTestNotice();

  Future<void> close();
}
