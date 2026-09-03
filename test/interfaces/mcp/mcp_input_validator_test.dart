import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/qa_agent.dart';

void main() {
  const definition = McpToolDefinition(
    name: 'test_tool',
    description: 'Test tool',
    inputSchema: <String, Object?>{
      'type': 'object',
      'additionalProperties': false,
      'required': <String>['qa_session_id', 'login_id', 'password'],
      'properties': <String, Object?>{
        'qa_session_id': <String, Object?>{'type': 'string'},
        'login_id': <String, Object?>{'type': 'string'},
        'password': <String, Object?>{'type': 'string'},
      },
    },
  );

  final validator = McpInputValidator();

  test('reports only absent required fields', () {
    final missing = validator.validate(
      definition: definition,
      arguments: <String, Object?>{'qa_session_id': 'abc'},
    );
    expect(missing, containsAll(<String>['login_id', 'password']));
  });

  test('accepts complete tool input', () {
    final missing = validator.validate(
      definition: definition,
      arguments: <String, Object?>{
        'qa_session_id': 'abc',
        'login_id': '1234567890',
        'password': 'secret',
      },
    );
    expect(missing, isEmpty);
  });
}
