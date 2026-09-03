# PenguinPOS QA Agent

PenguinPOS QA Agent is a Flutter desktop application for planning and running
repeatable QA checks against configured PenguinPOS **non-production** targets.
It combines deterministic Flutter Driver automation with a constrained
plain-language assistant. The assistant prepares structured plans; the QA
application remains responsible for validation and execution.

## Safety first

- Production and live targets are never executable from the assistant.
- A target must resolve to a configured, approved non-production profile before
  a validated plan can run.
- Credentials and PINs are entered through the secure settings flow. They are
  never requested, echoed, or stored in chat messages.
- Model output is treated as untrusted input. It is decoded, normalised, and
  validated before it can become an automation scenario.
- The assistant displays user-safe lifecycle details, not private model
  reasoning, prompts, or hidden instructions.

## What the assistant supports today

| Workflow | Plain-language examples | Required details |
| --- | --- | --- |
| Login and terminal checks | `test the login flow in kpn dev` | A configured non-production profile; credentials must already be configured securely. |
| Cash order checks | `create two orders in kpn stage: SKU 22, non-weighed, manual` | Target profile, SKU(s), item type, and entry method. Weighed items also require a positive weight. |
| Repeat a previous order | `repeat the previous order in kpn dev` | An earlier user message in the same chat containing valid item details. |

The assistant also answers read-only QA questions directly from the configured
suite catalogue. These never launch PenguinPOS:

```text
Explain the login flow.
What is the current order flow?
What test cases can I run in KPN Stage?
Explain /login.
```

Slash commands work inside a normal sentence. Choose a suggestion to insert it
at the cursor; selecting a suggestion does not send or run anything.

For multiple orders, state whether every order uses the same items or give the
items for each order. The assistant does not silently choose a SKU, item type,
weight, or entry method from an example or from unrelated chat history.

Examples of clear order requests:

```text
Create one order in kpn stage with SKU 22, non-weighed, manual entry.
Create two orders in kpn dev: order 1 has SKU 22, non-weighed, manual;
order 2 has SKU 10000001, weighed, 1.763 kg, scan.
Repeat the previous order in kpn dev.
```

If a request is incomplete or ambiguous, the assistant asks for the missing
information instead of executing. Unknown, disabled, or production targets are
also stopped with an explanation.

## Chat and execution experience

The chat is the primary workspace:

1. Read-only questions are answered from the QA catalogue without a model or
   app launch.
2. For an execution request, the assistant parses the request and resolves the
   configured profile.
3. It validates the structured plan and shows a live preflight: profile,
   non-production guard, credentials, suite readiness, and local launch setup.
4. Only a passing preflight launches an approved non-production target.
5. The chat receives a compact result card; order suites show one result for
   every requested order plus the checks applied to each order.

Every assistant response may include a collapsed **Activity details** panel.
It contains safe milestones such as “Parsing request”, “Matching target
profile”, and “Validating plan”. It deliberately excludes raw model
chain-of-thought, private reasoning, prompts, secrets, and driver commands.
The bottom execution log is a secondary diagnostic view, not the main way to
understand a run.

Read-only catalogue answers are intentionally paced through their real lookup
stages, then reveal the matching suite details line by line. Login and order
flow explanations also include native, Mermaid-style flow charts built from
the configured test cases. The app accepts only declarative diagram nodes;
untrusted Mermaid, HTML, SVG, and JavaScript are never rendered.

## Architecture

The project is structured by responsibility so GUI, planning, and driver code
remain independent:

```text
lib/
  ai/                 Constrained planning, model providers, plan contracts
  automation/         Deterministic login and order driver scenarios
  core/               Scenario models, results, parsing, and reporting
  interfaces/
    gui/              Desktop UI, assistant chat, settings, and suite screens
    cli/              Command-line adapter
    mcp/              MCP adapter and request validation
  runtime/            App launcher, driver engine, profiles, and sessions
scenarios/            Declarative YAML scenarios
test/                 Unit, contract, orchestration, and widget tests
```

Useful entry points:

- `lib/main.dart` starts the desktop application.
- `lib/ai/orchestration/ai_orchestrator.dart` turns a user request into a
  validated plan without executing driver commands itself.
- `lib/interfaces/gui/dashboard/screens/assistant/` owns the chat UI and its
  rich execution-report cards.
- `lib/automation/` owns deterministic interaction with PenguinPOS.
- `lib/runtime/ssh/` owns remote Flutter machine-protocol sessions, preflight,
  and local VM Service port forwarding.

## Running locally

Install Flutter and project dependencies, then run:

```sh
flutter pub get
flutter run
```

Run the test suite with:

```sh
flutter test
```

Before submitting a change, format the entire repository and run the quality
checks from the project root:

```sh
dart format .
flutter analyze
flutter test
```

The CLI and MCP adapters prompt for required values that have not been supplied
instead of relying on embedded credentials or target settings.

## Remote Linux execution

SSH mode keeps the QA Agent and its results on macOS while PenguinPOS runs in
the selected Linux desktop session. SSH settings are saved per QA profile and
include the host, port, username, authentication method, remote app root, and
remote Flutter executable.

The runtime performs a launch-readiness preflight, then starts Flutter's built-in
machine protocol through SSH and forwards only the VM Service port to localhost.
The existing login, order, stop, disconnect, and result flows use the same
execution coordinator for local and remote targets.

Linux requires PenguinPOS source with packages resolved, a compatible Flutter
SDK, Linux desktop build dependencies, an active graphical login for the SSH
user, and SSH access from the Mac. It does not require a QA helper binary or a
separate `setsid` installation.

Use **Test SSH Connection** before running a suite. It verifies SSH
authentication, the remote app root, the Flutter executable, and the Linux
graphical session. Passwords stay in the credential vault and are never placed
in command arguments, protocol messages, logs, or results. SSH identity files
are preferred for unattended runs.

## PenguinPOS application contract

The external driver requires debug-only Flutter Driver support and stable widget
keys in the PenguinPOS application. PenguinPOS should enable the driver only
when explicitly requested by a debug or QA build:

```dart
if (const bool.fromEnvironment('ENABLE_FLUTTER_DRIVER')) {
  enableFlutterDriverExtension();
}
```

The login and terminal keys are `login.id`, `login.password`,
`login.submit`, and `login.terminal.continue`. Order and payment automation
uses the `order.*` and `payment.*` keys defined in
`lib/automation/order/order_keys.dart`, including stable success and error
states. Renaming or removing a key is a breaking QA contract change and must
be updated together with the agent tests.

PenguinPOS remains the source of truth for catalog data, prices, taxes,
payments, stock, and order completion. New workflows require stable widget
keys, approved non-production data, reset behaviour, and deterministic success,
error, and retry conditions before they become executable.

## Contributing

- Keep Flutter GUI code feature-oriented and use package imports within `lib/`.
- Keep model plans and driver actions separate: planning must not bypass runtime
  safety checks.
- Add tests with behaviour changes, particularly for target safety, malformed
  model output, missing input, and rich execution reporting.
- Run `dart format .` from the repository root before analysis or tests. Do
  not format only a hand-picked list of files.
- Do not add credentials, PINs, or production target defaults to source, tests,
  documentation, or chat examples.
