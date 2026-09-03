import 'package:penguin_pos_qa_agent/automation/login/login_runner.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_scenario.dart';
import 'package:penguin_pos_qa_agent/runtime/qa_session_manager.dart';
import 'package:penguin_pos_qa_agent/interfaces/mcp/mcp_feature_tool.dart';
import 'package:penguin_pos_qa_agent/interfaces/mcp/mcp_tool_definition.dart';
import 'package:penguin_pos_qa_agent/interfaces/mcp/mcp_tool_result.dart';

/// Starts a reusable PenguinPOS QA session. It contains no credentials.
class StartLoginQaSessionTool implements McpFeatureTool {
  StartLoginQaSessionTool({required QaSessionManager sessions})
    : _sessions = sessions;
  final QaSessionManager _sessions;

  @override
  McpToolDefinition get definition => const McpToolDefinition(
    name: 'penguin_pos_start_qa_session',
    description:
        'Start or attach to one QA-enabled PenguinPOS app. Reuse the returned qa_session_id for login and later feature tests. Defaults to the trusted ibo-stage profile.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'additionalProperties': false,
      'properties': <String, Object?>{
        'profile': <String, Object?>{
          'type': 'string',
          'enum': <String>[
            'ibo-stage',
            'ibo-dev',
            'kpn-stage',
            'savomart-stage',
          ],
          'default': 'ibo-stage',
        },
        'vm_service_uri': <String, Object?>{'type': 'string'},
        'app_root': <String, Object?>{'type': 'string'},
        'device': <String, Object?>{'type': 'string'},
      },
    },
    outputSchema: <String, Object?>{
      'type': 'object',
      'required': <String>['qa_session_id', 'vm_service_uri', 'profile'],
    },
  );

  @override
  Future<McpToolResult> execute(Map<String, Object?> arguments) async {
    try {
      final session = await _sessions.start(
        profileName: arguments['profile'] as String?,
        vmServiceUri: arguments['vm_service_uri'] as String?,
        appRoot: arguments['app_root'] as String?,
        device: arguments['device'] as String?,
      );
      return McpToolResult.success(<String, Object?>{
        'qa_session_id': session.id,
        'vm_service_uri': session.vmServiceUri.toString(),
        'profile': session.profile.name,
      });
    } catch (error) {
      return McpToolResult.failure(error.toString());
    }
  }
}

/// Logs into an already running QA session through stable Flutter widget keys.
class LoginFeatureTool implements McpFeatureTool {
  LoginFeatureTool({
    required PenguinPosLoginRunner runner,
    required QaSessionManager sessions,
  }) : _runner = runner,
       _sessions = sessions;
  final PenguinPosLoginRunner _runner;
  final QaSessionManager _sessions;

  @override
  McpToolDefinition get definition => const McpToolDefinition(
    name: 'penguin_pos_login',
    description:
        'Executes login test scenarios (empty login, invalid credentials, valid login), handles terminal selection continue button, and verifies navigation into home screen.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'additionalProperties': false,
      'required': <String>['qa_session_id', 'login_id', 'password'],
      'properties': <String, Object?>{
        'qa_session_id': <String, Object?>{'type': 'string'},
        'login_id': <String, Object?>{
          'type': 'string',
          'description': '10-digit test login ID.',
        },
        'password': <String, Object?>{
          'type': 'string',
          'description': 'Test password. Never returned.',
        },
        'unlock_pin': <String, Object?>{
          'type': 'string',
          'description':
              'Terminal idle-lock PIN. Required only when the attached app opens with an active idle lock. Never returned.',
        },
        'check_all_scenarios': <String, Object?>{
          'type': 'boolean',
          'default': true,
          'description':
              'Run empty login click, invalid credentials attempt, then valid login sequence.',
        },
      },
    },
  );

  @override
  Future<McpToolResult> execute(Map<String, Object?> arguments) async {
    final loginId = arguments['login_id'] as String;
    if (!RegExp(r'^\d{10}$').hasMatch(loginId)) {
      return const McpToolResult.failure(
        'login_id must contain exactly 10 digits.',
      );
    }

    final checkAllScenarios =
        (arguments['check_all_scenarios'] as bool?) ?? true;

    try {
      final session = _sessions.requireSession(
        arguments['qa_session_id'] as String,
      );
      final scenario = LoginScenario(
        id: 'valid_login',
        name: 'Valid PenguinPOS login',
        loginId: loginId,
        password: arguments['password'] as String,
        unlockPin: arguments['unlock_pin'] as String?,
      );

      final result = checkAllScenarios
          ? await _runner.runFullSequence(
              scenario,
              vmServiceUri: session.vmServiceUri,
            )
          : await _runner.run(scenario, vmServiceUri: session.vmServiceUri);

      if (!result.passed) {
        return McpToolResult.failure(
          'Login verification failed: ${result.error ?? 'Home screen navigation contract was not fulfilled.'}',
        );
      }
      return McpToolResult.success(<String, Object?>{
        'passed': true,
        'scenarios_executed': result.scenariosExecuted,
        'qa_session_id': session.id,
        'started_at': result.startedAt.toUtc().toIso8601String(),
        'finished_at': result.finishedAt.toUtc().toIso8601String(),
      });
    } catch (error) {
      return McpToolResult.failure(error.toString());
    }
  }
}

/// Stops a QA session and its app process when this server started it.
class StopQaSessionTool implements McpFeatureTool {
  StopQaSessionTool({required QaSessionManager sessions})
    : _sessions = sessions;
  final QaSessionManager _sessions;

  @override
  McpToolDefinition get definition => const McpToolDefinition(
    name: 'penguin_pos_stop_qa_session',
    description:
        'Close a QA session. It stops the app only when this agent launched it.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'additionalProperties': false,
      'required': <String>['qa_session_id'],
      'properties': <String, Object?>{
        'qa_session_id': <String, Object?>{'type': 'string'},
      },
    },
  );

  @override
  Future<McpToolResult> execute(Map<String, Object?> arguments) async {
    final stopped = await _sessions.stop(arguments['qa_session_id'] as String);
    return McpToolResult.success(<String, Object?>{'stopped': stopped});
  }
}
