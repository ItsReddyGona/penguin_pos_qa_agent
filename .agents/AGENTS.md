# AGENTS Rules & Guidelines

- **No Hardcoded Credentials or Inputs**: NEVER hardcode default usernames, login IDs, passwords, entity names, environment names, or test payload values in generated CLI commands or UI code unless the user explicitly provides them in their prompt.
- **Dynamic Parameter Passing**: Only pass CLI flags and configuration values for parameters explicitly provided by the user in their prompt or auto-detected by system tools.
- **Interactive Prompt Fallback**: If a required parameter (e.g. `--login-id`, `--password`, `--entity`, `--env`, or future feature inputs) is missing from the user's prompt, omit that flag. The CLI runner will interactively prompt the user for missing inputs via standard input (`stdin`) at execution time.
- **Universal Feature Scope**: This rule applies to `login` and all upcoming feature modules (e.g. Checkout, Inventory, Terminal, Orders, Payments, etc.).
- **Always Use Package Imports**: ALWAYS use absolute package imports (e.g., `import 'package:penguin_pos_qa_agent/...'`) for project files inside `lib/` instead of relative imports (e.g., `import '../../...'`).
- **Repository Formatting**: Before verification, run `dart format .` from the project root so every Dart file follows the same formatter output. Do not run `dart format` only on a hand-picked file list unless a full repository format is impossible.
- **Modular GUI Architecture**: Keep the Flutter Desktop GUI modular and separated by features:
  - `lib/interfaces/gui/onboarding/`: Setup wizard and onboarding screens.
  - `lib/interfaces/gui/dashboard/`: Dashboard shell, models, repositories, and widgets (`side_nav.dart`, `qa_panel.dart`, `qa_activity_panel.dart`).
  - `lib/interfaces/gui/dashboard/screens/`: Feature test suite screens (e.g. `login/login_suite_screen.dart`).
- **Dynamic Path Auto-Detection**: Do not hardcode Flutter SDK or PenguinPOS app root paths. Always use `PathDetector` auto-detection with fallback for user selection.
- **Direct SSH Runtime**: Remote Linux execution uses Flutter's built-in machine protocol over OpenSSH and the existing `AppTargetHandle` abstraction. Do not add or restore a `penguin_pos_qa_helper` binary, helper protocol, or Linux `setsid` installation dependency.
- **SSH Configuration Safety**: Keep SSH settings profile-scoped. Resolve passwords through the credential vault at runtime; never place them in source, command arguments, protocol messages, logs, metadata, or test fixtures. Prefer identity files for unattended execution.

## Current repository context

- This is a Flutter desktop QA runner for PenguinPOS. Manual and AI modes share the same configured profiles, credentials, login cases, order cases, and execution pipelines.
- Local and remote execution share the same coordinator and result model. SSH mode runs PenguinPOS on Linux through an SSH-launched Flutter machine session and a localhost VM Service port forward; the QA Agent UI remains on macOS.
- SSH preflight must verify SSH authentication, the remote PenguinPOS app root, the configured Flutter executable, and an active Linux graphical session before launch. Process exit, tunnel failure, app quit, and user stop must update target lifecycle state promptly.
- Settings are the source of truth for reusable inputs. Login cases are profile-scoped and include case ID, title, description, username, password, expected result, and enabled state. Order settings support common payloads and custom per-iteration payloads, including SKU code, item type, entry mode, weight mode/value, order count, and login-case reference.
- AI natural-language requests are converted into the existing domain plan/models, then validated by guardrails and hydrated from Settings when the request uses the Settings source. Explicit user-provided order items remain authoritative. Do not create a parallel schema; preserve existing camelCase/domain enum values such as `skuCode`, `entryMode`, `nonWeighed`, and `manualNumpad`.
- AI preview and manual output should represent the same effective execution data: order count, allocation mode, SKU rows, entry mode, item type, weight mode, pass/fail status, and failure reason. Credentials must never be rendered in output or logs.
- Auto-weight execution is user/peripheral-driven: after scanning an auto-weight item, the runner observes the POS transition back to the code-input state and must not invent or submit a weight. Manual weight mode requires user-entered positive weight and should report a clear timeout/error when it is absent.
- Login execution must preserve the state decision flow: detect login/terminal/home/order state, log out an existing authenticated session when needed, execute configured cases in order, complete terminal selection and home verification for a successful login, then cleanly log out/finish.
- Current AI orchestration and preview work is centered in `lib/ai/`, `lib/interfaces/gui/dashboard/screens/assistant/`, and `lib/interfaces/gui/dashboard/screens/qa_dashboard_screen.dart`; automation blocks live under `lib/automation/` and settings persistence/repositories under the dashboard/settings and repository folders.
- Before handing off changes, run `dart format .`, `flutter analyze`, targeted tests, and then `flutter test` when practical. Do not commit unless the user explicitly authorizes a commit.
