/// Encapsulates execution output from an MCP tool call.
class McpToolResult {
  const McpToolResult.success(this.data) : isError = false, error = null;
  const McpToolResult.failure(this.error) : isError = true, data = null;

  final bool isError;
  final Map<String, Object?>? data;
  final String? error;

  Map<String, Object?> toJson() => <String, Object?>{
    'isError': isError,
    if (data != null)
      'content': <Object?>[
        <String, Object?>{'type': 'json', 'json': data},
      ],
    if (error != null) 'error': error,
  };
}
