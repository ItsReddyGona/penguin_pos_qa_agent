library;

// ── Automation Engine: Test Runners & Key Contracts ──────────────────────────
export 'automation/login/login_keys.dart';
export 'automation/login/login_runner.dart';
export 'automation/login/login_scenario.dart';

// ── Runtime: Driver Engine & Session Manager ─────────────────────────────────
export 'runtime/app_launcher.dart';
export 'runtime/driver_engine.dart';
export 'runtime/qa_profile_config.dart';
export 'runtime/qa_session_manager.dart';

// ── Interfaces: CLI Adapter ──────────────────────────────────────────────────
export 'interfaces/cli/login_cli_handler.dart';

// ── Interfaces: MCP Server & Tool Adapters ───────────────────────────────────
export 'interfaces/mcp/mcp_feature_tool.dart';
export 'interfaces/mcp/mcp_input_validator.dart';
export 'interfaces/mcp/mcp_server.dart';
export 'interfaces/mcp/mcp_tool_definition.dart';
export 'interfaces/mcp/mcp_tool_result.dart';
export 'interfaces/mcp/tools/login_mcp_tool.dart';

// ── Interfaces: Desktop GUI App ──────────────────────────────────────────────
export 'interfaces/gui/qa_agent_dashboard.dart';
