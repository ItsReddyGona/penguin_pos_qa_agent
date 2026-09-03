import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_cancellation.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/api_trace_collector.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/telemetry_dispatcher.dart';

/// Execution context passed to every [AutomationBlock] during test pipeline execution.
class ExecutionContext {
  final Driver driver;
  final Duration timeout;
  final void Function(ExecutionEvent event)? onEvent;
  final ApiTraceCollector? telemetryCollector;
  final TelemetryDispatcher? telemetryDispatcher;
  final QaTestNoticeDisplayMode noticeDisplayMode;
  final ExecutionCancellationSignal cancellationSignal;

  /// Shared non-sensitive state payload passed between blocks in a pipeline.
  final Map<String, Object?> state = {};

  ExecutionContext({
    required this.driver,
    this.timeout = const Duration(seconds: 45),
    this.onEvent,
    this.telemetryCollector,
    this.telemetryDispatcher,
    this.noticeDisplayMode = QaTestNoticeDisplayMode.warningsAndErrors,
    ExecutionCancellationSignal? cancellationSignal,
  }) : cancellationSignal =
           cancellationSignal ??
           ExecutionCancellationScope.current ??
           ExecutionCancellationSignal();

  void emit(
    String title,
    String message, {
    ExecutionEventLevel level = ExecutionEventLevel.info,
  }) {
    onEvent?.call(ExecutionEvent(title: title, message: message, level: level));
  }

  /// Sends an optional, user-dismissible in-app QA status notice.
  /// Failure is deliberately ignored so a target without the QA overlay remains testable.
  Future<void> showNotice(
    QaTestNoticeSeverity severity,
    String title,
    String message, {
    bool isMilestone = false,
  }) async {
    if (!noticeDisplayMode.shouldShow(severity, isMilestone: isMilestone)) {
      return;
    }
    await driver.showQaTestNotice(
      QaTestNotice(severity: severity, title: title, message: message),
    );
  }

  /// Explicitly clears the active notice when a runner completes or resets.
  Future<void> clearNotice() => driver.clearQaTestNotice();
}
