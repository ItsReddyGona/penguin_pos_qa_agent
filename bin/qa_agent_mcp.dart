import 'package:penguin_pos_qa_agent/qa_agent.dart';

/// Entrypoint for the MCP stdio server.
Future<void> main() async {
  final sessions = QaSessionManager(launcher: PenguinPosAppLauncher());
  final server = PenguinPosMcpServer(
    tools: <McpFeatureTool>[
      StartLoginQaSessionTool(sessions: sessions),
      LoginFeatureTool(runner: PenguinPosLoginRunner(), sessions: sessions),
      StopQaSessionTool(sessions: sessions),
    ],
  );
  await server.listenStdio();
}
