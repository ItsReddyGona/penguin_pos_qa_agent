import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/api_trace_event.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/execution_timeline_event.dart';

void main() {
  group('ApiTraceEvent', () {
    test('normalizes transport metadata and strips route query data', () {
      final trace = ApiTraceEvent.fromJson(<String, dynamic>{
        'traceId': '7',
        'stepId': 'valid_login',
        'method': 'post',
        'route': 'https://api.example.test/auth/login?token=do-not-show',
        'statusCode': '200',
        'result': 'success',
        'transport': 'HTTPS',
        'mode': 'cloud',
        'sanitizedPreview': ' ok ',
      });

      expect(trace.traceId, 7);
      expect(trace.method, 'POST');
      expect(trace.route, '/auth/login');
      expect(trace.statusCode, 200);
      expect(trace.transport, ApiTransport.https);
      expect(trace.mode, ApiTraceMode.cloud);
      expect(trace.sanitizedPreview, 'ok');
    });

    test('maps Dio timeout names and unsupported metadata safely', () {
      final trace = ApiTraceEvent.fromJson(<String, dynamic>{
        'result': 'connectionTimeout',
        'transport': 'ws',
        'mode': 'staging',
      });

      expect(trace.result, ApiTraceResult.connectTimeout);
      expect(trace.transport, ApiTransport.unknown);
      expect(trace.mode, ApiTraceMode.unknown);
      expect(trace.route, '/');
    });
  });

  group('ExecutionTimelineEvent', () {
    test('serializes completed step duration for a dynamic chat surface', () {
      const event = ExecutionTimelineEvent(
        stepId: 'terminal_selection',
        workflow: ExecutionWorkflow.login,
        status: ExecutionTimelineStatus.passed,
        title: 'Terminal selection',
        startedAtMs: 100,
        finishedAtMs: 375,
      );

      expect(event.durationMs, 275);
      expect(event.toJson()['durationMs'], 275);
    });
  });
}
