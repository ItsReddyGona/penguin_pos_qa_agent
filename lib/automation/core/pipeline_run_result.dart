/// Encapsulates generic execution results for an automation block pipeline run.
class PipelineRunResult {
  const PipelineRunResult({
    required this.passed,
    required this.startedAt,
    required this.finishedAt,
    this.scenariosExecuted = const <String>[],
    this.vmServiceUri,
    this.error,
    this.cleanupPassed,
    this.cleanupDetail,
    this.wasAppClosedByUser = false,
    this.metadata = const <String, Object?>{},
  });

  final bool passed;
  final DateTime startedAt;
  final DateTime finishedAt;
  final List<String> scenariosExecuted;
  final Uri? vmServiceUri;
  final String? error;

  /// Post-pipeline session cleanup is tracked independently so scenario results
  /// remain truthful even when the test environment could not be reset.
  final bool? cleanupPassed;
  final String? cleanupDetail;
  final bool wasAppClosedByUser;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => <String, Object?>{
    'passed': passed,
    'scenariosExecuted': scenariosExecuted,
    'wasAppClosedByUser': wasAppClosedByUser,
    if (metadata.isNotEmpty) 'metadata': metadata,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'finishedAt': finishedAt.toUtc().toIso8601String(),
    if (vmServiceUri != null) 'vmServiceUri': vmServiceUri.toString(),
    if (error != null) 'error': error,
    if (cleanupPassed != null) 'cleanupPassed': cleanupPassed,
    if (cleanupDetail != null) 'cleanupDetail': cleanupDetail,
  };
}
