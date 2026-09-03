enum ExecutionEventLevel { info, success, error }

class ExecutionEvent {
  const ExecutionEvent({
    required this.title,
    required this.message,
    this.level = ExecutionEventLevel.info,
  });

  final String title;
  final String message;
  final ExecutionEventLevel level;
}
