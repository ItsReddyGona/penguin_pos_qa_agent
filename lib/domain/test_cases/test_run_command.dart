/// A portable, JSON-serializable request to execute one configured test case.
class TestRunCommand {
  const TestRunCommand({
    required this.testCaseId,
    required this.profileId,
    this.inputs = const <String, Object?>{},
    this.metadata = const <String, Object?>{},
  });

  final String testCaseId;
  final String profileId;
  final Map<String, Object?> inputs;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => <String, Object?>{
    'testCaseId': testCaseId,
    'profileId': profileId,
    'inputs': inputs,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };

  factory TestRunCommand.fromJson(Map<String, Object?> json) => TestRunCommand(
    testCaseId: (json['testCaseId'] as String?) ?? '',
    profileId: (json['profileId'] as String?) ?? '',
    inputs:
        (json['inputs'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{},
    metadata:
        (json['metadata'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{},
  );
}
