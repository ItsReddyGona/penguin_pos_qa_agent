/// Lifecycle states emitted by a running PenguinPOS target.
enum AppTargetLifecycleState {
  starting,
  ready,
  stopping,
  stopped,
  exited,
  disconnected,
  failed,
}

/// A lifecycle notification for a local or remote PenguinPOS target.
class AppTargetLifecycleEvent {
  const AppTargetLifecycleEvent(this.state, {this.message, this.exitCode});

  final AppTargetLifecycleState state;
  final String? message;
  final int? exitCode;

  @override
  String toString() {
    final details = <String>[
      state.name,
      ?message,
      if (exitCode != null) 'exitCode=$exitCode',
    ];
    return 'AppTargetLifecycleEvent(${details.join(', ')})';
  }
}

/// A handle to the running target used by QA automation.
///
/// The VM Service URI must be reachable from the QA Agent process. A remote
/// implementation therefore returns an SSH-forwarded URI rather than the
/// target machine's private URI.
abstract interface class AppTargetHandle {
  Uri get vmServiceUri;

  Map<String, Object?> get metadata;

  Stream<AppTargetLifecycleEvent> get lifecycleEvents;

  /// Compatibility alias for callers that treat lifecycle as target health.
  Stream<AppTargetLifecycleEvent> get healthEvents => lifecycleEvents;

  bool get isClosed;

  Future<void> close();
}
