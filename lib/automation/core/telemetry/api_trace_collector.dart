import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/api_trace_event.dart';

/// Collector for fetching incremental API telemetry traces from a running target app.
class ApiTraceCollector {
  ApiTraceCollector({
    this.onTracesCaptured,
    this.onTraceCaptured,
    this.onTelemetryWarning,
    this.notificationBatchWindow = const Duration(milliseconds: 150),
  });

  int _cursorTraceId = 0;
  final List<ApiTraceEvent> _capturedTraces = <ApiTraceEvent>[];

  Future<List<ApiTraceEvent>>? _fetchInProgress;
  Future<void> _backgroundWork = Future<void>.value();
  Timer? _notificationTimer;
  bool _notificationPending = false;
  final ValueChanged<List<ApiTraceEvent>>? onTracesCaptured;
  final ValueChanged<ApiTraceEvent>? onTraceCaptured;
  final ValueChanged<String>? onTelemetryWarning;

  /// Limits how often a live dashboard is rebuilt while traces are arriving.
  final Duration notificationBatchWindow;

  int get cursorTraceId => _cursorTraceId;
  List<ApiTraceEvent> get capturedTraces => List.unmodifiable(_capturedTraces);

  /// Sends a step marker identifier to the target app extension.
  Future<void> markStep(Driver driver, String stepId) async {
    try {
      await driver.requestData('api_trace_mark:$stepId');
    } catch (_) {
      _warn('Unable to mark the active API telemetry step.');
    }
  }

  /// Queues a step marker without holding up the automation pipeline.
  ///
  /// Queued telemetry commands are processed in order, so a marker is always
  /// sent before the trace refresh queued for that same step. Errors are
  /// contained by the collector and never fail the test execution.
  void queueStepMarker(Driver driver, String stepId) {
    _enqueueBackground(() => markStep(driver, stepId));
  }

  /// Queues an incremental trace refresh without blocking the next UI action.
  void queueTraceFetch(Driver driver) {
    _enqueueBackground(() async {
      await fetchNewTraces(driver);
    });
  }

  /// Waits for all already queued telemetry work and dispatches any batched UI
  /// notification. A final snapshot is emitted even when no new trace arrived,
  /// so callers can safely construct a complete report at a run boundary.
  Future<void> flush() async {
    await _backgroundWork;
    _flushTraceNotification(traces: List.unmodifiable(_capturedTraces));
  }

  /// Stops pending dashboard notification timers when a run is discarded.
  void dispose() {
    _notificationTimer?.cancel();
    _notificationTimer = null;
    _notificationPending = false;
  }

  /// Incremental retrieval of newly recorded traces since [_cursorTraceId].
  ///
  /// Calls are coalesced to avoid issuing concurrent VM-service driver
  /// commands when a caller asks for live refresh more than once.
  Future<List<ApiTraceEvent>> fetchNewTraces(Driver driver) {
    final inProgress = _fetchInProgress;
    if (inProgress != null) return inProgress;

    late final Future<List<ApiTraceEvent>> operation;
    operation = _fetchNewTraces(driver).whenComplete(() {
      if (identical(_fetchInProgress, operation)) {
        _fetchInProgress = null;
      }
    });
    _fetchInProgress = operation;
    return operation;
  }

  Future<List<ApiTraceEvent>> _fetchNewTraces(Driver driver) async {
    final newTraces = <ApiTraceEvent>[];
    try {
      final res = await driver.requestData('api_traces_since:$_cursorTraceId');
      if (res == null || res.isEmpty || res.contains('No requestData')) {
        return newTraces;
      }
      final decoded = jsonDecode(res);
      if (decoded is! Map) {
        _warn('API telemetry response was not a JSON object.');
        return newTraces;
      }
      final payload = Map<String, dynamic>.from(decoded);
      final newCursor = _parseCursor(payload['cursor']);
      final rawEvents = payload['events'] as List<dynamic>? ?? <dynamic>[];

      for (final raw in rawEvents) {
        if (raw is Map) {
          final event = ApiTraceEvent.fromJson(Map<String, dynamic>.from(raw));
          if (event.traceId <= _cursorTraceId ||
              _capturedTraces.any((trace) => trace.traceId == event.traceId)) {
            continue;
          }
          newTraces.add(event);
          _capturedTraces.add(event);
          onTraceCaptured?.call(event);
        }
      }
      _cursorTraceId = newCursor < _cursorTraceId ? _cursorTraceId : newCursor;
      if (newTraces.isNotEmpty) _scheduleTraceNotification();
    } catch (_) {
      _warn('Unable to retrieve API telemetry from the target application.');
    }
    return newTraces;
  }

  /// Clears local and target app trace buffers.
  Future<void> clear(Driver driver) async {
    _cursorTraceId = 0;
    _capturedTraces.clear();
    _flushTraceNotification(traces: const <ApiTraceEvent>[]);
    try {
      await driver.requestData('api_trace_clear');
    } catch (_) {}
  }

  int _parseCursor(Object? value) => switch (value) {
    int cursor => cursor,
    String cursor => int.tryParse(cursor) ?? _cursorTraceId,
    _ => _cursorTraceId,
  };

  void _enqueueBackground(Future<void> Function() operation) {
    _backgroundWork = _backgroundWork.then<void>((_) => operation()).catchError(
      (Object _) {
        // Individual telemetry calls already emit safe warnings. This guard
        // keeps one unexpected failure from poisoning the remaining queue.
      },
    );
  }

  void _scheduleTraceNotification() {
    if (_notificationPending) return;
    _notificationPending = true;
    _notificationTimer = Timer(
      notificationBatchWindow,
      _flushTraceNotification,
    );
  }

  void _flushTraceNotification({List<ApiTraceEvent>? traces}) {
    _notificationTimer?.cancel();
    _notificationTimer = null;
    final wasPending = _notificationPending;
    _notificationPending = false;
    if (wasPending || traces != null) {
      onTracesCaptured?.call(traces ?? List.unmodifiable(_capturedTraces));
    }
  }

  void _warn(String message) {
    debugPrint('[ApiTraceCollector] $message');
    onTelemetryWarning?.call(message);
  }
}
