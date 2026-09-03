/// Represents an MCP tool declaration with JSON Schema arguments.
class McpToolDefinition {
  const McpToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
    this.outputSchema,
  });

  final String name;
  final String description;
  final Map<String, Object?> inputSchema;
  final Map<String, Object?>? outputSchema;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'description': description,
    'inputSchema': inputSchema,
    if (outputSchema != null) 'outputSchema': outputSchema,
  };
}
