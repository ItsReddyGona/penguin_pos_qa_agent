import 'dart:async';

import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/api_trace_collector.dart';

/// Queues non-critical API telemetry work without delaying automation blocks.
///
/// Operations execute in insertion order. This keeps each step marker ahead of
/// its corresponding trace refresh, while allowing the UI automation loop to
/// continue immediately. [flush] is the run-boundary barrier: callers must
/// await it before closing the driver or reading a final report.
class TelemetryDispatcher {
  TelemetryDispatcher({
    required Driver driver,
    required ApiTraceCollector collector,
  }) : _driver = driver,
       _collector = collector;

  final Driver _driver;
  final ApiTraceCollector _collector;
  Future<void> _tail = Future<void>.value();

  /// Enqueues a marker and incremental trace fetch for [stepId].
  ///
  /// This method deliberately does not return a future to await in the hot
  /// execution path. The collector turns telemetry transport failures into
  /// warnings, so telemetry cannot fail an automation block.
  void captureStep(String stepId) {
    _enqueue(() async {
      await _collector.markStep(_driver, stepId);
      await _collector.fetchNewTraces(_driver);
    });
  }

  /// Enqueues one final trace refresh and waits for all queued telemetry.
  Future<void> flush() async {
    _enqueue(() => _collector.fetchNewTraces(_driver));
    await _tail;
    // The collector coalesces dashboard callbacks during execution. Force the
    // final notification through before the runner builds its final report.
    await _collector.flush();
  }

  void _enqueue(Future<void> Function() operation) {
    _tail = _tail.catchError((_) {}).then<void>((_) async {
      try {
        await operation();
      } catch (_) {
        // Collector operations normally absorb transport errors. Keep the
        // dispatcher defensive so a callback failure never stops later
        // telemetry or affects the test result.
      }
    });
  }
}
