import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/api_trace_collector.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/telemetry_dispatcher.dart';

class _TelemetryDriver implements Driver {
  _TelemetryDriver({this.includeTrace = false});

  final List<String> requests = <String>[];
  final Completer<void> allowFirstRequest = Completer<void>();
  final bool includeTrace;
  bool _holdFirstRequest = true;

  @override
  Future<String?> requestData(
    String message, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    requests.add(message);
    if (_holdFirstRequest) {
      _holdFirstRequest = false;
      await allowFirstRequest.future;
    }
    if (includeTrace && message.startsWith('api_traces_since:')) {
      return '{"cursor": 1, "events": ['
          '{"traceId": 1, "stepId": "checkout", "result": "success"}'
          ']}';
    }
    return '{"cursor": 0, "events": []}';
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'queues step telemetry without blocking and flushes it in order',
    () async {
      final driver = _TelemetryDriver();
      final dispatcher = TelemetryDispatcher(
        driver: driver,
        collector: ApiTraceCollector(),
      );

      dispatcher.captureStep('first');
      dispatcher.captureStep('second');
      final flushed = dispatcher.flush();
      var completed = false;
      unawaited(flushed.then((_) => completed = true));

      await Future<void>.delayed(Duration.zero);
      expect(driver.requests, <String>['api_trace_mark:first']);
      expect(completed, isFalse);

      driver.allowFirstRequest.complete();
      await flushed;

      expect(driver.requests, <String>[
        'api_trace_mark:first',
        'api_traces_since:0',
        'api_trace_mark:second',
        'api_traces_since:0',
        'api_traces_since:0',
      ]);
    },
  );

  test('flush delivers a coalesced final trace notification', () async {
    final driver = _TelemetryDriver(includeTrace: true)
      ..allowFirstRequest.complete();
    final updates = <int>[];
    final dispatcher = TelemetryDispatcher(
      driver: driver,
      collector: ApiTraceCollector(
        notificationBatchWindow: const Duration(days: 1),
        onTracesCaptured: (traces) => updates.add(traces.length),
      ),
    );

    dispatcher.captureStep('checkout');
    await dispatcher.flush();

    expect(updates, <int>[1]);
  });
}
