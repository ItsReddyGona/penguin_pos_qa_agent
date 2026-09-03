import 'dart:async';
import 'dart:convert';

import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_cancellation.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/api_trace_event.dart';

enum LoginApiExpectation { accepted, rejected }

/// Waits for the completed PenguinPOS login HTTP request exposed by the
/// QA-gated telemetry bridge. No credentials or request payloads cross it.
class LoginApiCallBarrier {
  const LoginApiCallBarrier._({required this.cursor});

  static const _loginRoute = '/authn/api/v1/pos/login';

  /// Minimum time the barrier will poll for an API response.
  ///
  /// The PenguinPOS login API has a 30-second server-side timeout. This
  /// constant adds a 5-second buffer so the barrier never races against that
  /// deadline regardless of how much of [ExecutionContext.timeout] was already
  /// spent on field entry and UI operations before the Sign In tap.
  static const _kMinApiTimeout = Duration(seconds: 35);

  final int cursor;

  /// Captures the latest completed trace before the Sign In tap. This prevents
  /// a prior test case's login request from satisfying the next case.
  static Future<LoginApiCallBarrier> arm(Driver driver) async {
    final payload = await _readPayload(driver, cursor: 0);
    if (payload == null) {
      throw StateError(
        'PenguinPOS did not expose the QA API trace bridge before login.',
      );
    }
    return LoginApiCallBarrier._(cursor: payload.cursor);
  }

  Future<ApiTraceEvent> waitForCompletion(
    Driver driver, {
    required LoginApiExpectation expectation,
    required Duration timeout,
  }) async {
    // Always give the barrier at least _kMinApiTimeout so that the API's own
    // 30-second deadline cannot expire while the polling window is still open.
    final effectiveTimeout = timeout > _kMinApiTimeout
        ? timeout
        : _kMinApiTimeout;
    final deadline = DateTime.now().add(effectiveTimeout);
    var nextCursor = cursor;

    while (DateTime.now().isBefore(deadline)) {
      ExecutionCancellationScope.current?.throwIfCancelled();
      final payload = await _readPayload(driver, cursor: nextCursor);
      if (payload != null) {
        nextCursor = payload.cursor < nextCursor ? nextCursor : payload.cursor;
        for (final trace in payload.events) {
          if (trace.method != 'POST' || trace.route != _loginRoute) continue;
          _verifyResult(trace, expectation);
          return trace;
        }
      }
      final delay = Future<void>.delayed(const Duration(milliseconds: 150));
      await (ExecutionCancellationScope.current?.race(delay) ?? delay);
    }

    throw TimeoutException(
      'PenguinPOS did not complete POST $_loginRoute before timeout.',
      effectiveTimeout,
    );
  }

  static void _verifyResult(
    ApiTraceEvent trace,
    LoginApiExpectation expectation,
  ) {
    final statusCode = trace.statusCode;
    switch (expectation) {
      case LoginApiExpectation.accepted:
        if (trace.result == ApiTraceResult.success &&
            statusCode != null &&
            statusCode >= 200 &&
            statusCode < 300) {
          return;
        }
        throw StateError(
          'Login API failed with status ${statusCode ?? 'unknown'} '
          '(${trace.result.name}).',
        );
      case LoginApiExpectation.rejected:
        if (trace.result == ApiTraceResult.httpError &&
            statusCode != null &&
            statusCode >= 400 &&
            statusCode < 500) {
          return;
        }
        throw StateError(
          'Invalid credentials were expected to be rejected, but the login '
          'API completed with status ${statusCode ?? 'unknown'} '
          '(${trace.result.name}).',
        );
    }
  }

  static Future<_TracePayload?> _readPayload(
    Driver driver, {
    required int cursor,
  }) async {
    final operation = driver.requestData(
      'api_traces_since:$cursor',
      timeout: const Duration(seconds: 2),
    );
    final response =
        await (ExecutionCancellationScope.current?.race(operation) ??
            operation);
    if (response == null ||
        response.isEmpty ||
        response.contains('No requestData')) {
      return null;
    }
    try {
      final decoded = jsonDecode(response);
      if (decoded is! Map) return null;
      final json = Map<String, dynamic>.from(decoded);
      final nextCursor = switch (json['cursor']) {
        final int value => value,
        final String value => int.tryParse(value) ?? cursor,
        _ => cursor,
      };
      final events = <ApiTraceEvent>[];
      for (final raw in json['events'] as List<dynamic>? ?? const <dynamic>[]) {
        if (raw is Map) {
          events.add(ApiTraceEvent.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
      return _TracePayload(cursor: nextCursor, events: events);
    } catch (_) {
      return null;
    }
  }
}

class _TracePayload {
  const _TracePayload({required this.cursor, required this.events});

  final int cursor;
  final List<ApiTraceEvent> events;
}
