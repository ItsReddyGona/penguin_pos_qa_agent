import 'package:penguin_pos_qa_agent/interfaces/mcp/mcp_tool_definition.dart';
import 'package:penguin_pos_qa_agent/interfaces/mcp/mcp_tool_result.dart';

/// Standard interface for MCP feature tools.
abstract interface class McpFeatureTool {
  McpToolDefinition get definition;
  Future<McpToolResult> execute(Map<String, Object?> arguments);
}
