import 'dart:convert';
import 'dart:io';

import 'package:penguin_pos_qa_agent/interfaces/mcp/mcp_feature_tool.dart';
import 'package:penguin_pos_qa_agent/interfaces/mcp/mcp_input_validator.dart';
import 'package:penguin_pos_qa_agent/interfaces/mcp/mcp_tool_result.dart';

/// Stdio JSON-RPC MCP Server implementation.
class PenguinPosMcpServer {
  PenguinPosMcpServer({
    required List<McpFeatureTool> tools,
    McpInputValidator? validator,
  }) : _tools = <String, McpFeatureTool>{
         for (final tool in tools) tool.definition.name: tool,
       },
       _validator = validator ?? McpInputValidator();

  final Map<String, McpFeatureTool> _tools;
  final McpInputValidator _validator;

  Future<void> listenStdio() async {
    final lines = stdin.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        final raw = jsonDecode(line);
        if (raw is! Map<String, Object?>) continue;
        final response = await handleRequest(raw);
        if (response != null) {
          stdout.writeln(jsonEncode(response));
        }
      } catch (error) {
        stderr.writeln('MCP JSON parse error: $error');
      }
    }
  }

  Future<Map<String, Object?>?> handleRequest(Map<String, Object?> json) async {
    final id = json['id'];
    final method = json['method'] as String?;
    if (method == null) return _errorResponse(id, -32600, 'Invalid Request');

    switch (method) {
      case 'initialize':
        return <String, Object?>{
          'jsonrpc': '2.0',
          'id': id,
          'result': <String, Object?>{
            'protocolVersion': '2024-11-05',
            'capabilities': <String, Object?>{'tools': <String, Object?>{}},
            'serverInfo': <String, Object?>{
              'name': 'penguin-pos-qa',
              'version': '0.1.0',
            },
          },
        };
      case 'tools/list':
        return <String, Object?>{
          'jsonrpc': '2.0',
          'id': id,
          'result': <String, Object?>{
            'tools': _tools.values.map((t) => t.definition.toJson()).toList(),
          },
        };
      case 'tools/call':
        final params = json['params'] as Map<String, Object?>?;
        final name = params?['name'] as String?;
        final arguments =
            (params?['arguments'] as Map<String, Object?>?) ??
            <String, Object?>{};

        final tool = _tools[name];
        if (tool == null) {
          return _errorResponse(id, -32601, 'Tool not found: $name');
        }

        final missing = _validator.validate(
          definition: tool.definition,
          arguments: arguments,
        );
        if (missing.isNotEmpty) {
          return <String, Object?>{
            'jsonrpc': '2.0',
            'id': id,
            'result': McpToolResult.failure(
              'Missing required arguments: ${missing.join(", ")}',
            ).toJson(),
          };
        }

        final result = await tool.execute(arguments);
        return <String, Object?>{
          'jsonrpc': '2.0',
          'id': id,
          'result': result.toJson(),
        };
      default:
        return _errorResponse(id, -32601, 'Method not found');
    }
  }

  Map<String, Object?> _errorResponse(Object? id, int code, String message) =>
      <String, Object?>{
        'jsonrpc': '2.0',
        'id': id,
        'error': <String, Object?>{'code': code, 'message': message},
      };
}
