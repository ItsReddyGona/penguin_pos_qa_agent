/// Classification of HTTP execution outcome for telemetry recording.
enum ApiTraceResult {
  success,
  httpError,
  connectTimeout,
  sendTimeout,
  receiveTimeout,
  connectionError,
  cancelled,
  unexpectedError,
}

/// Network scheme reported by the target application's telemetry bridge.
///
/// This is transport information only. It must not be used to infer the
/// deployment environment; a local service may be exposed through HTTPS.
enum ApiTransport { http, https, unknown }

/// Deployment mode explicitly reported by the target application.
///
/// The mode deliberately remains independent from [ApiTransport] so the UI
/// never guesses that HTTP means local or HTTPS means cloud.
enum ApiTraceMode { local, cloud, unknown }

/// Secret-safe telemetry event capturing Dio HTTP activity in PenguinPOS.
class ApiTraceEvent {
  final int traceId;
  final String stepId;
  final int startTimeMs;
  final int endTimeMs;
  final int durationMs;
  final String method;
  final String route;
  final int? statusCode;
  final ApiTraceResult result;
  final int timeoutBudgetMs;
  final String sanitizedPreview;
  final int responseSizeBytes;
  final ApiTransport transport;
  final ApiTraceMode mode;

  const ApiTraceEvent({
    required this.traceId,
    required this.stepId,
    required this.startTimeMs,
    required this.endTimeMs,
    required this.durationMs,
    required this.method,
    required this.route,
    this.statusCode,
    required this.result,
    required this.timeoutBudgetMs,
    required this.sanitizedPreview,
    required this.responseSizeBytes,
    this.transport = ApiTransport.unknown,
    this.mode = ApiTraceMode.unknown,
  });

  Map<String, dynamic> toJson() => {
    'traceId': traceId,
    'stepId': stepId,
    'startTimeMs': startTimeMs,
    'endTimeMs': endTimeMs,
    'durationMs': durationMs,
    'method': method,
    'route': route,
    'statusCode': statusCode,
    'result': result.name,
    'timeoutBudgetMs': timeoutBudgetMs,
    'sanitizedPreview': sanitizedPreview,
    'responseSizeBytes': responseSizeBytes,
    'transport': transport.name,
    'mode': mode.name,
  };

  factory ApiTraceEvent.fromJson(Map<String, dynamic> json) => ApiTraceEvent(
    traceId: _asInt(json['traceId']),
    stepId: _asString(json['stepId'], fallback: 'none'),
    startTimeMs: _asInt(json['startTimeMs']),
    endTimeMs: _asInt(json['endTimeMs']),
    durationMs: _asInt(json['durationMs']),
    method: _asString(json['method'], fallback: 'GET').toUpperCase(),
    route: _safeRoute(_asString(json['route'], fallback: '/')),
    statusCode: _asNullableInt(json['statusCode']),
    result: _resultFromWire(json['result']),
    timeoutBudgetMs: _asInt(json['timeoutBudgetMs']),
    sanitizedPreview: _safePreview(json['sanitizedPreview']),
    responseSizeBytes: _asInt(json['responseSizeBytes']),
    transport: _transportFromWire(json['transport']),
    mode: _modeFromWire(json['mode']),
  );

  static int _asInt(Object? value) =>
      value is int ? value : int.tryParse('$value') ?? 0;

  static int? _asNullableInt(Object? value) {
    if (value == null) return null;
    return _asInt(value);
  }

  static String _asString(Object? value, {required String fallback}) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? fallback : text;
  }

  /// Prevent query parameters and fragments from crossing the QA bridge.
  static String _safeRoute(String route) {
    final uri = Uri.tryParse(route);
    final path = uri?.path ?? route.split(RegExp(r'[?#]')).first;
    if (path.isEmpty) return '/';
    return path.startsWith('/') ? path : '/$path';
  }

  /// The target app is responsible for redaction. Bound the preview here so a
  /// faulty handler cannot flood logs or the chat surface with a response body.
  static String _safePreview(Object? value) {
    if (value is! String) return '';
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length <= 512
        ? normalized
        : '${normalized.substring(0, 512)}…';
  }

  static ApiTraceResult _resultFromWire(Object? value) {
    final normalized = '$value'.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    return switch (normalized) {
      'success' => ApiTraceResult.success,
      'httperror' || 'badresponse' => ApiTraceResult.httpError,
      'connecttimeout' || 'connectiontimeout' => ApiTraceResult.connectTimeout,
      'sendtimeout' => ApiTraceResult.sendTimeout,
      'receivetimeout' => ApiTraceResult.receiveTimeout,
      'connectionerror' => ApiTraceResult.connectionError,
      'cancel' || 'cancelled' => ApiTraceResult.cancelled,
      _ => ApiTraceResult.unexpectedError,
    };
  }

  static ApiTransport _transportFromWire(Object? value) =>
      switch ('$value'.toLowerCase()) {
        'http' => ApiTransport.http,
        'https' => ApiTransport.https,
        _ => ApiTransport.unknown,
      };

  static ApiTraceMode _modeFromWire(Object? value) =>
      switch ('$value'.toLowerCase()) {
        'local' => ApiTraceMode.local,
        'cloud' => ApiTraceMode.cloud,
        _ => ApiTraceMode.unknown,
      };
}
