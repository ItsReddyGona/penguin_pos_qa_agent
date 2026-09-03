import 'dart:async';

enum ExecutionCancellationReason { userRequested, targetUnavailable }

class ExecutionCancelledException implements Exception {
  const ExecutionCancelledException(this.reason, this.message);

  final ExecutionCancellationReason reason;
  final String message;

  @override
  String toString() => message;
}

/// One idempotent cancellation signal shared by an entire QA execution.
class ExecutionCancellationSignal {
  final Completer<ExecutionCancelledException> _cancelled =
      Completer<ExecutionCancelledException>();

  bool get isCancelled => _cancelled.isCompleted;

  ExecutionCancelledException? _exception;

  ExecutionCancelledException? get exception => _exception;

  Future<ExecutionCancelledException> get whenCancelled => _cancelled.future;

  void cancel(ExecutionCancellationReason reason, String message) {
    if (isCancelled) return;
    final exception = ExecutionCancelledException(reason, message);
    _exception = exception;
    _cancelled.complete(exception);
  }

  void throwIfCancelled() {
    final cancellation = _exception;
    if (cancellation != null) throw cancellation;
  }

  Future<T> race<T>(Future<T> operation) {
    throwIfCancelled();
    return Future.any<T>(<Future<T>>[
      operation,
      whenCancelled.then<T>((exception) => throw exception),
    ]);
  }

  Future<T> run<T>(Future<T> Function() body) => runZoned<Future<T>>(
    body,
    zoneValues: <Object?, Object?>{_executionCancellationZoneKey: this},
  );
}

final Object _executionCancellationZoneKey = Object();

abstract final class ExecutionCancellationScope {
  static ExecutionCancellationSignal? get current =>
      Zone.current[_executionCancellationZoneKey]
          as ExecutionCancellationSignal?;
}
