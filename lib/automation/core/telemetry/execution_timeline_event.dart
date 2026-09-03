/// Workflow that owns an execution-timeline event.
enum ExecutionWorkflow { login, order }

/// Lifecycle state for one deterministic automation step.
enum ExecutionTimelineStatus { pending, running, passed, failed, skipped }

/// A UI-neutral execution fact suitable for a dynamic chat timeline.
///
/// It deliberately contains only safe, already-redacted display text. API
/// evidence belongs to [ApiTraceEvent] and is associated by [stepId].
class ExecutionTimelineEvent {
  final String stepId;
  final ExecutionWorkflow workflow;
  final ExecutionTimelineStatus status;
  final String title;
  final String detail;
  final int startedAtMs;
  final int? finishedAtMs;

  const ExecutionTimelineEvent({
    required this.stepId,
    required this.workflow,
    required this.status,
    required this.title,
    this.detail = '',
    required this.startedAtMs,
    this.finishedAtMs,
  });

  int? get durationMs => finishedAtMs == null
      ? null
      : (finishedAtMs! - startedAtMs).clamp(0, 1 << 31);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'stepId': stepId,
    'workflow': workflow.name,
    'status': status.name,
    'title': title,
    'detail': detail,
    'startedAtMs': startedAtMs,
    'finishedAtMs': finishedAtMs,
    'durationMs': durationMs,
  };

  factory ExecutionTimelineEvent.fromJson(Map<String, dynamic> json) {
    final startedAtMs = _asInt(json['startedAtMs']);
    return ExecutionTimelineEvent(
      stepId: _asText(json['stepId'], fallback: 'unknown_step'),
      workflow: _workflowFromWire(json['workflow']),
      status: _statusFromWire(json['status']),
      title: _asText(json['title'], fallback: 'Automation step'),
      detail: _asText(json['detail'], fallback: ''),
      startedAtMs: startedAtMs,
      finishedAtMs: json['finishedAtMs'] == null
          ? null
          : _asInt(json['finishedAtMs']),
    );
  }

  static int _asInt(Object? value) =>
      value is int ? value : int.tryParse('$value') ?? 0;

  static String _asText(Object? value, {required String fallback}) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? fallback : text;
  }

  static ExecutionWorkflow _workflowFromWire(Object? value) =>
      '$value'.toLowerCase() == 'order'
      ? ExecutionWorkflow.order
      : ExecutionWorkflow.login;

  static ExecutionTimelineStatus _statusFromWire(Object? value) =>
      switch ('$value'.toLowerCase()) {
        'pending' => ExecutionTimelineStatus.pending,
        'running' => ExecutionTimelineStatus.running,
        'passed' || 'success' => ExecutionTimelineStatus.passed,
        'failed' || 'error' => ExecutionTimelineStatus.failed,
        'skipped' => ExecutionTimelineStatus.skipped,
        _ => ExecutionTimelineStatus.pending,
      };
}
