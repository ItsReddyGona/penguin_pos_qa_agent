import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/automation_pipeline.dart';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_cancellation.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/core/pipeline_run_result.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/api_trace_collector.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/telemetry_dispatcher.dart';
import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/core/secret_redactor.dart';
import 'package:penguin_pos_qa_agent/runtime/driver_engine.dart';

/// Orchestrates execution of an ordered pipeline of [AutomationBlock]s against a target driver session.
class PipelineRunner {
  Future<PipelineRunResult> runPipeline({
    required List<AutomationBlock> blocks,
    required Uri vmServiceUri,
    List<AutomationBlock> cleanupBlocks = const <AutomationBlock>[],
    Driver? driver,
    Duration timeout = const Duration(seconds: 45),
    void Function(ExecutionEvent event)? onExecutionEvent,
    void Function(String scenarioName)? onScenarioCompleted,
    List<String?> secretsToRedact = const <String?>[],
    ApiTraceCollector? telemetryCollector,
    QaTestNoticeDisplayMode noticeDisplayMode =
        QaTestNoticeDisplayMode.warningsAndErrors,
    bool connectDriver = true,
    bool closeDriver = true,
    bool clearSnackBarsBeforeBlock = true,
    ExecutionCancellationSignal? cancellationSignal,
  }) async {
    final startedAt = DateTime.now();
    final activeDriver = driver ?? DriverEngine();
    final telemetryDispatcher = telemetryCollector == null
        ? null
        : TelemetryDispatcher(
            driver: activeDriver,
            collector: telemetryCollector,
          );
    final context = ExecutionContext(
      driver: activeDriver,
      timeout: timeout,
      onEvent: onExecutionEvent,
      telemetryCollector: telemetryCollector,
      telemetryDispatcher: telemetryDispatcher,
      noticeDisplayMode: noticeDisplayMode,
      cancellationSignal: cancellationSignal,
    );

    final executed = <String>[];
    var isPassed = true;
    String? errorStr;
    var wasAppClosed = false;
    var wasCancelled = false;

    try {
      if (connectDriver) {
        await context.cancellationSignal.race(
          activeDriver.connect(vmServiceUri, timeout: timeout),
        );
      }
      context.emit('Driver Connected', 'Connected to PenguinPOS Driver.');

      final pipeline = AutomationPipeline();
      final ranNames = await pipeline.execute(
        blocks,
        context,
        onScenarioCompleted: onScenarioCompleted,
        clearSnackBarsBeforeBlock: clearSnackBarsBeforeBlock,
      );
      executed.addAll(ranNames);
    } catch (error) {
      isPassed = false;
      errorStr = redactSecrets(error.toString(), secretsToRedact);
      wasCancelled = error is ExecutionCancelledException;
      wasAppClosed = wasCancelled || isTargetAppDisconnectedError(error);
      context.emit(
        'Pipeline Error',
        errorStr,
        level: ExecutionEventLevel.error,
      );
      if (!wasAppClosed && !wasCancelled) {
        try {
          await context.showNotice(
            QaTestNoticeSeverity.error,
            'Test suite failed',
            'Execution stopped. Check the QA Agent terminal for details.',
          );
        } catch (_) {}
      }
    }

    bool? cleanupPassed;
    String? cleanupDetail;

    if (cleanupBlocks.isNotEmpty && !wasAppClosed && !wasCancelled) {
      try {
        // Run cleanup through the same pipeline wrapper so it is included in
        // the background telemetry queue before the final flush.
        await AutomationPipeline().execute(
          cleanupBlocks,
          context,
          emitStepEvents: false,
          clearSnackBarsBeforeBlock: clearSnackBarsBeforeBlock,
        );
        cleanupPassed = true;
        context.emit(
          'Cleanup Completed',
          'Post-pipeline cleanup executed successfully.',
          level: ExecutionEventLevel.success,
        );
      } catch (cleanupError) {
        cleanupPassed = false;
        cleanupDetail = redactSecrets(cleanupError.toString(), secretsToRedact);
        context.emit(
          'Cleanup Warning',
          'Pipeline completed, but cleanup failed. Test isolation is not guaranteed.',
          level: ExecutionEventLevel.error,
        );
      }
    } else if (cleanupBlocks.isNotEmpty && wasAppClosed) {
      cleanupPassed = false;
      cleanupDetail = 'Cleanup skipped because PenguinPOS disconnected.';
    }

    // Leave a failure notice available for the operator to read and dismiss.
    // A subsequent successful run clears any stale notice during teardown.
    if (isPassed && !context.cancellationSignal.isCancelled) {
      try {
        await activeDriver.clearQaTestNotice();
      } catch (_) {}
    }
    // The final barrier preserves complete metrics while the normal block path
    // remains fire-and-forget. It must happen before the driver is closed.
    if (!wasAppClosed && !context.cancellationSignal.isCancelled) {
      await telemetryDispatcher?.flush();
    }
    if (closeDriver) {
      try {
        await activeDriver.close();
      } catch (_) {}
    }

    return PipelineRunResult(
      passed: isPassed,
      startedAt: startedAt,
      finishedAt: DateTime.now(),
      scenariosExecuted: executed,
      vmServiceUri: vmServiceUri,
      error: errorStr,
      cleanupPassed: cleanupPassed,
      cleanupDetail: cleanupDetail,
      wasAppClosedByUser: wasAppClosed,
      metadata: Map<String, Object?>.unmodifiable(context.state),
    );
  }
}
