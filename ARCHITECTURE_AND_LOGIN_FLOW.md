# PenguinPOS QA Agent: Architecture, Execution Modes & Login Flow Deep Dive

> **Document Version**: 1.0  
> **Audience**: Engineering Team / Onboarding Engineers  
> **Scope**: System Architecture, Manual vs. AI Execution Modes, End-to-End Login Flow Trace, and Login Test Case Implementation.

---

## 1. Executive Overview & System Architecture

### 1.1 Purpose of the System
**PenguinPOS QA Agent** is a Flutter desktop application (running primarily on macOS) engineered for repeatable, deterministic quality assurance against configured non-production PenguinPOS targets (running locally or remotely on Linux via SSH).

The system solves a critical testing challenge: testing a POS desktop system requires driving real UI components, handling asynchronous network calls, managing session lifecycles, and supporting both manual operator-driven testing and natural-language AI-driven testing—all without compromising safety or leaking sensitive credentials.

---

### 1.2 Architectural Layers & Clean Separation of Concerns

The codebase follows a clean, decoupled, layered architecture:

```text
lib/
├── ai/                 # Constrained planning, model providers, intent parsing, GenUI schemas
├── application/        # Application-level services, preflight guardrails, execution coordination
├── automation/         # Deterministic Flutter Driver execution, pipelines, atomic blocks, telemetry
│   ├── core/           # Pipeline engine, Driver abstraction, execution context, notices
│   ├── login/          # Login runner, keys, API barriers, atomic login automation blocks
│   └── order/          # Order runner, cart sync, cash round-off, order blocks
├── core/               # Shared utilities (e.g., secret redactor)
├── domain/             # Enterprise business models, repositories, test suites & cases
│   ├── plan/           # ExecutionPlan, item strategies, configurations
│   ├── profiles/       # Profiles, credentials vault, test case repositories
│   ├── suites/         # Suite definitions & registries
│   └── test_cases/     # Login & order test case definitions, results, schemas
├── interfaces/         # Entry adapters (GUI, CLI, MCP)
│   ├── cli/            # Interactive command-line interface
│   ├── gui/            # Flutter desktop UI (Dashboard, Assistant, Suites, Settings)
│   └── mcp/            # Model Context Protocol server & tool adapters
└── runtime/            # Process lifecycle & Flutter Driver integration
    ├── app_launcher.dart            # Local process launcher & VM Service detector
    ├── app_target_handle.dart       # Target lifecycle abstraction
    ├── driver_engine.dart           # FlutterDriver implementation with custom keyboard support
    └── ssh/                         # Remote Linux Flutter machine protocol & port forwarding
```

