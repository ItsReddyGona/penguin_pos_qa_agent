import 'package:penguin_pos_qa_agent/interfaces/mcp/mcp_tool_definition.dart';

/// Validates provided tool arguments against a tool's JSON Schema definition.
class McpInputValidator {
  List<String> validate({
    required McpToolDefinition definition,
    required Map<String, Object?> arguments,
  }) {
    final missing = <String>[];
    final schema = definition.inputSchema;
    final rawRequired = schema['required'];
    if (rawRequired is! List) return missing;

    for (final item in rawRequired) {
      if (item is! String) continue;
      final value = arguments[item];
      if (value == null || (value is String && value.trim().isEmpty)) {
        missing.add(item);
      }
    }
    return missing;
  }
}
