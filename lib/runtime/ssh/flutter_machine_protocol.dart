import 'dart:convert';

sealed class FlutterMachineEvent {
  const FlutterMachineEvent();
}

class FlutterMachineAppStartEvent extends FlutterMachineEvent {
  const FlutterMachineAppStartEvent({required this.appId});

  final String appId;
}

class FlutterMachineDebugPortEvent extends FlutterMachineEvent {
  const FlutterMachineDebugPortEvent({
    required this.appId,
    required this.port,
    this.wsUri,
  });

  final String appId;
  final int port;
  final Uri? wsUri;
}

class FlutterMachineAppStartedEvent extends FlutterMachineEvent {
  const FlutterMachineAppStartedEvent({required this.appId});

  final String appId;
}

class FlutterMachineAppLogEvent extends FlutterMachineEvent {
  const FlutterMachineAppLogEvent({required this.message, this.appId});

  final String message;
  final String? appId;
}

class FlutterMachineAppStopEvent extends FlutterMachineEvent {
  const FlutterMachineAppStopEvent({required this.appId});

  final String appId;
}

class FlutterMachineDaemonErrorEvent extends FlutterMachineEvent {
  const FlutterMachineDaemonErrorEvent({required this.message});

  final String message;
}

class FlutterMachineProcessExitEvent extends FlutterMachineEvent {
  const FlutterMachineProcessExitEvent({required this.exitCode});

  final int exitCode;
}

/// Parses one JSON line emitted by `flutter run --machine`.
///
/// Flutter wraps daemon messages in a JSON list, even when a line contains a
/// single event. Unknown events are intentionally ignored for forward
/// compatibility with newer Flutter SDKs.
List<FlutterMachineEvent> parseFlutterMachineLine(String line) {
  final decoded = jsonDecode(line);
  final messages = decoded is List<Object?>
      ? decoded
      : decoded is Map<String, Object?>
      ? <Object?>[decoded]
      : throw const FormatException('Flutter machine output is not JSON.');

  final events = <FlutterMachineEvent>[];
  for (final rawMessage in messages) {
    if (rawMessage is! Map) continue;
    final message = Map<String, Object?>.from(rawMessage);
    final eventName = message['event'];
    final paramsValue = message['params'];
    final params = paramsValue is Map
        ? Map<String, Object?>.from(paramsValue)
        : const <String, Object?>{};

    switch (eventName) {
      case 'app.start':
        final appId = _stringValue(params['appId']);
        if (appId != null) {
          events.add(FlutterMachineAppStartEvent(appId: appId));
        }
        break;
      case 'app.debugPort':
        final appId = _stringValue(params['appId']);
        final port = _intValue(params['port']);
        final wsUriValue = _stringValue(params['wsUri']);
        if (appId != null && port != null && port > 0) {
          events.add(
            FlutterMachineDebugPortEvent(
              appId: appId,
              port: port,
              wsUri: wsUriValue == null ? null : Uri.tryParse(wsUriValue),
            ),
          );
        }
        break;
      case 'app.started':
        final appId = _stringValue(params['appId']);
        if (appId != null) {
          events.add(FlutterMachineAppStartedEvent(appId: appId));
        }
        break;
      case 'app.log':
        final messageText = _stringValue(params['log']);
        if (messageText != null && messageText.isNotEmpty) {
          events.add(
            FlutterMachineAppLogEvent(
              appId: _stringValue(params['appId']),
              message: messageText,
            ),
          );
        }
        break;
      case 'app.stop':
        final appId = _stringValue(params['appId']);
        if (appId != null) {
          events.add(FlutterMachineAppStopEvent(appId: appId));
        }
        break;
      case 'daemon.log':
      case 'daemon.logMessage':
        final messageText =
            _stringValue(params['message']) ?? _stringValue(params['log']);
        if (messageText != null && messageText.isNotEmpty) {
          events.add(FlutterMachineAppLogEvent(message: messageText));
        }
        break;
      case 'daemon.showMessage':
        final messageText =
            _stringValue(params['message']) ??
            _stringValue(params['title']) ??
            'Flutter reported an error.';
        events.add(FlutterMachineDaemonErrorEvent(message: messageText));
        break;
    }
  }
  return events;
}

String encodeFlutterStopCommand({
  required int requestId,
  required String appId,
}) {
  return jsonEncode(<Object?>[
    <String, Object?>{
      'id': requestId,
      'method': 'app.stop',
      'params': <String, Object?>{'appId': appId},
    },
  ]);
}

String? _stringValue(Object? value) => value is String ? value : null;

int? _intValue(Object? value) => switch (value) {
  int value => value,
  String value => int.tryParse(value),
  _ => null,
};