```text
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                INTERFACES & USER INGRESS LAYER                                   │
│                                                                                                  │
│   ┌───────────────────────────┐         ┌────────────────────────┐         ┌─────────────────┐   │
│   │    Manual Suite Screens   │         │  AI Assistant Workspace │         │   CLI / MCP     │   │
│   │  (login_suite_screen.dart)│         │(ai_assistant_workspace)│         │    Adapters     │   │
│   └─────────────┬─────────────┘         └───────────┬────────────┘         └────────┬────────┘   │
│                 │                                   │                               │            │
│                 │ (Manual Click: "Run Suite")       │ (Natural Language / Slash Cmd)│            │
│                 ▼                                   ▼                               ▼            │
│   ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│   │                         QA Dashboard Controller (qa_dashboard_screen.dart)               │   │
│   └──────────────────────────┬───────────────────────────┬───────────────────────────────────┘   │
└──────────────────────────────┼───────────────────────────┼───────────────────────────────────────┘
                               │                           │
          (Prompt / Slash Cmd) │                           │ (Execute Plan / Review in Manual)
                               ▼                           │
┌──────────────────────────────────────────────────────┐   │
│                 AI & INTENT LAYER                    │   │
│                                                      │   │
│   ┌──────────────────────────────────────────────┐   │   │
│   │       AiOrchestrator (ai_orchestrator.dart)  │   │   │
│   └──────────────────────┬───────────────────────┘   │   │
│                          │                           │   │
│          ┌───────────────┴───────────────┐           │   │
│          ▼                               ▼           │   │
│   ┌───────────────┐             ┌────────────────┐   │   │
│   │ OpenAiProvider│             │ Local Fallback │   │   │
│   │ (Remote LLM)  │             │ (Regex / Slash)│   │   │
│   └───────┬───────┘             └────────┬───────┘   │   │
│           └──────────────┬───────────────┘           │   │
│                          ▼                           │   │
│   ┌──────────────────────────────────────────────┐   │   │
│   │ Guardrails & Constraint Validation Filters   │   │   │
│   │ (Blocks prod targets, verifies schemas)      │   │   │
│   └──────────────────────┬───────────────────────┘   │   │
│                          ▼                           │   │
│        Validated ExecutionPlan Preview               │   │
└──────────────────────────┬───────────────────────────┘   │
                           │                               │
                           └────────────────┐              │
                                            ▼              ▼
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              APPLICATION & COORDINATION LAYER                                    │
│                                                                                                  │
│   ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│   │               PreflightService (preflight_service.dart) - SAFETY BOUNDARY                │   │
│   │  • Asserts Target != Production   • Asserts Credentials Present   • Asserts App Paths    │   │
│   └───────────────────────────────────────────┬──────────────────────────────────────────────┘   │
│                                               ▼                                                  │
│   ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│   │                   QaExecutionCoordinator (qa_execution_coordinator.dart)                 │   │
│   │         Owns process lifecycle, cancellation races, target health & result aggregation    │   │
│   └───────────────────────────┬─────────────────────────────────────────┬────────────────────┘   │
└───────────────────────────────┼─────────────────────────────────────────┼────────────────────────┘
                                │                                         │
        (1. Launch Target App)  ▼                                         ▼ (2. Execute Pipeline)
┌──────────────────────────────────────────────┐        ┌──────────────────────────────────────────┐
│              RUNTIME LAYER                   │        │           AUTOMATION ENGINE              │
│                                              │        │                                          │
│   ┌──────────────────────────────────────┐   │        │   ┌──────────────────────────────────┐   │
│   │ Target Launchers:                    │   │        │   │ PenguinPosLoginRunner            │   │
│   │ • Local: PenguinPosAppLauncher       │   │        │   │ • runConfiguredCases(...)        │   │
│   │ • Remote: SshRemoteAppLauncher (SSH) │   │        │   │ • runFullSequence(...)           │   │
│   └──────────────────┬───────────────────┘   │        │   └────────────────┬─────────────────┘   │
│                      ▼                       │        │                    ▼                     │
│   ┌──────────────────────────────────────┐   │        │   ┌──────────────────────────────────┐   │
│   │ AppTargetHandle (LaunchedPenguinPos) │   │        │   │ PipelineRunner                   │   │
│   │ Exposes VM Service URI & Exit stream │   │        │   │ (Orchestrates ordered blocks)    │   │
│   └──────────────────┬───────────────────┘   │        │   └────────────────┬─────────────────┘   │
│                      ▼                       │        │                    ▼                     │
│   ┌──────────────────────────────────────┐   │        │   ┌──────────────────────────────────┐   │
│   │ Flutter Driver Protocol Session      │   │◄───────┼───┤ DriverEngine (driver_engine.dart)│   │
│   │ (VM Service WebSocket: port 54321)   │   │        │   │ Taps, enters text, waits for keys│   │
│   └──────────────────┬───────────────────┘   │        │   └────────────────┬─────────────────┘   │
└──────────────────────┼───────────────────────┘        │                    │                     │
                       │                                │                    ▼                     │
                       │                                │   ┌──────────────────────────────────┐   │
                       │                                │   │ LoginApiCallBarrier              │   │
                       │                                │   │ Polls api_traces_since:$cursor   │   │
                       │                                │   │ Verifies HTTP 200 / 4xx result   │   │
                       │                                │   └──────────────────────────────────┘   │
                       ▼                                └──────────────────────────────────────────┘
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                 RUNNING PENGUINPOS APPLICATION                                   │
│  Widget Tree: login.id, login.password, login.submit, login.terminal.continue, home.screen       │
│  Internal QA Telemetry Bridge: /authn/api/v1/pos/login HTTP traces                               │
└──────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 1.3 Key Design Patterns Applied

1. **Pipeline Pattern (`AutomationPipeline`, `AutomationBlock`)**:
   Complex test scenarios are broken into discrete, single-responsibility atomic blocks (e.g., `EnsureLoggedOutBlock`, `PerformLoginBlock`, `SelectTerminalBlock`, `VerifyHomeScreenBlock`). Each block implements:
   ```dart
   abstract class AutomationBlock {
     String get id;
     String get name;
     StepNotice? get notice;
     Future<void> execute(ExecutionContext context);
   }
   ```
2. **Strategy Pattern (`AppTargetHandle`, `ExecutionLauncher`)**:
   Whether PenguinPOS is launched locally (`LaunchedPenguinPos`) or remotely via OpenSSH (`SshAppTargetHandle`), the execution coordinator interacts only with the abstract `AppTargetHandle` and standard VM Service URI.
3. **Repository Pattern (`QaLoginTestCaseRepository`, `QaCredentialVault`)**:
   Decouples metadata persistence (stored in JSON) from secret persistence (stored under independent, base64-encoded keys). Raw credentials never touch application metadata exports.
4. **API Call Barrier Pattern (`LoginApiCallBarrier`)**:
   Instead of relying on fragile UI sleep timers or static widget presence, the test runner queries application network telemetry over the VM Service bridge (`api_traces_since:$cursor`) to verify that the HTTP request `POST /authn/api/v1/pos/login` completed with the expected status code.

---

## 2. Manual Mode vs. AI Mode

Both modes share the **exact same target profiles, credentials vault, execution coordinator, driver pipeline, and result models**. The difference lies solely in **how the plan is formulated and presented**.

| Dimension | Manual Mode | AI Mode |
| :--- | :--- | :--- |
| **Primary Interface** | Dedicated feature screens (`LoginSuiteScreen`, `OrderSuiteScreen`) | Conversational chat canvas (`AiAssistantWorkspace`) |
| **Trigger Mechanism** | User clicks "Run Suite" on the dashboard/suite screen | User submits natural language (e.g. `test login in kpn dev`) or slash command (`/login /kpn-dev`) |
| **Planning Step** | Direct: builds `ExecutionPlan` from active UI state and saved Settings | Planner: `AiOrchestrator` parses intent via LLM or deterministic fallback |
| **Credential Handling** | Loaded dynamically from `QaCredentialVault` at runtime; never typed in plain text | Credentials are **never** shown to or requested by the model; hydrated from Settings post-planning |
| **Target Guardrails** | Verified by `PreflightService`; production profiles blocked | AI request strictly validated: production targets rejected, unknown targets rejected, missing params prompted |
| **Pre-run Inspection** | User inspects configured test case cards in the "Test cases" tab | Assistant renders an interactive `AssistantLaunchPreviewCard` showing preflight milestones |
| **Bridge Between Modes** | N/A | "Open in Manual Mode" button ports any AI plan directly into the editable manual suite UI |
| **Output Representation** | `LoginSuiteScreen` "Output" tab: pass/fail badges, duration, error details | Rich chat message: `AssistantLoginReportCard` with case table, status chips, and cleanup details |

### 2.1 The AI Planning Lifecycle
1. **Input Normalization**: In `AiOrchestrator.respond()`, input is inspected. If it contains an explicit login intent (e.g., `/login` or "test login"), local deterministic parsing handles it immediately without calling external APIs.
2. **Model Call (if configured)**: For dynamic or conversational requests, `OpenAiCompatibleProvider.completeJson()` asks the LLM to output a constrained JSON schema.
3. **Guardrails & Reconciliation**: Model JSON output is treated as untrusted. `_validate()` ensures:
   - Profile exists and is **not production**.
   - No credentials or secrets were hallucinated or demanded.
   - Referenced test case IDs exist and are enabled.
4. **Plan Preview**: The GUI displays `AssistantLaunchPreviewCard`. The test will **not** execute until the operator reviews the preflight card and clicks **"Run Now"**.

---

## 3. The Moment Login Flow is Executed: End-to-End Trace

Here is the exact, function-by-function trace of what occurs from the moment execution is triggered until final completion.

```text
USER / OPERATOR          GUI CONTROLLER         PREFLIGHT SERVICE      EXEC COORDINATOR        APP LAUNCHER        PENGUINPOS APP        LOGIN RUNNER        DRIVER ENGINE        API BARRIER
      │                        │                        │                     │                     │                    │                    │                     │                    │
 1.   │── Click "Run Suite" ──►│                        │                     │                     │                    │                    │                     │                    │
      │   or "Run Now" (AI)    │                        │                     │                     │                    │                    │                     │                    │
 2.   │                        │── Preflight.check() ──►│                     │                     │                    │                    │                     │                    │
 3.   │                        │◄─── Preflight Passed ──│                     │                     │                    │                    │                     │                    │
      │                        │     (Non-prod, creds, paths OK)              │                     │                    │                    │                     │                    │
 4.   │                        │──────────────── Coordinator.run() ──────────►│                     │                    │                    │                     │                    │
      │                        │                                              │                     │                    │                    │                     │                    │
      │                        │                                              │── Launch Process ──►│                    │                    │                     │                    │
 5.   │                        │                                              │                     │── flutter run ────►│                    │                     │                    │
 6.   │                        │                                              │                     │   (-d macos/linux) │                    │                     │                    │
 7.   │                        │                                              │                     │◄── VM Service URI ─│                    │                     │                    │
 8.   │                        │                                              │◄── Launched Target ─│   (http://127...)  │                    │                     │                    │
      │                        │                                              │                     │                    │                    │                     │                    │
 9.   │                        │                                              │── runConfiguredCases() ──────────────────────────────────────►│                     │                    │
10.   │                        │                                              │                                                               │── connect(Uri) ────►│                    │
11.   │                        │                                              │                                                               │◄── Connected ───────│                    │
      │                        │                                              │                                                               │                     │                    │
      │                        │  ═══════════════════════════════════════ REPEAT FOR EACH ENABLED TEST CASE ═════════════════════════════════  │                     │                    │
      │                        │                                              │                                                               │                     │                    │
      │                        │                                              │  [Step A: EnsureLoggedOutBlock]                               │                     │                    │
12.   │                        │                                              │                                                               │── waitForAnyKey() ─►│                    │
      │                        │                                              │                                                               │   (login/home/order)│                    │
13.   │                        │                                              │                                                               │◄── Active Key ──────│                    │
      │                        │                                              │   (If logged in: taps logout.button -> confirms logout)       │                     │                    │
      │                        │                                              │                                                               │                     │                    │
      │                        │                                              │  [Step B: PerformLoginBlock]                                  │                     │                    │
14.   │                        │                                              │                                                               │── tap(login.id) ───►│                    │
15.   │                        │                                              │                                                               │── enterText(user) ─►│                    │
16.   │                        │                                              │                                                               │── enterText(pass) ─►│                    │
17.   │                        │                                              │                                                               │                     │── arm(cursor) ────►│
18.   │                        │                                              │                                                               │── tap(login.submit)►│                    │
19.   │                        │                                              │                                                               │                     │── waitForCompletion│
20.   │                        │                                              │                                                               │                     │   (poll 150ms) ───►│
21.   │                        │                                              │                                                               │                     │◄── HTTP 200 OK ────│
      │                        │                                              │                                                               │                     │                    │
      │                        │                                              │  [Step C: SelectTerminalBlock]                                │                     │                    │
22.   │                        │                                              │                                                               │── tap(continue) ───►│                    │
      │                        │                                              │                                                               │                     │                    │
      │                        │                                              │  [Step D: VerifyHomeScreenBlock]                              │                     │                    │
23.   │                        │                                              │                                                               │── waitFor(home) ───►│                    │
24.   │                        │                                              │                                                               │◄── Home Verified ───│                    │
      │                        │                                              │                                                               │                     │                    │
      │                        │                                              │  [Step E: EnsureLoggedOutBlock (Post-Case Cleanup)]           │                     │                    │
25.   │                        │                                              │                                                               │── tap(logout) ─────►│                    │
      │                        │                                              │  ════════════════════════════════════════════════════════════  │                     │                    │
      │                        │                                              │                                                               │                     │                    │
26.   │                        │                                              │                                                               │── close() ─────────►│                    │
27.   │                        │                                              │◄── LoginRunResult (Case Results & Suite Totals) ──────────────│                     │                    │
28.   │                        │                                              │── Terminate Process (SIGINT / SIGTERM) ──────────────────────►│ (PenguinPOS exits)  │                    │
29.   │                        │◄── ExecutionPlanResult ──────────────────────│                                                                                     │                    │
30.   │◄── Render Output Tab ──│                                                                                                                                    │                    │
      │    or AI Chat Card     │                                                                                                                                    │                    │
```

---

### 3.1 Chronological Code Call-Path

#### Step 1: User Action & Preflight
- **Files**:
  - `lib/interfaces/gui/dashboard/screens/login/login_suite_screen.dart`
  - `lib/interfaces/gui/dashboard/screens/qa_dashboard_screen.dart`
  - `lib/application/execution/preflight_service.dart`
- **Functions**:
  1. `LoginSuiteScreen.onRunSuite` callback triggers `_runSelectedSuite()` in `_QaDashboardScreenState`.
  2. `_runManualPreflight()` constructs `PreflightService`.
  3. `PreflightService.check(ExecutionPlan)` performs safety checks:
     - `profile.isProduction == false` (Non-production enforcement).
     - `hasSavedLoginCredentials`: verifies username & password exist for successful login test cases.
     - `PathDetector.isValidAppRoot(_appRoot)` & `PathDetector.isValidFlutterExecutable(_flutterPath)` (Local) or `_verifySshConnection()` (SSH).
  4. Returns `PreflightResult.passed`.

#### Step 2: Dispatch to Coordinator
- **Files**:
  - `lib/interfaces/gui/dashboard/screens/qa_dashboard_screen.dart`
  - `lib/application/execution/qa_execution_coordinator.dart`
- **Functions**:
  1. `_runSelectedSuite()` instantiates a `PreparedExecution` object.
  2. Calls `_executionCoordinator.run(preparedExecution, callbacks: ...)`.
  3. Validates `execution.plan.validate()`.
  4. Initializes `ExecutionCancellationSignal` and attaches lifecycle listeners.

#### Step 3: Application Launch & Port Discovery
- **Files**:
  - `lib/runtime/app_launcher.dart` (or `lib/runtime/ssh/ssh_remote_app_launcher.dart`)
- **Functions**:
  1. `PenguinPosAppLauncher.launch()` is called with `appRoot`, `flutterExecutable`, `entity`, `env`.
  2. Spawns process:
     ```sh
     flutter run -d macos \
       --dart-define=ENABLE_FLUTTER_DRIVER=true \
       --dart-define=ENTITY=$entity \
       --dart-define=ENV=$env
     ```
  3. `_waitForVmServiceUri(process)`:
     - Merges `stdout` and `stderr` streams.
     - Uses regex `RegExp(r'https?://[^\s]+')` to detect line:  
       `The Dart VM service is available at: http://127.0.0.1:XXXXX/...`
     - Completes future with VM Service `Uri`.
  4. Returns `LaunchedPenguinPos` handle.

#### Step 4: Login Suite Execution Dispatch
- **Files**:
  - `lib/application/execution/qa_execution_coordinator.dart`
  - `lib/automation/login/login_runner.dart`
- **Functions**:
  1. `_executionCoordinator` identifies `plan.suiteId == QaSuiteId.loginTerminal`.
  2. Calls `_loginExecutor(...)` defined in `QaExecutionCoordinator.live`.
  3. Detects `execution.configuredLoginCases.isNotEmpty` and delegates to:
     ```dart
     PenguinPosLoginRunner.runConfiguredCases(
       cases,
       vmServiceUri: target.vmServiceUri,
       timeout: const Duration(seconds: 90),
       ...
     )
     ```

#### Step 5: Test Case Loop & Pipeline Assembly
- **Files**:
  - `lib/automation/login/login_runner.dart`
  - `lib/automation/core/pipeline_runner.dart`
  - `lib/automation/core/automation_pipeline.dart`
- **Functions**:
  1. Iterates over `definitions.where((c) => c.enabled)`.
  2. For each test case, maps its `expectedResult` to an ordered list of `AutomationBlock`s:
     - Always inserts `EnsureLoggedOutBlock()`.
     - If `LoginExpectedResult.requiredFieldValidation`:
       - If username & password empty: `ValidateEmptyCredentialsBlock()`.
       - If partial: `ValidatePartialCredentialsBlock(username, password)`.
     - If `LoginExpectedResult.authenticationRejected`:
       - `ValidateInvalidCredentialsBlock(username, password)`.
     - If `LoginExpectedResult.successfulLogin`:
       - `PerformLoginBlock(scenario)`.
       - `SelectTerminalBlock(scenario)`.
       - `VerifyHomeScreenBlock(scenario)`.
     - Cleanup block: `EnsureLoggedOutBlock()`.
  3. Calls `PipelineRunner().runPipeline(...)`.
  4. `activeDriver.connect(vmServiceUri)` initializes the VM Service connection via `DriverEngine`.

#### Step 6: Atomic Block Execution in Target UI
- **Files**:
  - `lib/automation/core/automation_pipeline.dart`
  - `lib/automation/login/blocks/ensure_logged_out_block.dart`
  - `lib/automation/login/blocks/perform_login_block.dart`
  - `lib/automation/login/blocks/select_terminal_block.dart`
  - `lib/automation/login/blocks/verify_home_screen_block.dart`
  - `lib/automation/login/login_api_call_barrier.dart`
  - `lib/runtime/driver_engine.dart`

- **Execution Details of Each Block**:
  1. **`EnsureLoggedOutBlock.execute()`**:
     - Calls `driver.waitForAnyKey(['login.id', 'home.screen', 'order.screen'])`.
     - If already on `login.id`, returns immediately.
     - If on `home.screen` or `order.screen`:
       - Probes `hasKey('logout.button')` (or falls back to `tapText('LOGOUT')`).
       - Taps `logout.confirm`.
       - Waits for `login.id` to appear.
  2. **`PerformLoginBlock.execute()`**:
     - Waits for `login.id`.
     - Taps `login.id` to request focus.
     - Calls `driver.enterTextViaVirtualKeyboard('login.id', scenario.loginId)`.
     - Calls `driver.enterTextViaVirtualKeyboard('login.password', scenario.password)`.
     - **Arms Barrier**: Calls `LoginApiCallBarrier.arm(driver)`.
       - Queries `driver.requestData('api_traces_since:0')`.
       - Records current cursor index.
     - Taps `login.submit`.
     - **Awaits Barrier**: Calls `loginApi.waitForCompletion(driver, expectation: LoginApiExpectation.accepted)`.
       - Polls every 150ms with minimum 35s timeout.
       - Confirms route `POST /authn/api/v1/pos/login` completed with HTTP `200..299` and `ApiTraceResult.success`.
  3. **`SelectTerminalBlock.execute()`**:
     - Clears any SnackBars.
     - Waits for `login.terminal.continue`.
     - Taps `login.terminal.continue`.
  4. **`VerifyHomeScreenBlock.execute()`**:
     - Waits for `home.screen` key to be present on screen.
  5. **Post-Case Cleanup**:
     - `PipelineRunner` runs `EnsureLoggedOutBlock` to log the user out so the next test case starts with a pristine session.

#### Step 7: Teardown & Result Aggregation
- **Files**:
  - `lib/automation/login/login_runner.dart`
  - `lib/application/execution/qa_execution_coordinator.dart`
  - `lib/interfaces/gui/dashboard/screens/qa_dashboard_screen.dart`
- **Functions**:
  1. `LoginTestCaseResult.fromDefinition` created for each case (redacting raw credentials).
  2. `LoginSuiteResult` aggregates pass/fail counts and total duration.
  3. `activeDriver.close()` terminates the Flutter Driver connection.
  4. `_closeTarget(launched)` sends `SIGINT`/`SIGTERM` to the PenguinPOS process.
  5. `QaExecutionCoordinator` returns `ExecutionPlanResult`.
  6. `QaDashboardScreen.setState()` updates dashboard models:
     - In **Manual Mode**: populates `_lastLoginSuiteResult` in `LoginSuiteScreen` and refreshes pass/fail cards in the UI.
     - In **AI Mode**: constructs an `AiRichLoginReport` containing the structured results table and posts an `AiChatMessage` to the chat canvas.

---

## 4. How Login Test Cases are Implemented

### 4.1 Domain Data Model
Located in `lib/domain/test_cases/login_test_case.dart`:

```dart
enum LoginExpectedResult {
  authenticationRejected,   // Expect invalid credentials error
  requiredFieldValidation,  // Expect client-side form validation error
  successfulLogin,          // Expect authentication -> terminal -> home -> logout
  idlePinRejected,          // Idle lock verification (future phase)
  idlePinAccepted;          // Idle lock verification (future phase)
}

class LoginTestCaseDefinition {
  final String id;
  final String name;
  final String description;
  final String username;    // Runtime secret
  final String password;    // Runtime secret
  final String pin;         // Runtime secret
  final LoginExpectedResult expectedResult;
  final bool enabled;
}
```

### 4.2 Security & Credential Isolation Architecture

A core architectural tenet of this codebase is **Zero Credential Leakage**:
1. **Metadata vs. Secret Storage Separation**:
   In `SharedPreferencesQaLoginTestCaseRepository`:
   - Metadata is stored as JSON under: `qa.profile.$profileId.suite.login.test_cases.v1`.  
     **`LoginTestCaseDefinition.toJson()` strictly excludes `username`, `password`, and `pin`**.
   - Secrets are saved individually under base64-encoded keys:  
     `qa.profile.$profileId.suite.login.case.$base64Id.username`  
     `qa.profile.$profileId.suite.login.case.$base64Id.password`
2. **Masked Summaries**:
   `LoginTestCaseDefinition.credentialsSummary` produces masked representations (e.g. `Username: te••••er, Password: ••••••••`).
3. **Automatic Secret Redaction**:
   When errors occur, `redactSecrets(errorString, [username, password, pin])` replaces every secret occurrence with `[REDACTED]` before messages reach the UI, logs, or reports.

### 4.3 Evaluation Matrix

| Case Type | Expected Outcome | Execution Verification Mechanism |
| :--- | :--- | :--- |
| **Empty Credentials** | `requiredFieldValidation` | Taps `login.submit`. Verifies `login.id` is still present (form does not submit). |
| **Partial Credentials** | `requiredFieldValidation` | Enters username only or password only. Taps submit. Verifies `login.id` remains present. |
| **Invalid Credentials** | `authenticationRejected` | Enters invalid username/password. Arms `LoginApiCallBarrier`. Taps submit. Barrier verifies `POST /authn/api/v1/pos/login` returns HTTP `4xx` and `login.id` remains visible. |
| **Valid Login** | `successfulLogin` | Enters valid credentials. Arms barrier. Barrier verifies HTTP `200..299`. Waits for and taps `login.terminal.continue`. Verifies `home.screen` is reached. Cleans up with logout. |

---

## 5. Codebase Navigation Cheat Sheet

| Feature / Question | Key File(s) to Inspect |
| :--- | :--- |
| **Application Entry & Startup** | `lib/main.dart`, `lib/interfaces/gui/app/qa_agent_app.dart` |
| **Dashboard Shell & State** | `lib/interfaces/gui/dashboard/screens/qa_dashboard_screen.dart` |
| **AI Assistant Workspace** | `lib/interfaces/gui/dashboard/screens/assistant/ai_assistant_workspace.dart` |
| **AI Planning & Prompting** | `lib/ai/orchestration/ai_orchestrator.dart`, `lib/ai/providers/openai_compatible_provider.dart` |
| **Manual Login Suite UI** | `lib/interfaces/gui/dashboard/screens/login/login_suite_screen.dart` |
| **Settings & Credentials UI** | `lib/interfaces/gui/dashboard/screens/settings/widgets/inputs_credentials_settings_tab.dart` |
| **Safety Preflight Checks** | `lib/application/execution/preflight_service.dart` |
| **Process Launcher (Local)** | `lib/runtime/app_launcher.dart` |
| **Process Launcher (SSH)** | `lib/runtime/ssh/ssh_remote_app_launcher.dart`, `ssh_flutter_run_session.dart` |
| **Driver & Virtual Keyboard** | `lib/runtime/driver_engine.dart` |
| **Login Suite Runner** | `lib/automation/login/login_runner.dart` |
| **Pipeline Runner Engine** | `lib/automation/core/pipeline_runner.dart`, `automation_pipeline.dart` |
| **Network API Trace Barrier**| `lib/automation/login/login_api_call_barrier.dart` |
| **Login Keys Contract** | `lib/automation/login/login_keys.dart` |
| **Login Case Repository** | `lib/domain/profiles/qa_login_test_case_repository.dart` |
| **Login Domain Models** | `lib/domain/test_cases/login_test_case.dart` |
