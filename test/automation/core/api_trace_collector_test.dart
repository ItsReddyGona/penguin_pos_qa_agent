import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/api_trace_collector.dart';

class _RecordingDriver implements Driver {
  final List<String> requests = <String>[];
  final List<String?> responses;

  _RecordingDriver(this.responses);

  @override
  Future<String?> requestData(
    String message, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    requests.add(message);
    return responses.removeAt(0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'background telemetry preserves command order and batches UI updates',
    () async {
      final updates = <int>[];
      final collector = ApiTraceCollector(
        notificationBatchWindow: Duration.zero,
        onTracesCaptured: (traces) => updates.add(traces.length),
      );
      final driver = _RecordingDriver(<String?>[
        'marked',
        '{"cursor":1,"events":[{"traceId":1,"stepId":"login","result":"success"}]}',
        'marked',
        '{"cursor":2,"events":[{"traceId":2,"stepId":"home","result":"success"}]}',
      ]);

      collector.queueStepMarker(driver, 'login');
      collector.queueTraceFetch(driver);
      collector.queueStepMarker(driver, 'home');
      collector.queueTraceFetch(driver);

      await collector.flush();

      expect(driver.requests, <String>[
        'api_trace_mark:login',
        'api_traces_since:0',
        'api_trace_mark:home',
        'api_traces_since:1',
      ]);
      expect(collector.capturedTraces, hasLength(2));
      expect(updates, <int>[2]);
    },
  );
}
