import 'dart:async';

import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/ai/models/qa_gen_ui.dart';
import 'package:penguin_pos_qa_agent/ai/orchestration/ai_orchestrator.dart';
import 'package:penguin_pos_qa_agent/ai/providers/openai_compatible_provider.dart';
import 'package:penguin_pos_qa_agent/application/execution/preflight_service.dart';
import 'package:penguin_pos_qa_agent/application/execution/qa_execution_coordinator.dart';
import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_runner.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_metrics.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/api_trace_collector.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/api_trace_event.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/runtime/path_detector.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/test_suite_model.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/repository/qa_target_preferences_repository.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/widgets/side_nav.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/login/login_suite_screen.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/order/order_suite_screen.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/register/register_suite_screen.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/register/close_register_suite_screen.dart';
import 'package:penguin_pos_qa_agent/automation/register/register_runner.dart';
import 'package:penguin_pos_qa_agent/automation/register/register_scenario.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/ai_assistant_workspace.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_log_drawer.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/qa_settings_screen.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_credential_vault.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_order_input_repository.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_login_test_case_repository.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_order_test_case_repository.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_register_input_repository.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/login_test_case.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/order_test_case.dart';
import 'package:penguin_pos_qa_agent/domain/plan/execution_plan.dart';
import 'package:penguin_pos_qa_agent/runtime/app_target_handle.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_connection_config.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_preflight.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_remote_app_launcher.dart';

/// Coordinates dashboard configuration, test execution, and the AI workspace.
///
/// Feature-specific presentation remains in the suite and assistant widgets.
/// This screen owns only the state that has to be shared between those views.
class QaDashboardScreen extends StatefulWidget {
  const QaDashboardScreen({
    super.key,
    this.sshLauncher,
    this.sshConnectionTester,
  });

  /// Supplied by the runtime SSH slice when it is available. Keeping this as
  /// an adapter lets the dashboard compile and remain local-only meanwhile.
  final ExecutionLauncher? sshLauncher;
  final SshConnectionTester? sshConnectionTester;

  @override
  State<QaDashboardScreen> createState() => _QaDashboardScreenState();
}

class _QaDashboardScreenState extends State<QaDashboardScreen> {
  final _preferences = QaTargetPreferencesRepository();
  final _credentialVault = QaCredentialVault();
  final _orderInputRepository = SharedPreferencesQaOrderInputRepository();
  final _loginCasesRepository = SharedPreferencesQaLoginTestCaseRepository();
  final _orderCasesRepository = SharedPreferencesQaOrderTestCaseRepository();
  final _registerInputRepository = SharedPreferencesQaRegisterInputRepository();
  final _sshRemoteAppLauncher = SshRemoteAppLauncher();

  bool _preferencesLoaded = false;
  bool _showFirstRunSetupPrompt = false;
  bool _showSettingsScreen = false;

  QaTargetMode _targetMode = QaTargetMode.local;
  String _flutterPath = 'flutter';
  String _appRoot = '/Users/reddygona/Documents/PenguinPOS/penguin_pos';
  List<QaProfile> _profiles = QaProfile.values;
  QaProfile _profile = QaProfile.values.first;
  String _loginId = '';
  String _password = '';
  String _unlockPin = '';
  String _sshUser = '';
  String _sshHost = '';
  String _sshPort = '';
  String _sshIdentityFile = '';
  String _sshRemoteAppRoot = '';
  String _sshRemoteFlutterPath = '';
  String _sshPassword = '';

  String _selectedSuiteId = 'login_terminal';
  AiInputSource _activeInputSource = AiInputSource.settings;
  OrderScenario _orderScenario = OrderScenario.sampleScenario;
  double _openingFloatAmount = 0.0;
  double _closeTotalAmount = 1000.0;
  bool _aiModeEnabled = true;
  final List<AiChatMessage> _aiChatMessages = <AiChatMessage>[];
  AiPendingRequest? _pendingAssistantRequest;
  bool _aiPlanningWaiting = false;
  bool _terminalExpanded = false;
  PlanningRequestHandle? _activePlanningHandle;

  bool get _hasActiveWork => _running || _aiPlanningWaiting;
  AiModelConfig _aiModelConfig = const AiModelConfig();
  QaTestNoticeDisplayMode _noticeDisplayMode =
      QaTestNoticeDisplayMode.warningsAndErrors;

  bool _aiModelConnected = false;
  int _modelConnectionGeneration = 0;

  bool _running = false;
  bool _stopRequested = false;
  Future<void>? _activeAiExecution;
  late final QaExecutionCoordinator _executionCoordinator;
  Duration? _lastExecutionDuration;
  bool? _lastExecutionPassed;
  bool? _lastCleanupPassed;
  String? _lastExecutionDetails;
  bool _wasAppClosedByUser = false;
  Map<String, Object?> _lastLoginMetadata = const <String, Object?>{};
  List<LoginTestCaseDefinition> _configuredLoginCases =
      const <LoginTestCaseDefinition>[];
  LoginSuiteResult? _lastLoginSuiteResult;
  int _loginRepeatCount = 1;
  List<String> _scenariosCompletedSoFar = <String>[];
  OrderRunResult? _lastOrderRunResult;
  RegisterRunResult? _lastRegisterRunResult;
  List<ApiTraceEvent> _apiTraces = const <ApiTraceEvent>[];

  // The runner can emit several events and telemetry snapshots for one driver
  // action. Keep those facts, but render them together so UI rebuilds never
  // become part of the execution critical path.
  static const _dashboardUpdateInterval = Duration(milliseconds: 150);
  Timer? _dashboardUpdateTimer;
  final List<QaActivityMessage> _pendingMessages = <QaActivityMessage>[];
  final List<String> _pendingCompletedScenarios = <String>[];
  final List<ExecutionEvent> _pendingExecutionEvents = <ExecutionEvent>[];
  List<ApiTraceEvent>? _pendingApiTraces;

  // Layer 3: Live execution progress tracking for the AI workspace.
  final _executionSteps = <AiExecutionStep>[];
  String _executionSuiteTitle = '';
  String _executionProfileLabel = '';
  final _executionStopwatch = Stopwatch();

  final _messages = <QaActivityMessage>[
    QaActivityMessage(
      'Ready',
      'QA Assistant is ready. Configure a reusable profile in Settings when needed.',
      QaActivityKind.info,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _executionCoordinator = QaExecutionCoordinator.live(
      sshLauncher: widget.sshLauncher ?? _launchSshTarget,
    );
    _loadSavedTargetPreferences();
  }

  Future<void> _loadSavedTargetPreferences() async {
    final profiles = await _preferences.loadProfiles();
    final selectedProfileId = await _preferences.loadSelectedProfileId();
    var hasCompletedInitialSetup = await _preferences
        .hasCompletedInitialSetup();
    final aiModeEnabled = await _preferences.loadAiModeEnabled();
    final aiModelConfig = await _preferences.loadAiModelConfig();
    final noticeDisplayMode = await _preferences.loadNoticeDisplayMode();
    final savedFlutterPath = await _preferences.loadFlutterPath();
    final savedAppRoot = await _preferences.loadAppRoot();
    final selectedProfile = profiles.firstWhere(
      (profile) => profile.id == selectedProfileId,
      orElse: () => profiles.first,
    );
    final target = await _preferences.loadSshTarget(
      profileId: selectedProfile.id,
    );
    final sshPassword = await _preferences.loadSshPassword(
      profileId: selectedProfile.id,
    );
    final credentials = await _credentialVault.read(selectedProfile.id);
    final savedOrderItems = await _orderInputRepository.read(
      selectedProfile.id,
    );
    final savedOrderCases = await _orderCasesRepository.read(
      selectedProfile.id,
    );
    final configuredCases = await _loginCasesRepository.readOrMigrateLegacy(
      selectedProfile.id,
      credentials,
    );
    final activeOrderCase = await _resolveActiveOrderCase(
      selectedProfile.id,
      savedOrderItems,
      savedOrderCases,
    );
    final registerInput = await _registerInputRepository.read(
      selectedProfile.id,
    );
    // Existing users configured before this preference was introduced should
    // not see first-run setup again simply because the marker is new.
    if (!hasCompletedInitialSetup &&
        selectedProfileId != null &&
        (credentials.loginId.isNotEmpty ||
            credentials.password.isNotEmpty ||
            credentials.unlockPin.isNotEmpty)) {
      await _preferences.markInitialSetupComplete();
      hasCompletedInitialSetup = true;
    }

    if (!mounted) return;
    setState(() {
      _targetMode = target.enabled ? QaTargetMode.ssh : QaTargetMode.local;
      _sshUser = target.username;
      _sshHost = target.host;
      _sshPort = target.port;
      _sshIdentityFile = target.identityFile;
      _sshRemoteAppRoot = target.appRoot;
      _sshRemoteFlutterPath = target.flutterPath;
      _sshPassword = sshPassword;
      _profiles = profiles;
      _profile = selectedProfile;
      _openingFloatAmount = registerInput.openingFloatAmount;
      _closeTotalAmount = registerInput.closeTotalAmount;
      if (activeOrderCase != null) {
        final orderCase = activeOrderCase;
        final matchingLoginCases = configuredCases
            .where((c) => c.id == orderCase.loginTestCaseId)
            .toList();
        final loginCase = matchingLoginCases.isEmpty
            ? null
            : matchingLoginCases.first;
        _orderScenario = orderCase.toScenario(
          loginId: loginCase?.username,
          password: loginCase?.password,
          unlockPin: loginCase?.pin,
        );
      }
      _loginId = credentials.loginId;
      _password = credentials.password;
      _unlockPin = credentials.unlockPin;
      _configuredLoginCases = configuredCases;
      _aiModelConfig = aiModelConfig;
      _noticeDisplayMode = noticeDisplayMode;
      _aiModeEnabled = aiModeEnabled;
      if (savedFlutterPath != null && savedFlutterPath.isNotEmpty) {
        _flutterPath = savedFlutterPath;
      }
      if (savedAppRoot != null && savedAppRoot.isNotEmpty) {
        _appRoot = savedAppRoot;
      }
      _preferencesLoaded = true;
      _showFirstRunSetupPrompt = !hasCompletedInitialSetup;
    });
    unawaited(_refreshAiModelConnection(aiModelConfig));
    if (!hasCompletedInitialSetup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showFirstRunSetupPrompt) {
          _openFirstRunSetupDialog();
        }
      });
    }
    if ((savedFlutterPath == null || savedFlutterPath.isEmpty) &&
        (savedAppRoot == null || savedAppRoot.isEmpty)) {
      _refreshDetectedPaths();
    }
  }

  /// Connectivity is deliberately checked separately from saved settings: a
  /// user might change a model's endpoint or key and expect the status badge to
  /// reflect whether that specific configuration is reachable right now.
  Future<void> _refreshAiModelConnection(AiModelConfig config) async {
    final generation = ++_modelConnectionGeneration;
    if (!config.isConfigured) {
      if (mounted) setState(() => _aiModelConnected = false);
      return;
    }

    try {
      final apiKey = await _credentialVault.readAiApiKey();
      final models = await OpenAiCompatibleProvider(
        config: config,
        apiKey: apiKey,
      ).listModels();
      if (!mounted || generation != _modelConnectionGeneration) return;
      setState(() => _aiModelConnected = models.isNotEmpty);
    } catch (_) {
      if (!mounted || generation != _modelConnectionGeneration) return;
      setState(() => _aiModelConnected = false);
    }
  }

  Future<OrderTestCaseDefinition?> _resolveActiveOrderCase(
    String profileId,
    List<OrderItem> legacyItems,
    List<OrderTestCaseDefinition> savedCases,
  ) async {
    OrderTestCaseDefinition? active;
    if (savedCases.isNotEmpty) {
      active = savedCases.firstWhere(
        (candidate) => candidate.enabled,
        orElse: () => savedCases.first,
      );
    } else if (legacyItems.isNotEmpty) {
      active = OrderTestCaseDefinition(
        id: 'ORD-${profileId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '-')}',
        title: 'Manual Order Inputs',
        description: 'Migrated from saved SKU inputs.',
        loginTestCaseId: '',
        items: List<OrderItem>.unmodifiable(legacyItems),
      );
      await _orderCasesRepository.write(profileId, <OrderTestCaseDefinition>[
        active,
      ]);
    }
    return active;
  }

  /// Path checks touch the local file system and must not delay the first AI
  /// screen. The runner receives the detected values before it is invoked.
  Future<void> _refreshDetectedPaths() async {
    final flutterPath = await PathDetector.detectFlutterPath();
    final appRoot = await PathDetector.detectAppRoot();
    if (!mounted) return;
    setState(() {
      _flutterPath = flutterPath;
      _appRoot = appRoot;
    });
  }

  Future<void> _selectProfile(QaProfile profile) async {
    final credentials = await _credentialVault.read(profile.id);
    final sshTarget = await _preferences.loadSshTarget(profileId: profile.id);
    final sshPassword = await _preferences.loadSshPassword(
      profileId: profile.id,
    );
    final savedOrderItems = await _orderInputRepository.read(profile.id);
    final savedOrderCases = await _orderCasesRepository.read(profile.id);
    final configuredCases = await _loginCasesRepository.readOrMigrateLegacy(
      profile.id,
      credentials,
    );
    final activeOrderCase = await _resolveActiveOrderCase(
      profile.id,
      savedOrderItems,
      savedOrderCases,
    );
    final registerInput = await _registerInputRepository.read(profile.id);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _openingFloatAmount = registerInput.openingFloatAmount;
      _closeTotalAmount = registerInput.closeTotalAmount;
      _targetMode = sshTarget.enabled ? QaTargetMode.ssh : QaTargetMode.local;
      _sshUser = sshTarget.username;
      _sshHost = sshTarget.host;
      _sshPort = sshTarget.port;
      _sshIdentityFile = sshTarget.identityFile;
      _sshRemoteAppRoot = sshTarget.appRoot;
      _sshRemoteFlutterPath = sshTarget.flutterPath;
      _sshPassword = sshPassword;
      if (activeOrderCase != null) {
        final orderCase = activeOrderCase;
        final matchingLoginCases = configuredCases
            .where((c) => c.id == orderCase.loginTestCaseId)
            .toList();
        final loginCase = matchingLoginCases.isEmpty
            ? null
            : matchingLoginCases.first;
        _orderScenario = orderCase.toScenario(
          loginId: loginCase?.username,
          password: loginCase?.password,
          unlockPin: loginCase?.pin,
        );
      }
      _loginId = credentials.loginId;
      _password = credentials.password;
      _unlockPin = credentials.unlockPin;
      _configuredLoginCases = configuredCases;
      _lastLoginSuiteResult = null;
      _lastOrderRunResult = null;
      _lastRegisterRunResult = null;
    });
    await _preferences.saveSelectedProfileId(profile.id);
  }

  SshExecutionConfig get _sshExecutionConfig => SshExecutionConfig(
    username: _sshUser,
    host: _sshHost,
    port: int.tryParse(_sshPort) ?? 22,
    identityFile: _sshIdentityFile.isEmpty ? null : _sshIdentityFile,
    remoteAppRoot: _sshRemoteAppRoot,
    remoteFlutterExecutable: _sshRemoteFlutterPath.isEmpty
        ? 'flutter'
        : _sshRemoteFlutterPath,
    password: _sshPassword.isEmpty ? null : _sshPassword,
  );

  Future<AppTargetHandle> _launchSshTarget(
    ExecutionLaunchRequest request,
  ) async {
    final config = request.sshConfig;
    if (config == null) {
      throw StateError('SSH target configuration is missing.');
    }
    return _sshRemoteAppLauncher.launch(
      config: SshConnectionConfig(
        host: config.host,
        username: config.username,
        port: config.port,
        identityFile: config.identityFile,
        remoteAppRoot: config.remoteAppRoot,
        remoteFlutterExecutable: config.remoteFlutterExecutable,
        password: config.password,
      ),
      entity: request.entity,
      environment: request.environment,
    );
  }

  Future<bool> _performSshConnectionTest(SshExecutionConfig config) async {
    final runtimeConfig = SshConnectionConfig(
      host: config.host,
      username: config.username,
      port: config.port,
      identityFile: config.identityFile,
      remoteAppRoot: config.remoteAppRoot,
      remoteFlutterExecutable: config.remoteFlutterExecutable,
      password: config.password,
    );
    await SshPreflight().verify(runtimeConfig);
    return true;
  }

  /// Verifies SSH, remote paths, and an active Linux graphical session.
  Future<bool> _verifySshConnection({bool announce = true}) async {
    final config = _sshExecutionConfig;
    if (!config.isConfigured) {
      if (announce) {
        _addMessage(
          'SSH Configuration Required',
          'Save an SSH username and host before selecting a remote target.',
          QaActivityKind.error,
        );
      }
      return false;
    }
    try {
      final connected = widget.sshConnectionTester == null
          ? await _performSshConnectionTest(config)
          : await widget.sshConnectionTester!(config);
      if (!connected && announce) {
        _addMessage(
          'SSH Connection Failed',
          'Could not connect to ${config.username}@${config.host}. No application was launched.',
          QaActivityKind.error,
        );
      }
      return connected;
    } catch (error) {
      if (announce) {
        _addMessage(
          'SSH Connection Failed',
          error.toString(),
          QaActivityKind.error,
        );
      }
      return false;
    }
  }

  Future<void> _setTargetMode(QaTargetMode mode) async {
    if (_running || mode == _targetMode) return;
    setState(() => _targetMode = mode);
    await _preferences.saveSshEnabled(
      mode == QaTargetMode.ssh,
      profileId: _profile.id,
    );
    if (mode == QaTargetMode.ssh) {
      await _verifySshConnection();
    }
  }

  Future<void> _setAiModeEnabled(bool enabled) async {
    if (!enabled && _hasActiveWork) {
      final choice = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Active Task Running'),
          content: const Text(
            'A QA test execution or model planning request is currently running. Leaving AI mode will stop active work.',
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('stay'),
              child: const Text('Keep running and stay here'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD92D20),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop('stop'),
              child: const Text('Stop execution and leave'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('cancel'),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (choice != 'stop') return;
      await _stopActiveWork();
    }
    setState(() => _aiModeEnabled = enabled);
    await _preferences.saveAiModeEnabled(enabled);
  }

  Future<void> _stopActiveWork() async {
    _activePlanningHandle?.cancel();
    _activePlanningHandle = null;
    if (_running) {
      await _stopRunningSuite();
      // Wait until the runner has converted the app-quit signal into a
      // complete result and rendered the pass/fail report.
      await _activeAiExecution;
    }
    if (!mounted) return;
    setState(() {
      _aiPlanningWaiting = false;
    });
  }

  void _openFirstRunSetupDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Row(
          children: <Widget>[
            Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF7C3AED),
              size: 20,
            ),
            SizedBox(width: 10),
            Text(
              'Welcome to QA Assistant',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: const SizedBox(
          width: 410,
          child: Text(
            'Reusable environment, credentials/PIN, and optional local/cloud model are configured in Settings.',
            style: TextStyle(
              height: 1.5,
              fontSize: 13.5,
              color: Color(0xFF475569),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        actions: <Widget>[
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              _openSettingsDialog();
            },
            icon: const Icon(Icons.settings_outlined, size: 16),
            label: const Text(
              'Open Settings',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _openSettingsDialog() {
    setState(() => _showSettingsScreen = true);
  }

  void _openSupportDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: <Widget>[
            Icon(Icons.help_outline_rounded, color: Color(0xFF155EEF)),
            SizedBox(width: 10),
            Text('PenguinPOS Support'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'PenguinPOS QA Agent v0.1.0',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              'Automated execution driver & desktop GUI app for PenguinPOS testing.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _stopRunningSuite() async {
    if (!_running || _stopRequested) return;

    setState(() => _stopRequested = true);
    _addMessage(
      'Stop Requested',
      'Stopping the active test case and closing the PenguinPOS instance launched by QA.',
      QaActivityKind.info,
    );
    await _executionCoordinator.requestStop();
  }

  void _recordCompletedScenario(String scenarioName) {
    _pendingCompletedScenarios.add(scenarioName);
    _scheduleDashboardUpdate();
  }

  void _applyCompletedScenario(String scenarioName) {
    var existingIdx = _executionSteps.indexWhere(
      (s) => s.scenarioName == scenarioName,
    );
    if (existingIdx < 0) {
      final caseMatch = _configuredLoginCases
          .where((c) => c.name == scenarioName || c.id == scenarioName)
          .firstOrNull;
      if (caseMatch != null) {
        existingIdx = _executionSteps.indexWhere(
          (s) => s.scenarioName == caseMatch.name,
        );
      }
    }

    if (existingIdx >= 0) {
      final oldStep = _executionSteps[existingIdx];
      if (!_scenariosCompletedSoFar.contains(oldStep.scenarioName)) {
        _scenariosCompletedSoFar.add(oldStep.scenarioName);
      }
      _executionSteps[existingIdx] = AiExecutionStep(
        scenarioName: oldStep.scenarioName,
        status: AiScenarioStatus.passed,
        elapsedMs: _executionStopwatch.elapsedMilliseconds,
        totalScenarios: oldStep.totalScenarios,
        completedScenarios: _scenariosCompletedSoFar.length,
      );
    }
  }

  void _recordExecutionEvent(ExecutionEvent event) {
    _addMessage(event.title, event.message, switch (event.level) {
      ExecutionEventLevel.success => QaActivityKind.success,
      ExecutionEventLevel.error => QaActivityKind.error,
      ExecutionEventLevel.info => QaActivityKind.info,
    });

    _pendingExecutionEvents.add(event);
    _scheduleDashboardUpdate();
  }

  void _applyExecutionEvent(ExecutionEvent event) {
    var idx = _executionSteps.indexWhere((s) => s.scenarioName == event.title);
    if (idx < 0) {
      final caseMatch = _configuredLoginCases
          .where((c) => c.name == event.title || c.id == event.title)
          .firstOrNull;
      if (caseMatch != null) {
        idx = _executionSteps.indexWhere(
          (s) => s.scenarioName == caseMatch.name,
        );
      }
    }
    if (idx < 0) {
      return;
    }
    final oldStep = _executionSteps[idx];
    if (event.level == ExecutionEventLevel.error) {
      if (!_scenariosCompletedSoFar.contains(oldStep.scenarioName)) {
        _scenariosCompletedSoFar.add(oldStep.scenarioName);
      }
      _executionSteps[idx] = AiExecutionStep(
        scenarioName: oldStep.scenarioName,
        status: AiScenarioStatus.failed,
        detail: event.message,
        elapsedMs: _executionStopwatch.elapsedMilliseconds,
        totalScenarios: oldStep.totalScenarios,
        completedScenarios: _scenariosCompletedSoFar.length,
      );
      return;
    }
    if (oldStep.status != AiScenarioStatus.pending &&
        oldStep.status != AiScenarioStatus.running) {
      return;
    }
    _executionSteps[idx] = AiExecutionStep(
      scenarioName: oldStep.scenarioName,
      status: AiScenarioStatus.running,
      detail: event.message,
      totalScenarios: oldStep.totalScenarios,
      completedScenarios: _scenariosCompletedSoFar.length,
    );
  }

  void _queueApiTraces(List<ApiTraceEvent> traces) {
    // Each collector callback contains the complete cumulative trace list, so
    // retaining only the newest snapshot cannot drop a trace.
    _pendingApiTraces = List<ApiTraceEvent>.unmodifiable(traces);
    _scheduleDashboardUpdate();
  }

  void _scheduleDashboardUpdate() {
    if (!mounted || _dashboardUpdateTimer != null) return;
    _dashboardUpdateTimer = Timer(
      _dashboardUpdateInterval,
      _flushDashboardUpdates,
    );
  }

  void _flushDashboardUpdates() {
    _dashboardUpdateTimer?.cancel();
    _dashboardUpdateTimer = null;
    if (!mounted) {
      _pendingMessages.clear();
      _pendingCompletedScenarios.clear();
      _pendingExecutionEvents.clear();
      _pendingApiTraces = null;
      return;
    }
    if (_pendingMessages.isEmpty &&
        _pendingCompletedScenarios.isEmpty &&
        _pendingExecutionEvents.isEmpty &&
        _pendingApiTraces == null) {
      return;
    }
    setState(() {
      _messages.addAll(_pendingMessages);
      _pendingMessages.clear();
      for (final scenario in _pendingCompletedScenarios) {
        _applyCompletedScenario(scenario);
      }
      _pendingCompletedScenarios.clear();
      for (final event in _pendingExecutionEvents) {
        _applyExecutionEvent(event);
      }
      _pendingExecutionEvents.clear();
      final traces = _pendingApiTraces;
      if (traces != null) _apiTraces = traces;
      _pendingApiTraces = null;
    });
  }

  String _interruptionDetails({required bool wasStopped}) => wasStopped
      ? 'Test stopped by the user. Completed test cases are retained; remaining cases are pending.'
      : 'PenguinPOS was quit during testing. Completed test cases are retained; remaining cases are pending.';

  Future<AiAssistantResponse> _respondToAi(
    String input,
    List<AiChatMessage> history,
    AiModelEventCallback onEvent,
  ) async {
    _activePlanningHandle?.cancel();
    final handle = PlanningRequestHandle(
      generationId: DateTime.now().microsecondsSinceEpoch,
    );
    _activePlanningHandle = handle;

    void safeOnEvent(AiModelEvent event) {
      if (handle.generationId != _activePlanningHandle?.generationId ||
          handle.isCancelled) {
        return;
      }
      onEvent(event);
    }

    try {
      final apiKey = await _credentialVault.readAiApiKey();
      final provider = _aiModelConfig.isConfigured && _aiModelConnected
          ? OpenAiCompatibleProvider(config: _aiModelConfig, apiKey: apiKey)
          : null;

      final orchestrator = AiOrchestrator(
        profiles: _profiles,
        activeProfile: _profile,
        provider: provider,
      );

      final response = await orchestrator.respond(
        input: input,
        history: history,
        pendingRequest: _pendingAssistantRequest,
        cancelToken: handle.cancelToken,
        onEvent: safeOnEvent,
      );

      if (handle.generationId != _activePlanningHandle?.generationId ||
          handle.isCancelled) {
        throw const OperationCanceledException(
          'Cancelled stale planning request.',
        );
      }

      var finalResponse = response;
      if (response.plan != null) {
        if (response.plan!.isOrder &&
            response.plan!.inputSource == AiInputSource.settings) {
          final profileId = response.plan!.profileId;
          final savedOrderItems = await _orderInputRepository.read(profileId);
          final savedOrderCases = await _orderCasesRepository.read(profileId);
          final activeOrderCase = await _resolveActiveOrderCase(
            profileId,
            savedOrderItems,
            savedOrderCases,
          );

          if (activeOrderCase != null) {
            final requestedCount = response.plan!.overrideSettingsOrderCount
                ? response.plan!.ordersCount
                : null;
            final scenario = activeOrderCase.toScenario(
              ordersCount: requestedCount,
            );
            final usesPerIteration =
                scenario.ordersCount > 1 &&
                scenario.uiCustomMode == UiCustomMode.perIteration;
            final hydratedPlan = response.plan!.copyWith(
              ordersCount: scenario.ordersCount,
              itemStrategy: usesPerIteration
                  ? AiItemStrategy.perOrder
                  : AiItemStrategy.sameForAll,
              items: usesPerIteration ? const <OrderItem>[] : scenario.items,
              perIterationItems: usesPerIteration
                  ? <int, List<OrderItem>>{
                      for (
                        var order = 1;
                        order <= scenario.ordersCount;
                        order++
                      )
                        order: List<OrderItem>.unmodifiable(
                          scenario.getItemsForIteration(order),
                        ),
                    }
                  : const <int, List<OrderItem>>{},
            );

            final summary = response.richContent is AiRichPlanSummary
                ? response.richContent as AiRichPlanSummary
                : null;
            final orderItemRows = usesPerIteration
                ? <AiOrderItemRow>[
                    for (var order = 1; order <= scenario.ordersCount; order++)
                      for (final item in scenario.getItemsForIteration(order))
                        AiOrderItemRow.fromOrderItem(
                          item,
                          allocationLabel: 'Order $order',
                        ),
                  ]
                : <AiOrderItemRow>[
                    for (final item in scenario.items)
                      AiOrderItemRow.fromOrderItem(
                        item,
                        allocationLabel: scenario.ordersCount > 1
                            ? 'All ${scenario.ordersCount} Orders'
                            : 'Order 1',
                      ),
                  ];
            final enrichedSummary = summary == null
                ? response.richContent
                : AiRichPlanSummary(
                    profileLabel: summary.profileLabel,
                    workflowLabel: summary.workflowLabel,
                    dataSourceLabel:
                        'Settings → Inputs & Credentials → Order Inputs',
                    scenarios: summary.scenarios,
                    orderItems: orderItemRows,
                  );

            finalResponse = AiAssistantResponse(
              state: response.state,
              message: response.message,
              plan: hydratedPlan,
              missingFields: response.missingFields,
              kind: response.kind,
              knowledge: response.knowledge,
              richContent: enrichedSummary,
              pendingRequest: response.pendingRequest,
            );
          }
        } else if (!response.plan!.isOrder) {
          final profileId = response.plan!.profileId;
          final credentials = await _credentialVault.read(profileId);
          final savedLoginCases = await _loginCasesRepository
              .readOrMigrateLegacy(profileId, credentials);
          final selectedLoginCases = response.plan!.loginCaseIds.isEmpty
              ? savedLoginCases.where((caseItem) => caseItem.enabled).toList()
              : savedLoginCases
                    .where(
                      (caseItem) =>
                          caseItem.enabled &&
                          response.plan!.loginCaseIds.contains(caseItem.id),
                    )
                    .toList();

          final enrichedPlan = response.plan!.copyWith(
            loginCases: selectedLoginCases,
            executionSteps: selectedLoginCases.isNotEmpty
                ? selectedLoginCases.map((c) => '${c.id}: ${c.name}').toList()
                : response.plan!.executionSteps,
          );
          finalResponse = AiAssistantResponse(
            state: response.state,
            message: response.message,
            plan: enrichedPlan,
            missingFields: response.missingFields,
            kind: response.kind,
            richContent: response.richContent,
            pendingRequest: response.pendingRequest,
          );
        }
      }

      setState(() {
        _pendingAssistantRequest = finalResponse.pendingRequest;
      });

      return finalResponse;
    } catch (e) {
      if (handle.generationId != _activePlanningHandle?.generationId ||
          handle.isCancelled) {
        throw const OperationCanceledException(
          'Cancelled stale planning request.',
        );
      }
      rethrow;
    }
  }

  Future<void> _runAiPlan(AiTestPlan plan) async {
    final profile = _profileForId(plan.profileId);
    final plannedSuite = plan.isOrder
        ? _suiteForId('order_checkout')
        : _suiteForId('login_terminal');
    final preflightSteps = <String>[
      'Matched target profile: ${profile.label.isEmpty ? plan.profileId : profile.label}',
      'Confirmed approved non-production target',
      'Checked saved credentials',
      'Checked ${plannedSuite.title} readiness',
      _targetMode == QaTargetMode.ssh
          ? 'Confirmed SSH target is available'
          : 'Confirmed local launch is available',
    ];

    if (profile.id.isEmpty) {
      _finishAiPreflight(
        steps: preflightSteps,
        failedStep: 0,
        message:
            'I could not find the selected target profile. Choose an approved non-production profile and try again.',
      );
      _addMessage(
        'Execution Blocked',
        'The selected target profile is no longer configured. Choose an approved non-production profile and try again.',
        QaActivityKind.error,
      );
      return;
    }
    if (profile.isProduction) {
      _finishAiPreflight(
        steps: preflightSteps,
        failedStep: 1,
        message:
            'Production environments are strictly prohibited. No application was launched.',
      );
      _addMessage(
        'Execution Blocked',
        'Production environments are strictly prohibited for QA Agent execution.',
        QaActivityKind.error,
      );
      return;
    }
    final credentials = await _credentialVault.read(profile.id);
    // AI login runs use the same profile-scoped case definitions as Manual
    // mode. Negative cases are intentionally allowed to contain empty
    // credentials; only a selected successful-login case requires values.
    final savedLoginCases = await _loginCasesRepository.readOrMigrateLegacy(
      profile.id,
      credentials,
    );
    final selectedLoginCases = plan.loginCaseIds.isEmpty
        ? savedLoginCases.where((caseItem) => caseItem.enabled).toList()
        : savedLoginCases
              .where(
                (caseItem) =>
                    caseItem.enabled && plan.loginCaseIds.contains(caseItem.id),
              )
              .toList();
    final loginCasesNeedCredentials = selectedLoginCases.any(
      (caseItem) =>
          caseItem.expectedResult == LoginExpectedResult.successfulLogin,
    );
    if (!plan.isOrder &&
        plan.loginCaseIds.isNotEmpty &&
        selectedLoginCases.length != plan.loginCaseIds.length) {
      _finishAiPreflight(
        steps: preflightSteps,
        failedStep: 2,
        message:
            'One or more login test cases in this AI plan are no longer available or enabled. Refresh the plan from Settings and try again.',
      );
      _addMessage(
        'Login Cases Changed',
        'The AI plan references login cases that are missing or disabled.',
        QaActivityKind.error,
      );
      return;
    }
    if (selectedLoginCases.isEmpty &&
        (credentials.loginId.isEmpty || credentials.password.isEmpty)) {
      _finishAiPreflight(
        steps: preflightSteps,
        failedStep: 2,
        message:
            'Credentials are missing for ${profile.label}. Open Settings → Credentials, select this profile, and save the login ID and password.',
      );
      _addMessage(
        'Credentials Required',
        'Save the login ID and password for ${profile.label} in Settings → Credentials before running this plan.',
        QaActivityKind.error,
      );
      return;
    }
    // Only successful-login cases require credentials. Negative test cases
    // (requiredFieldValidation, authenticationRejected) intentionally contain
    // empty or invalid credentials and must not trigger a preflight block.
    final credentialMissingCase = loginCasesNeedCredentials
        ? selectedLoginCases.cast<LoginTestCaseDefinition?>().firstWhere(
            (caseItem) =>
                caseItem!.expectedResult ==
                    LoginExpectedResult.successfulLogin &&
                (caseItem.username.trim().isEmpty ||
                    caseItem.password.trim().isEmpty),
            orElse: () => null,
          )
        : null;
    if (credentialMissingCase != null) {
      _finishAiPreflight(
        steps: preflightSteps,
        failedStep: 2,
        message:
            'Login case \'${credentialMissingCase.name}\' (${credentialMissingCase.id}) is missing a username or password. Update it in Settings → Inputs & Credentials → Login.',
      );
      _addMessage(
        'Credentials Required',
        'Login case \'${credentialMissingCase.name}\' (${credentialMissingCase.id}) needs a username and password.',
        QaActivityKind.error,
      );
      return;
    }
    if (!plannedSuite.isImplemented) {
      _finishAiPreflight(
        steps: preflightSteps,
        failedStep: 3,
        message:
            '${plannedSuite.title} is configured but does not yet have an executable runner.',
      );
      _addMessage(
        'Suite Pending',
        'The ${plannedSuite.title} runner is scheduled for the next phase.',
        QaActivityKind.info,
      );
      return;
    }

    final targetReady = _targetMode == QaTargetMode.ssh
        ? await _verifySshConnection()
        : true;

    final appRootIsValid = _targetMode == QaTargetMode.ssh
        ? true
        : await PathDetector.isValidAppRoot(_appRoot);
    final flutterIsValid = _targetMode == QaTargetMode.ssh
        ? true
        : await PathDetector.isValidFlutterExecutable(_flutterPath);
    if (!targetReady || !appRootIsValid || !flutterIsValid) {
      _finishAiPreflight(
        steps: preflightSteps,
        failedStep: 4,
        message: _targetMode == QaTargetMode.ssh
            ? 'The SSH target is not ready. Check the saved connection and SSH runtime adapter before running this plan.'
            : 'The local PenguinPOS app path or Flutter executable is not ready. Review Settings → System & Engine Paths before running.',
      );
      _addMessage(
        _targetMode == QaTargetMode.ssh
            ? 'SSH Target Not Ready'
            : 'Launch Setup Required',
        _targetMode == QaTargetMode.ssh
            ? 'Check the SSH target and connection before running this plan.'
            : 'Review the PenguinPOS app root and Flutter executable in Settings → System & Engine Paths before running this plan.',
        QaActivityKind.error,
      );
      return;
    }

    setState(() {
      _profile = profile;
      _loginId = credentials.loginId;
      _password = credentials.password;
      _unlockPin = credentials.unlockPin;
      _activeInputSource = plan.inputSource;
      if (!plan.isOrder) {
        _configuredLoginCases = selectedLoginCases;
      }
      _selectedSuiteId = plan.isOrder ? 'order_checkout' : 'login_terminal';
      _loginRepeatCount = plan.isOrder ? 1 : plan.repeatCount;
      if (plan.isOrder && plan.inputSource == AiInputSource.user) {
        _orderScenario = OrderScenario(
          id: 'ai_${profile.id}_order_cash',
          name: 'AI planned Order & Cash Payment',
          items: plan.items,
          ordersCount: plan.ordersCount,
          inputSourceMode: InputSourceMode.uiForm,
          uiCustomMode: plan.itemStrategy == AiItemStrategy.perOrder
              ? UiCustomMode.perIteration
              : UiCustomMode.common,
          perIterationItems: plan.perIterationItems,
        );
      }
    });
    await _preferences.saveSelectedProfileId(profile.id);
    final execution = _runSelectedSuite(
      skipPreflight: true,
      useConfiguredOrderInputs: plan.inputSource == AiInputSource.settings,
      configuredOrderCountOverride:
          plan.inputSource == AiInputSource.settings &&
              plan.overrideSettingsOrderCount
          ? plan.ordersCount
          : null,
    );
    _activeAiExecution = execution;
    try {
      await execution;
    } finally {
      if (identical(_activeAiExecution, execution)) {
        _activeAiExecution = null;
      }
    }
  }

  /// Opens a validated assistant plan in the existing manual workspace without
  /// launching PenguinPOS. The manual forms remain the operator's editable
  /// review surface; execution can only begin from their Run action.
  Future<void> _openAiPlanInManualMode(AiTestPlan plan) async {
    final profile = _profileForId(plan.profileId);
    if (profile.id.isEmpty) {
      _addMessage(
        'Plan Needs Attention',
        'The target profile in this plan is no longer configured.',
        QaActivityKind.error,
      );
      return;
    }
    final credentials = await _credentialVault.read(profile.id);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loginId = credentials.loginId;
      _password = credentials.password;
      _unlockPin = credentials.unlockPin;
      _activeInputSource = plan.inputSource;
      _selectedSuiteId = plan.isOrder ? 'order_checkout' : 'login_terminal';
      if (plan.isOrder && plan.inputSource == AiInputSource.user) {
        _orderScenario = OrderScenario(
          id: 'ai_${profile.id}_order_cash',
          name: 'AI planned Order & Cash Payment',
          items: plan.items,
          ordersCount: plan.ordersCount,
          inputSourceMode: InputSourceMode.uiForm,
          uiCustomMode: plan.itemStrategy == AiItemStrategy.perOrder
              ? UiCustomMode.perIteration
              : UiCustomMode.common,
          perIterationItems: plan.perIterationItems,
        );
      }
      _aiModeEnabled = false;
    });
    await _preferences.saveSelectedProfileId(profile.id);
    await _preferences.saveAiModeEnabled(false);
    _addMessage(
      'Plan Opened in Manual Mode',
      'Review and edit the generated plan before running it.',
      QaActivityKind.info,
    );
  }

  QaProfile _profileForId(String profileId) => _profiles.firstWhere(
    (candidate) => candidate.id == profileId,
    orElse: () =>
        const QaProfile(id: '', label: '', entity: '', environment: ''),
  );

  TestSuiteItem _suiteForId(String suiteId) =>
      TestSuiteItem.availableSuites.firstWhere(
        (suite) => suite.id == suiteId,
        orElse: () => TestSuiteItem.availableSuites.first,
      );

  void _finishAiPreflight({
    required List<String> steps,
    required String message,
    int? failedStep,
  }) {
    if (_aiModeEnabled) {
      setState(() {
        _aiChatMessages.add(
          AiChatMessage(
            role: AiChatRole.assistant,
            text: message,
            richContent: AiRichPlanningSummary(
              steps: steps,
              failedStep: failedStep,
            ),
          ),
        );
      });
    }
    setState(() {
      _running = false;
      _executionSteps.clear();
    });
  }

  ExecutionPlan _manualExecutionPlan() => ExecutionPlan(
    profileId: _profile.id,
    suiteId: _selectedSuiteId == 'order_checkout'
        ? QaSuiteId.orderCheckout
        : _selectedSuiteId == 'register'
        ? QaSuiteId.register
        : _selectedSuiteId == 'close_register'
        ? QaSuiteId.closeRegister
        : QaSuiteId.loginTerminal,
    orderConfiguration: _selectedSuiteId == 'order_checkout'
        ? OrderExecutionConfiguration(
            ordersCount: _orderScenario.ordersCount,
            itemStrategy:
                _orderScenario.uiCustomMode == UiCustomMode.perIteration
                ? ExecutionItemStrategy.perOrder
                : ExecutionItemStrategy.sameForAll,
            items: _orderScenario.items,
            perIterationItems: _orderScenario.perIterationItems,
          )
        : null,
  );

  /// Manual mode uses the same safety contract as an AI-reviewed plan. The AI
  /// path has already displayed this preflight before calling the runner.
  Future<bool> _runManualPreflight() async {
    final preflight = PreflightService(
      PreflightDependencies(
        findProfile: (profileId) {
          final profile = _profileForId(profileId);
          return profile.id.isEmpty
              ? null
              : PreflightProfile(
                  id: profile.id,
                  label: profile.label,
                  isProduction: profile.isProduction,
                );
        },
        hasSavedLoginCredentials: (profileId) async {
          if (_configuredLoginCases.isNotEmpty) {
            final enabledCases = _configuredLoginCases.where(
              (caseItem) => caseItem.enabled,
            );
            final successfulCases = enabledCases.where(
              (caseItem) =>
                  caseItem.expectedResult ==
                  LoginExpectedResult.successfulLogin,
            );
            if (successfulCases.isNotEmpty) {
              return successfulCases.every(
                (caseItem) =>
                    caseItem.username.trim().isNotEmpty &&
                    caseItem.password.trim().isNotEmpty,
              );
            }
            if (enabledCases.isNotEmpty) return true;
          }
          final credentials = await _credentialVault.read(profileId);
          return credentials.loginId.isNotEmpty &&
              credentials.password.isNotEmpty;
        },
        isSuiteImplemented: (suiteId) =>
            _suiteForId(suiteId.storageValue).isImplemented,
        checkRuntimeReadiness: () async {
          if (_targetMode == QaTargetMode.ssh) {
            return RuntimeReadiness(
              localExecutionSupported: await _verifySshConnection(),
              appRootIsValid: true,
              flutterExecutableIsValid: true,
            );
          }
          return RuntimeReadiness(
            localExecutionSupported: true,
            appRootIsValid: await PathDetector.isValidAppRoot(_appRoot),
            flutterExecutableIsValid:
                await PathDetector.isValidFlutterExecutable(_flutterPath),
          );
        },
      ),
    );
    final result = await preflight.check(_manualExecutionPlan());
    if (result.passed) return true;

    final failure = result.failure;
    final message = failure?.message ?? 'The test plan did not pass preflight.';
    _addMessage('Execution Blocked', message, QaActivityKind.error);
    if (mounted) {
      setState(() {
        _lastExecutionPassed = null;
        _wasAppClosedByUser = false;
        _lastExecutionDetails = message;
      });
    }
    return false;
  }

  Future<void> _runSelectedSuite({
    bool skipPreflight = false,
    bool? useConfiguredOrderInputs,
    int? configuredOrderCountOverride,
  }) async {
    final shouldUseConfiguredOrderInputs =
        useConfiguredOrderInputs ??
        _activeInputSource == AiInputSource.settings;
    if (_selectedSuiteId == 'order_checkout') {
      final savedOrderItems = await _orderInputRepository.read(_profile.id);
      final savedOrderCases = await _orderCasesRepository.read(_profile.id);
      final activeOrderCase = await _resolveActiveOrderCase(
        _profile.id,
        savedOrderItems,
        savedOrderCases,
      );
      if (shouldUseConfiguredOrderInputs && activeOrderCase != null) {
        final credentials = await _credentialVault.read(_profile.id);
        final configuredCases = await _loginCasesRepository.readOrMigrateLegacy(
          _profile.id,
          credentials,
        );
        final matchingLoginCases = configuredCases
            .where((c) => c.id == activeOrderCase.loginTestCaseId)
            .toList();
        final loginCase = matchingLoginCases.isEmpty
            ? null
            : matchingLoginCases.first;
        setState(() {
          _orderScenario = activeOrderCase.toScenario(
            ordersCount: configuredOrderCountOverride,
            loginId:
                loginCase?.username ?? (_loginId.isNotEmpty ? _loginId : null),
            password:
                loginCase?.password ??
                (_password.isNotEmpty ? _password : null),
            unlockPin:
                loginCase?.pin ?? (_unlockPin.isNotEmpty ? _unlockPin : null),
          );
        });
      }
    }
    if (!skipPreflight && !await _runManualPreflight()) return;
    if (_selectedSuiteId == 'order_checkout' &&
        _orderScenario.itemsForAllIterations().isEmpty) {
      _addMessage(
        'Order Inputs Required',
        shouldUseConfiguredOrderInputs
            ? 'Add and save at least one SKU in Settings → Inputs & Credentials → Order Inputs before running the order suite.'
            : 'The AI order plan did not contain any executable SKU items.',
        QaActivityKind.error,
      );
      return;
    }
    // Keep this check at the execution boundary. AI planning and manual mode
    // share this runner, so neither path can execute a production profile.
    if (_profile.isProduction) {
      _addMessage(
        'Execution Blocked',
        'Production environments are strictly prohibited for QA Agent execution.',
        QaActivityKind.error,
      );
      return;
    }
    final currentSuite = _activeSuite;

    if (!currentSuite.isImplemented) {
      _addMessage(
        'Suite Pending',
        'The ${currentSuite.title} runner is scheduled for the next phase.',
        QaActivityKind.info,
      );
      setState(() {
        _lastExecutionPassed = null;
        _wasAppClosedByUser = false;
        _lastExecutionDetails =
            'This test suite is currently planned for the upcoming release phase.';
      });
      return;
    }

    final activeSuite = _activeSuite;

    setState(() {
      _running = true;
      _lastExecutionPassed = null;
      _lastCleanupPassed = null;
      _lastExecutionDetails = null;
      _apiTraces = const <ApiTraceEvent>[];
      _wasAppClosedByUser = false;
      _stopRequested = false;
      _scenariosCompletedSoFar = <String>[];
      _executionSteps.clear();
      _executionSuiteTitle = activeSuite.title;
      _executionProfileLabel = _profile.label;

      _seedExecutionSteps(activeSuite);
    });
    _executionStopwatch
      ..reset()
      ..start();

    _addMessage(
      'Processing Suite',
      _targetMode == QaTargetMode.ssh
          ? 'Launching PenguinPOS on $_sshUser@$_sshHost at $_sshRemoteAppRoot for ${_profile.label}...'
          : 'Launching PenguinPOS via $_flutterPath at $_appRoot for ${_profile.label}...',
      QaActivityKind.info,
    );

    final stopwatch = Stopwatch()..start();
    final telemetryCollector = ApiTraceCollector(
      onTracesCaptured: (traces) {
        _queueApiTraces(traces);
      },
    );

    final registerInput = await _registerInputRepository.read(_profile.id);
    if (mounted) {
      setState(() {
        _openingFloatAmount = registerInput.openingFloatAmount;
      });
    }
    final orderScenario = _selectedSuiteId == 'order_checkout'
        ? OrderScenario(
            id: _orderScenario.id,
            name: _orderScenario.name,
            loginId: _loginId.isNotEmpty ? _loginId : null,
            password: _password.isNotEmpty ? _password : null,
            unlockPin: _unlockPin.isNotEmpty ? _unlockPin : null,
            items: _orderScenario.items,
            ordersCount: _orderScenario.ordersCount,
            inputSourceMode: _orderScenario.inputSourceMode,
            uiCustomMode: _orderScenario.uiCustomMode,
            perIterationItems: _orderScenario.perIterationItems,
            rawJson: _orderScenario.rawJson,
            rawCsv: _orderScenario.rawCsv,
            openingFloatAmount: registerInput.openingFloatAmount,
          )
        : null;
    final registerScenario = _selectedSuiteId == 'register'
        ? RegisterScenario(openingFloatAmount: registerInput.openingFloatAmount)
        : _selectedSuiteId == 'close_register'
        ? RegisterScenario(
            id: 'close_register',
            name: 'Close Register Flow',
            closeTotalAmount: _closeTotalAmount,
          )
        : null;
    final preparedExecution = PreparedExecution(
      plan: _manualExecutionPlan(),
      profileId: _profile.id,
      profileLabel: _profile.label,
      entity: _profile.entity,
      environment: _profile.environment,
      credentials: ExecutionCredentials(
        loginId: _loginId,
        password: _password,
        unlockPin: _unlockPin.isEmpty ? null : _unlockPin,
      ),
      appRoot: _appRoot,
      flutterExecutable: _flutterPath,
      targetMode: _targetMode == QaTargetMode.ssh
          ? ExecutionTargetMode.ssh
          : ExecutionTargetMode.local,
      sshConfig: _targetMode == QaTargetMode.ssh ? _sshExecutionConfig : null,
      configuredLoginCases: _configuredLoginCases,
      loginRepeatCount: _loginRepeatCount,
      orderScenario: orderScenario,
      registerScenario: registerScenario,
      telemetryCollector: telemetryCollector,
      noticeDisplayMode: _noticeDisplayMode,
    );

    try {
      final result = await _executionCoordinator.run(
        preparedExecution,
        callbacks: ExecutionCallbacks(
          onEvent: _recordExecutionEvent,
          onScenarioCompleted: _recordCompletedScenario,
          onOrderProgress: (completed, total) {
            _addMessage(
              'Order Progress',
              'Completed order $completed of $total back-to-back orders.',
              QaActivityKind.info,
            );
          },
        ),
      );
      stopwatch.stop();
      final loginResult = result.loginResult;
      final orderResult = result.orderResult;
      final registerResult = result.registerResult;
      if (orderScenario != null) {
        _addMessage(
          'Order Inputs Loaded',
          'Case ${orderScenario.id}: ${orderScenario.items.length} SKU item(s), ${orderScenario.ordersCount} iteration(s).',
          QaActivityKind.info,
        );
      }

      if (mounted) {
        setState(() {
          _lastOrderRunResult = orderResult;
          _lastRegisterRunResult = registerResult;
          _lastExecutionDuration = stopwatch.elapsed;
          _lastExecutionPassed = result.passed;
          _lastCleanupPassed = result.cleanupPassed;
          _lastLoginMetadata =
              loginResult?.metadata ?? const <String, Object?>{};
          _lastLoginSuiteResult = loginResult?.suiteResult;
          _wasAppClosedByUser = result.wasAppClosedByUser;
          _scenariosCompletedSoFar = result.completedScenarios;
          if (orderResult?.passed == true) {
            _scenariosCompletedSoFar = <String>[
              'Start Sale & Customer Handling',
              'SKU & Weighed Item Entry',
              'Cash Payment & Round-Off',
            ];
          }
          _lastExecutionDetails = result.passed
              ? orderResult != null
                    ? 'Punched ${orderResult.ordersCompleted} orders (${orderResult.totalItemsProcessed} total items). Aggregate payable: ₹${orderResult.aggregateTotalPayable.toStringAsFixed(2)} → Cash: ₹${orderResult.aggregatePayableAmount}.'
                    : registerResult != null
                    ? 'Successfully opened register with float amount ₹${registerResult.floatAmount}.'
                    : 'Successfully executed all scenarios: ${result.completedScenarios.join(', ')}.${result.cleanupPassed == false ? ' Cleanup failed; session isolation is not guaranteed.' : ''}'
              : (result.wasAppClosedByUser
                    ? _interruptionDetails(wasStopped: _stopRequested)
                    : (result.error ??
                          'The test driver did not reach the expected UI state.'));
        });
      }

      if (_wasAppClosedByUser) {
        _addMessage(
          _stopRequested ? 'Test Stopped' : 'Application Quit',
          _lastExecutionDetails ??
              'PenguinPOS stopped before the test completed.',
          QaActivityKind.info,
        );
      } else if (orderResult != null) {
        _addMessage(
          orderResult.passed ? 'Order Suite Passed 🎉' : 'Order Suite Failed ❌',
          orderResult.passed
              ? 'Punched ${orderResult.ordersCompleted} of ${orderResult.ordersTarget} orders (${orderResult.totalItemsProcessed} items) in ${stopwatch.elapsed.inSeconds}s (Cash: ₹${orderResult.aggregatePayableAmount}).'
              : (orderResult.error ?? 'Order checkout test failed.'),
          orderResult.passed ? QaActivityKind.success : QaActivityKind.error,
        );
      } else if (registerResult != null ||
          _selectedSuiteId == 'register' ||
          _selectedSuiteId == 'close_register') {
        final isClose = _selectedSuiteId == 'close_register';
        _addMessage(
          result.passed
              ? (isClose
                    ? 'Close Register Suite Passed 🎉'
                    : 'Open Register Suite Passed 🎉')
              : (isClose
                    ? 'Close Register Suite Failed ❌'
                    : 'Open Register Suite Failed ❌'),
          result.passed
              ? (isClose
                    ? 'Register closed successfully with total cash ₹${_closeTotalAmount.toInt()} in ${stopwatch.elapsed.inSeconds}s.'
                    : 'Register opened successfully with float ₹${_openingFloatAmount.toInt()} in ${stopwatch.elapsed.inSeconds}s.')
              : (result.error ??
                    (isClose
                        ? 'Close Register failed.'
                        : 'Open Register failed.')),
          result.passed ? QaActivityKind.success : QaActivityKind.error,
        );
      } else {
        final suite = loginResult?.suiteResult;
        final summaryDetails = suite != null
            ? '${suite.passedCount} of ${suite.totalCount} test cases passed (${suite.failedCount} failed) in ${stopwatch.elapsed.inSeconds}s.'
            : 'Completed in ${stopwatch.elapsed.inSeconds}s (${result.completedScenarios.length} scenarios).';
        _addMessage(
          result.passed ? 'Suite Passed 🎉' : 'Suite Failed ❌',
          result.passed
              ? summaryDetails
              : (result.error != null
                    ? '${result.error}\n$summaryDetails'
                    : summaryDetails),
          result.passed ? QaActivityKind.success : QaActivityKind.error,
        );
      }
    } catch (error) {
      stopwatch.stop();
      final errStr = error.toString();
      final isAppQuit =
          errStr.contains('Service has disappeared') ||
          errStr.contains('112') ||
          errStr.contains('SocketException') ||
          errStr.contains('Closed');

      setState(() {
        _lastExecutionDuration = stopwatch.elapsed;
        _lastExecutionPassed = false;
        _wasAppClosedByUser = isAppQuit || _stopRequested;
        _lastExecutionDetails = (isAppQuit || _stopRequested)
            ? _interruptionDetails(wasStopped: _stopRequested)
            : errStr;
      });

      if (isAppQuit || _stopRequested) {
        _addMessage(
          _stopRequested ? 'Test Stopped' : 'Application Quit',
          _lastExecutionDetails!,
          QaActivityKind.info,
        );
      } else {
        _addMessage('Suite Error', errStr, QaActivityKind.error);
      }
    } finally {
      _executionStopwatch.stop();
      // The final report must observe every execution event and the latest
      // cumulative telemetry snapshot, even when the 150ms render window has
      // not elapsed yet.
      _flushDashboardUpdates();
      if (mounted) {
        setState(() {
          _running = false;
        });

        // Layer 3: Auto-inject a rich test report message into the chat
        if (_aiModeEnabled && _lastExecutionPassed != null) {
          final scenarioResults = <AiScenarioResult>[];
          final failureDetail = _lastExecutionPassed == true
              ? null
              : (_lastExecutionDetails ??
                    'The test did not reach its expected outcome.');

          if (_selectedSuiteId == 'login_terminal' &&
              _lastLoginSuiteResult != null) {
            for (final caseResult in _lastLoginSuiteResult!.results) {
              scenarioResults.add(
                AiScenarioResult(
                  name: '${caseResult.testCase} (${caseResult.testCaseId})',
                  passed: caseResult.passed,
                  durationMs: caseResult.duration.inMilliseconds,
                  detail: caseResult.passed
                      ? (caseResult.description.isNotEmpty
                            ? caseResult.description
                            : null)
                      : (caseResult.failureReason ?? failureDetail),
                ),
              );
            }
          } else {
            final suiteScenarios = activeSuite.scenarios;
            for (final scenario in suiteScenarios) {
              final passed =
                  _scenariosCompletedSoFar.contains(scenario.name) ||
                  _scenariosCompletedSoFar.contains(scenario.id);
              scenarioResults.add(
                AiScenarioResult(
                  name: scenario.name,
                  passed: passed,
                  durationMs: passed
                      ? (stopwatch.elapsedMilliseconds ~/ suiteScenarios.length)
                      : 0,
                  detail: passed ? null : failureDetail,
                ),
              );
            }
          }

          final isOrderSuite = _selectedSuiteId == 'order_checkout';
          final allScenariosPassed = isOrderSuite
              ? (_lastOrderRunResult?.passed == true ||
                        _lastExecutionPassed == true) &&
                    !_wasAppClosedByUser &&
                    _lastCleanupPassed != false
              : _lastExecutionPassed! &&
                    !_wasAppClosedByUser &&
                    _lastCleanupPassed != false &&
                    scenarioResults.every((s) => s.passed);
          final orderResult = _lastOrderRunResult;
          final AiRichContent reportContent =
              isOrderSuite && orderResult != null
              ? _buildAiOrderReport(orderResult)
              : !isOrderSuite && _lastLoginSuiteResult != null
              ? AiRichLoginReport(
                  suiteTitle: _executionSuiteTitle,
                  profileLabel: _executionProfileLabel,
                  suite: _lastLoginSuiteResult!,
                  cleanupPassed: _lastCleanupPassed,
                  cleanupDetail: _lastExecutionDetails,
                )
              : AiRichGenUi(
                  document: _buildExecutionGenUi(
                    isOrder: false,
                    passed: allScenariosPassed,
                    durationMs: stopwatch.elapsedMilliseconds,
                    scenarioResults: scenarioResults,
                    orderResult: orderResult,
                    cleanupPassed: _lastCleanupPassed,
                    wasAppClosed: _wasAppClosedByUser,
                    loginMetadata: _lastLoginMetadata,
                  ),
                );

          final summaryLabel = _lastLoginSuiteResult != null
              ? ' (${_lastLoginSuiteResult!.passedCount}/${_lastLoginSuiteResult!.totalCount} cases passed)'
              : (orderResult != null
                    ? ' (${orderResult.ordersCompleted}/${orderResult.ordersTarget} orders completed)'
                    : '');
          final reportMessage = AiChatMessage(
            role: AiChatRole.assistant,
            text: allScenariosPassed
                ? 'Test suite completed successfully$summaryLabel.'
                : 'Test suite finished with failures$summaryLabel.',
            richContent: reportContent,
          );
          setState(() {
            _aiChatMessages.add(reportMessage);
          });
        }

        // Clear temporary execution steps so floating tracker box disappears
        setState(() {
          _executionSteps.clear();
        });
      }
    }
  }

  TestSuiteItem get _activeSuite => TestSuiteItem.availableSuites.firstWhere(
    (suite) => suite.id == _selectedSuiteId,
    orElse: () => TestSuiteItem.availableSuites.first,
  );

  void _seedExecutionSteps(TestSuiteItem suite) {
    if (_selectedSuiteId == 'login_terminal' &&
        _configuredLoginCases.isNotEmpty) {
      final enabledCases = _configuredLoginCases
          .where((c) => c.enabled)
          .toList();
      for (final testCase in enabledCases) {
        _executionSteps.add(
          AiExecutionStep(
            scenarioName: testCase.name,
            status: AiScenarioStatus.pending,
            totalScenarios: enabledCases.length,
            completedScenarios: 0,
          ),
        );
      }
      return;
    }
    for (final scenario in suite.scenarios) {
      _executionSteps.add(
        AiExecutionStep(
          scenarioName: scenario.name,
          status: AiScenarioStatus.pending,
          totalScenarios: suite.scenarios.length,
          completedScenarios: 0,
        ),
      );
    }
  }

  QaGenUiDocument _buildExecutionGenUi({
    required bool isOrder,
    required bool passed,
    required int durationMs,
    required List<AiScenarioResult> scenarioResults,
    required OrderRunResult? orderResult,
    required bool? cleanupPassed,
    required bool wasAppClosed,
    required Map<String, Object?> loginMetadata,
  }) {
    final timeline = isOrder
        ? _buildOrderTimeline(
            scenarioResults,
            orderResult: orderResult,
            traces: _apiTraces,
          )
        : _buildLoginTimeline(
            scenarioResults,
            cleanupPassed: cleanupPassed,
            wasAppClosed: wasAppClosed,
            metadata: loginMetadata,
            traces: _apiTraces,
          );
    final document = QaGenUiDocument.tryParse(<String, Object?>{
      'components': <Object?>[
        <String, Object?>{
          'component': isOrder ? 'orderPlan' : 'loginPlan',
          'title': isOrder ? 'Order execution' : 'Login & Terminal execution',
          'workflowLabel': _executionSuiteTitle,
          'profileLabel': _executionProfileLabel,
          'summary': isOrder && orderResult != null
              ? '${orderResult.ordersCompleted} of ${orderResult.ordersTarget} orders completed.'
              : (_lastLoginSuiteResult != null
                    ? '${_lastLoginSuiteResult!.passedCount} of ${_lastLoginSuiteResult!.totalCount} test cases passed.${_lastLoginSuiteResult!.failedCount > 0 ? ' (${_lastLoginSuiteResult!.failedCount} failed)' : ''}'
                    : 'Login, terminal selection, home verification, and logout cleanup.'),
        },
        <String, Object?>{
          'component': 'stepTimeline',
          'title': 'Execution timeline',
          'steps': timeline.map(_timelineJson).toList(growable: false),
        },
        <String, Object?>{
          'component': 'resultSummary',
          'title': passed ? 'Suite passed' : 'Suite finished with failures',
          'passed': passed,
          'summary':
              'Completed in ${durationMs < 1000 ? '${durationMs}ms' : '${(durationMs / 1000).toStringAsFixed(1)}s'}.',
        },
      ],
    });
    return document!;
  }

  AiRichOrderReport _buildAiOrderReport(OrderRunResult result) {
    return AiRichOrderReport(
      suiteTitle: _executionSuiteTitle,
      profileLabel: _executionProfileLabel,
      passed: result.passed,
      totalDurationMs: result.finishedAt
          .difference(result.startedAt)
          .inMilliseconds,
      aggregateTotalPayable: result.aggregateTotalPayable,
      aggregatePayableAmount: result.aggregatePayableAmount,
      orders: result.loopMetrics
          .map(
            (loop) => AiOrderResult(
              orderNumber: loop.loopIndex,
              itemSummary:
                  '${loop.itemsCount} SKU item${loop.itemsCount == 1 ? '' : 's'}',
              passed: loop.passed,
              durationMs: loop.durationMs,
              cashAmount: loop.payableCash,
              totalPayable: loop.totalPayable,
              orderNumberLabel: loop.orderNumber,
              error: loop.error,
              skuResults: loop.skuResults
                  .map(
                    (sku) => AiOrderSkuResult(
                      sku: sku.sku,
                      type: sku.type,
                      entryMode: sku.entryMode,
                      passed: sku.passed,
                      weight: sku.weight,
                      error: sku.error,
                    ),
                  )
                  .toList(growable: false),
              stageResults: loop.stageResults
                  .map(
                    (stage) => AiOrderStageResult(
                      name: stage.name,
                      passed: stage.passed,
                      details: stage.details,
                    ),
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
      testChecks: const <AiScenarioResult>[],
    );
  }

  Map<String, Object?> _timelineJson(
    AiScenarioResult result,
  ) => <String, Object?>{
    'label': result.name,
    'status': result.detail?.startsWith('__pending__') == true
        ? 'pending'
        : result.detail?.startsWith('__skipped__') == true
        ? 'skipped'
        : (result.passed ? 'passed' : 'failed'),
    if (result.durationMs >= 0) 'durationMs': result.durationMs,
    if (result.detail != null &&
        !result.detail!.startsWith('__pending__') &&
        !result.detail!.startsWith('__skipped__'))
      'detail': result.detail,
    if (result.detail?.startsWith('__skipped__: ') == true)
      'detail': result.detail!.substring('__skipped__: '.length),
    if (result.children.isNotEmpty)
      'children': result.children.map(_timelineJson).toList(growable: false),
  };

  List<AiScenarioResult> _buildOrderTimeline(
    List<AiScenarioResult> scenarioResults, {
    required OrderRunResult? orderResult,
    required List<ApiTraceEvent> traces,
  }) {
    AiScenarioResult stage(
      String name,
      bool passed, {
      String? detail,
      List<AiScenarioResult> children = const <AiScenarioResult>[],
    }) => AiScenarioResult(
      name: name,
      passed: passed,
      durationMs: -1,
      detail: detail,
      children: children,
    );

    AiScenarioResult api(ApiTraceEvent trace) => AiScenarioResult(
      name: '${trace.method} ${trace.route}',
      passed: trace.result.name == 'success',
      durationMs: trace.durationMs,
      detail:
          '${trace.statusCode ?? '-'} · ${trace.mode.name == 'unknown' ? 'target' : trace.mode.name}',
    );

    final initialScreen = orderResult?.metadata['initial_screen'];
    final loggedIn =
        orderResult?.metadata['initial_session_state'] == 'logged_in';
    final loginApis = traces
        .where(
          (trace) =>
              trace.route.toLowerCase().contains('/login') ||
              trace.route.toLowerCase().contains('terminal-selection'),
        )
        .map(api)
        .toList(growable: false);
    final splashApis = traces
        .where(
          (trace) =>
              trace.route.toLowerCase().contains('device-config') ||
              trace.route.toLowerCase().contains('terminal-events'),
        )
        .map(api)
        .toList(growable: false);
    final orderSteps = <AiScenarioResult>[];
    final metrics = orderResult?.loopMetrics ?? const <OrderLoopMetrics>[];
    for (final metric in metrics) {
      final children = metric.stepMetrics
          .map(
            (step) => AiScenarioResult(
              name: step.stepName,
              passed: true,
              durationMs: step.uiRenderTimeMs,
              detail: step.apiTelemetry == null
                  ? null
                  : '${step.apiTelemetry!.statusCode} · API ${step.apiTelemetry!.responseTimeMs}ms',
            ),
          )
          .toList(growable: false);
      orderSteps.add(
        stage(
          'Order ${metric.loopIndex}',
          true,
          detail: '${metric.itemsCount} items · ₹${metric.payableCash} cash',
          children: children,
        ),
      );
    }
    if (orderSteps.isEmpty) {
      orderSteps.addAll(
        scenarioResults.map(
          (result) => stage(result.name, result.passed, detail: result.detail),
        ),
      );
    }

    return <AiScenarioResult>[
      stage(
        'Splash Screen',
        splashApis.isNotEmpty && splashApis.every((item) => item.passed),
        children: splashApis,
      ),
      stage(
        'Check If Logged In',
        orderResult?.metadata.isNotEmpty == true,
        detail: loggedIn
            ? 'Already logged in on ${initialScreen ?? 'authenticated screen'} — login and terminal selection skipped.'
            : 'Login screen detected — login and terminal selection required.',
      ),
      if (!loggedIn)
        stage(
          'Login',
          loginApis
              .where((item) => item.name.contains('/login'))
              .every((item) => item.passed),
          children: loginApis
              .where((item) => item.name.contains('/login'))
              .toList(growable: false),
        ),
      if (!loggedIn)
        stage(
          'Terminal Selection',
          loginApis
              .where((item) => item.name.contains('terminal-selection'))
              .every((item) => item.passed),
          children: loginApis
              .where((item) => item.name.contains('terminal-selection'))
              .toList(growable: false),
        ),
      stage(
        'Continue With Order',
        orderSteps.every((item) => item.passed),
        children: orderSteps,
      ),
    ];
  }

  List<AiScenarioResult> _buildLoginTimeline(
    List<AiScenarioResult> scenarioResults, {
    required bool? cleanupPassed,
    required bool wasAppClosed,
    required Map<String, Object?> metadata,
    required List<ApiTraceEvent> traces,
  }) {
    AiScenarioResult status(
      String name,
      bool passed, {
      bool observed = true,
      String? detail,
      List<AiScenarioResult> children = const <AiScenarioResult>[],
    }) => AiScenarioResult(
      name: name,
      passed: passed,
      // Stage/decision rows are labels, not timed API calls. Durations are
      // attached only to the concrete API rows below them in the flat chain.
      durationMs: -1,
      detail: detail ?? (observed ? null : '__pending__'),
      children: children,
    );
    final completed = _scenariosCompletedSoFar.toSet();
    final failure = scenarioResults
        .where((item) => !item.passed && item.detail != null)
        .map((item) => item.detail!)
        .firstOrNull;
    List<AiScenarioResult> apiRows(String category) {
      final selected = traces.where((trace) {
        final route = trace.route.toLowerCase();
        return switch (category) {
          'splash' => route.contains('splash'),
          'device_config' =>
            route.contains('device-config') && !route.contains('/modes'),
          'device_modes' =>
            route.contains('device-config') && route.contains('/modes'),
          'terminal' => route.contains('terminal-events'),
          'auth' =>
            route.contains('/login') ||
                route.contains('/logout') ||
                route.contains('terminal-selection'),
          _ => false,
        };
      });
      return selected
          .map(
            (trace) => AiScenarioResult(
              name: '${trace.method} ${trace.route}',
              passed: trace.result.name == 'success',
              durationMs: trace.durationMs,
              detail:
                  '${trace.statusCode ?? '-'} · ${trace.mode.name == 'unknown' ? 'target' : trace.mode.name}',
            ),
          )
          .toList(growable: false);
    }

    final initialState = metadata['initial_session_state'];
    final splashApis = <AiScenarioResult>[
      ...apiRows('device_config'),
      ...apiRows('device_modes'),
      ...apiRows('terminal'),
    ];
    final logoutApis = apiRows('auth')
        .where((item) => item.name.toLowerCase().contains('/logout'))
        .toList(growable: false);
    final initialLogout = initialState == 'logged_in' && logoutApis.isNotEmpty
        ? <AiScenarioResult>[logoutApis.first]
        : const <AiScenarioResult>[];
    final finalLogout = logoutApis.length > 1
        ? <AiScenarioResult>[logoutApis.last]
        : (initialState == 'logged_out' && logoutApis.isNotEmpty
              ? <AiScenarioResult>[logoutApis.last]
              : const <AiScenarioResult>[]);
    final loginApis = apiRows('auth')
        .where((item) => item.name.toLowerCase().contains('/login'))
        .toList(growable: false);
    final terminalSelectionApis = apiRows('auth')
        .where((item) => item.name.toLowerCase().contains('terminal-selection'))
        .toList(growable: false);

    if (_lastLoginSuiteResult != null &&
        _lastLoginSuiteResult!.results.isNotEmpty) {
      final caseSteps = <AiScenarioResult>[];
      for (final res in _lastLoginSuiteResult!.results) {
        final caseLoginApis =
            res.testCaseId == 'legacy-valid-login' ||
                res.testCase.toLowerCase().contains('valid') ||
                res.status == LoginTestCaseStatus.passed
            ? loginApis
            : const <AiScenarioResult>[];
        caseSteps.add(
          status(
            '${res.testCase} (${res.testCaseId})',
            res.passed,
            observed:
                res.status != LoginTestCaseStatus.notExecuted &&
                res.status != LoginTestCaseStatus.pending,
            detail:
                res.failureReason ??
                (res.description.isNotEmpty ? res.description : null),
            children: caseLoginApis,
          ),
        );
      }
      return <AiScenarioResult>[
        status(
          'Splash Screen',
          splashApis.isNotEmpty && splashApis.every((step) => step.passed),
          observed: splashApis.isNotEmpty,
          children: splashApis,
        ),
        ...caseSteps,
        status(
          'Logout Cleanup',
          cleanupPassed == true,
          observed: cleanupPassed != null || wasAppClosed,
          detail: cleanupPassed == true
              ? null
              : (wasAppClosed
                    ? 'PenguinPOS was quit before logout.'
                    : 'Logout was not completed.'),
          children: finalLogout,
        ),
      ];
    }

    return <AiScenarioResult>[
      status(
        'Splash Screen',
        splashApis.isNotEmpty && splashApis.every((step) => step.passed),
        observed: splashApis.isNotEmpty,
        children: splashApis,
      ),
      status(
        'Check If Logged In',
        initialState != null,
        observed: initialState != null || wasAppClosed,
        detail: initialState == 'logged_out'
            ? '__skipped__: Already logged out — no logout API required.'
            : (initialState == 'logged_in'
                  ? 'Existing session detected — initial logout required.'
                  : (wasAppClosed
                        ? 'PenguinPOS was quit before the initial logout.'
                        : null)),
        children: initialLogout.isEmpty
            ? const <AiScenarioResult>[]
            : <AiScenarioResult>[
                status(
                  'Logging Out User',
                  initialLogout.every((step) => step.passed),
                  children: initialLogout,
                ),
              ],
      ),
      status(
        'Login',
        completed.contains('Valid Login Flow') ||
            traces.any(
              (trace) =>
                  trace.route.contains('/login') && trace.statusCode == 201,
            ),
        detail: failure,
        children: loginApis,
      ),
      status(
        'Terminal Selection',
        completed.contains('Select Terminal') ||
            terminalSelectionApis.isNotEmpty,
        observed:
            completed.contains('Select Terminal') ||
            terminalSelectionApis.isNotEmpty,
        detail: failure,
        children: terminalSelectionApis,
      ),
      status(
        'Logout',
        cleanupPassed == true,
        observed: cleanupPassed != null || wasAppClosed,
        detail: cleanupPassed == true
            ? null
            : (wasAppClosed
                  ? 'PenguinPOS was quit before logout.'
                  : 'Logout was not completed.'),
        children: finalLogout,
      ),
    ];
  }

  void _addMessage(String title, String body, QaActivityKind kind) {
    _pendingMessages.add(QaActivityMessage(title, body, kind));
    _scheduleDashboardUpdate();
  }

  @override
  void dispose() {
    _dashboardUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_preferencesLoaded) {
      return _buildLoadingScreen();
    }

    return Stack(
      children: <Widget>[
        ExcludeSemantics(
          excluding: _showSettingsScreen,
          child: IgnorePointer(
            ignoring: _showSettingsScreen,
            child: Scaffold(
              backgroundColor: _aiModeEnabled
                  ? const Color(0xFFFCFCFD)
                  : const Color(0xFFF1F5F9),
              body: _aiModeEnabled
                  ? _buildAssistantWorkspace()
                  : Column(
                      children: <Widget>[
                        Expanded(child: _buildManualMode()),
                        AssistantLogDrawer(
                          activityMessages: _messages,
                          apiTraces: const <ApiTraceEvent>[],
                          expanded: _terminalExpanded,
                          onToggleExpanded: () => setState(
                            () => _terminalExpanded = !_terminalExpanded,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        if (_showSettingsScreen)
          Positioned.fill(
            child: FocusScope(
              autofocus: true,
              child: FocusTraversalGroup(child: _buildSettingsScreen()),
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingScreen() => const Scaffold(
    backgroundColor: Color(0xFFFCFCFD),
    body: Center(
      child: SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );

  Future<String> _testSshConnectionFromSettings(
    QaSshTarget target,
    String password,
  ) async {
    final config = SshExecutionConfig(
      username: target.username,
      host: target.host,
      port: int.tryParse(target.port) ?? 22,
      identityFile: target.identityFile.isEmpty ? null : target.identityFile,
      remoteAppRoot: target.appRoot,
      remoteFlutterExecutable: target.flutterPath.isEmpty
          ? 'flutter'
          : target.flutterPath,
      password: password.isEmpty ? null : password,
    );
    final connected = widget.sshConnectionTester == null
        ? await _performSshConnectionTest(config)
        : await widget.sshConnectionTester!(config);
    return connected
        ? 'SSH connection successful.'
        : 'SSH connection failed. No application was launched.';
  }

  Widget _buildSettingsScreen() => QaSettingsScreen(
    profiles: _profiles,
    activeProfile: _profile,
    aiModelConfig: _aiModelConfig,
    noticeDisplayMode: _noticeDisplayMode,
    flutterPath: _flutterPath,
    appRoot: _appRoot,
    onProfileSelected: _selectProfile,
    onProfilesUpdated: (profiles) => setState(() => _profiles = profiles),
    onAiModelConfigUpdated: (config) {
      setState(() {
        _aiModelConfig = config;
        _aiModelConnected = false;
      });
      unawaited(_refreshAiModelConnection(config));
    },
    onNoticeDisplayModeUpdated: (mode) {
      setState(() => _noticeDisplayMode = mode);
      unawaited(_preferences.saveNoticeDisplayMode(mode));
    },
    onSystemPathsUpdated: (flutterPath, appRoot) {
      if (!mounted) return;
      setState(() {
        _flutterPath = flutterPath;
        _appRoot = appRoot;
      });
    },
    onTestSshConnection: _testSshConnectionFromSettings,
    onClose: () async {
      final target = await _preferences.loadSshTarget(profileId: _profile.id);
      final sshPassword = await _preferences.loadSshPassword(
        profileId: _profile.id,
      );
      final credentials = await _credentialVault.read(_profile.id);
      final cases = await _loginCasesRepository.readOrMigrateLegacy(
        _profile.id,
        credentials,
      );
      final savedOrderItems = await _orderInputRepository.read(_profile.id);
      final savedOrderCases = await _orderCasesRepository.read(_profile.id);
      final activeOrderCase = await _resolveActiveOrderCase(
        _profile.id,
        savedOrderItems,
        savedOrderCases,
      );
      final registerInput = await _registerInputRepository.read(_profile.id);
      if (!mounted) return;
      setState(() {
        _showSettingsScreen = false;
        _openingFloatAmount = registerInput.openingFloatAmount;
        _targetMode = target.enabled ? QaTargetMode.ssh : QaTargetMode.local;
        _sshUser = target.username;
        _sshHost = target.host;
        _sshPort = target.port;
        _sshIdentityFile = target.identityFile;
        _sshRemoteAppRoot = target.appRoot;
        _sshRemoteFlutterPath = target.flutterPath;
        _sshPassword = sshPassword;
        _loginId = credentials.loginId;
        _password = credentials.password;
        _unlockPin = credentials.unlockPin;
        _configuredLoginCases = cases;
        if (activeOrderCase != null) {
          final loginCase = cases.where(
            (candidate) => candidate.id == activeOrderCase.loginTestCaseId,
          );
          final matchingLoginCase = loginCase.isEmpty ? null : loginCase.first;
          _orderScenario = activeOrderCase.toScenario(
            loginId: matchingLoginCase?.username,
            password: matchingLoginCase?.password,
            unlockPin: matchingLoginCase?.pin,
          );
        }
      });
    },
  );

  Widget _buildAssistantWorkspace() => AiAssistantWorkspace(
    modelConfigured: _aiModelConnected,
    running: _running,
    sshTargetEnabled: _targetMode == QaTargetMode.ssh,
    onSshTargetChanged: (enabled) =>
        _setTargetMode(enabled ? QaTargetMode.ssh : QaTargetMode.local),
    messages: _aiChatMessages,
    onAddMessage: (msg) {
      if (mounted) {
        setState(() => _aiChatMessages.add(msg));
      }
    },
    onTruncateMessages: (index) {
      if (mounted && index >= 0 && index < _aiChatMessages.length) {
        setState(
          () => _aiChatMessages.removeRange(index, _aiChatMessages.length),
        );
      }
    },
    onPlanningStateChanged: (waiting) {
      if (mounted) {
        setState(() => _aiPlanningWaiting = waiting);
      }
    },
    activityMessages: _messages,
    apiTraces: _apiTraces,
    executionSteps: _executionSteps,
    executionSuiteTitle: _executionSuiteTitle,
    executionProfileLabel: _executionProfileLabel,
    onSend: _respondToAi,
    onRunPlan: _runAiPlan,
    onOpenPlanInManualMode: _openAiPlanInManualMode,
    onStop: _stopRunningSuite,
    onOpenSettings: _openSettingsDialog,
    onExitAiMode: () => _setAiModeEnabled(false),
  );

  Widget _buildManualMode() => Row(
    children: <Widget>[
      SideNav(
        suites: TestSuiteItem.availableSuites,
        selectedSuiteId: _selectedSuiteId,
        onSelectSuite: _selectSuite,
        onNewSuite: _showCustomSuiteBuilderNotice,
        onOpenSettings: _openSettingsDialog,
        onOpenSupport: _openSupportDialog,
        activeProfileLabel: _profile.label,
        targetMode: _targetMode,
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: _buildManualModeToolbar(),
              ),
              const SizedBox(height: 10),
              Expanded(child: _buildSuiteWorkspace()),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _buildManualModeToolbar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text(
          'Environment:',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 170, child: _buildProfileSelector()),
        const SizedBox(width: 12),
        _buildTargetModeToggle(),
        const SizedBox(width: 12),
        TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF475569),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          onPressed: _openSettingsDialog,
          icon: const Icon(Icons.settings_outlined, size: 16),
          label: const Text(
            'Settings',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 8),
        const VerticalDivider(
          width: 1,
          indent: 4,
          endIndent: 4,
          color: Color(0xFFE2E8F0),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'Manual',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 4),
            Switch.adaptive(
              value: false,
              onChanged: _running ? null : _setAiModeEnabled,
            ),
            const SizedBox(width: 4),
            const Text(
              'AI',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildTargetModeToggle() => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(
        _targetMode == QaTargetMode.ssh ? 'SSH' : 'Local',
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF475569),
        ),
      ),
      const SizedBox(width: 4),
      Switch.adaptive(
        value: _targetMode == QaTargetMode.ssh,
        onChanged: _running
            ? null
            : (enabled) => _setTargetMode(
                enabled ? QaTargetMode.ssh : QaTargetMode.local,
              ),
      ),
    ],
  );

  Widget _buildProfileSelector() => DropdownButtonFormField<QaProfile>(
    initialValue: _profile,
    isDense: true,
    decoration: InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
    ),
    items: _profiles
        .map(
          (profile) => DropdownMenuItem<QaProfile>(
            value: profile,
            child: Text(profile.label, style: const TextStyle(fontSize: 12.5)),
          ),
        )
        .toList(),
    onChanged: _running
        ? null
        : (profile) {
            if (profile != null) _selectProfile(profile);
          },
  );

  Widget _buildSuiteWorkspace() {
    final suite = _activeSuite;
    if (_selectedSuiteId == 'order_checkout') {
      return OrderSuiteScreen(
        suite: suite,
        currentProfile: _profile,
        targetMode: _targetMode,
        flutterPath: _flutterPath,
        appRoot: _appRoot,
        running: _running,
        lastExecutionPassed: _lastExecutionPassed,
        lastExecutionDuration: _lastExecutionDuration,
        lastExecutionDetails: _lastExecutionDetails,
        wasAppClosedByUser: _wasAppClosedByUser,
        scenariosCompleted: _scenariosCompletedSoFar,
        orderScenario: _orderScenario,
        lastOrderRunResult: _lastOrderRunResult,
        onUpdateScenario: (scenario) => setState(() {
          _orderScenario = scenario;
          _activeInputSource = AiInputSource.user;
        }),
        onRunSuite: _runSelectedSuite,
        onStopSuite: _stopRunningSuite,
      );
    }
    if (_selectedSuiteId == 'close_register') {
      return CloseRegisterSuiteScreen(
        suite: suite,
        currentProfile: _profile,
        targetMode: _targetMode,
        flutterPath: _flutterPath,
        appRoot: _appRoot,
        running: _running,
        lastExecutionPassed: _lastExecutionPassed,
        lastExecutionDuration: _lastExecutionDuration,
        lastExecutionDetails: _lastExecutionDetails,
        lastRegisterRunResult: _lastRegisterRunResult,
        wasAppClosedByUser: _wasAppClosedByUser,
        scenariosCompleted: _scenariosCompletedSoFar,
        closeTotalAmount: _closeTotalAmount,
        onTotalAmountChanged: (val) {
          setState(() {
            _closeTotalAmount = val;
          });
          _registerInputRepository.write(
            _profile.id,
            QaRegisterInput(
              openingFloatAmount: _openingFloatAmount,
              closeTotalAmount: val,
            ),
          );
        },
        onRunSuite: _runSelectedSuite,
        onStopSuite: _stopRunningSuite,
        onOpenSettings: _openSettingsDialog,
      );
    }
    if (_selectedSuiteId == 'register') {
      return RegisterSuiteScreen(
        suite: suite,
        currentProfile: _profile,
        targetMode: _targetMode,
        flutterPath: _flutterPath,
        appRoot: _appRoot,
        running: _running,
        lastExecutionPassed: _lastExecutionPassed,
        lastExecutionDuration: _lastExecutionDuration,
        lastExecutionDetails: _lastExecutionDetails,
        lastRegisterRunResult: _lastRegisterRunResult,
        wasAppClosedByUser: _wasAppClosedByUser,
        scenariosCompleted: _scenariosCompletedSoFar,
        openingFloatAmount: _openingFloatAmount,
        onRunSuite: _runSelectedSuite,
        onStopSuite: _stopRunningSuite,
        onOpenSettings: _openSettingsDialog,
      );
    }
    return LoginSuiteScreen(
      suite: suite,
      currentProfile: _profile,
      loginId: _loginId,
      password: _password,
      targetMode: _targetMode,
      flutterPath: _flutterPath,
      appRoot: _appRoot,
      running: _running,
      lastExecutionPassed: _lastExecutionPassed,
      lastExecutionDuration: _lastExecutionDuration,
      lastExecutionDetails: _lastExecutionDetails,
      wasAppClosedByUser: _wasAppClosedByUser,
      scenariosCompleted: _scenariosCompletedSoFar,
      onLoginIdChanged: (loginId) => setState(() => _loginId = loginId),
      onPasswordChanged: (password) => setState(() => _password = password),
      onRunSuite: _runSelectedSuite,
      onStopSuite: _stopRunningSuite,
      configuredCases: _configuredLoginCases,
      lastLoginSuiteResult: _lastLoginSuiteResult,
    );
  }

  void _selectSuite(String suiteId) {
    setState(() {
      _selectedSuiteId = suiteId;
      _activeInputSource = AiInputSource.settings;
      _lastExecutionPassed = null;
      _wasAppClosedByUser = false;
      _lastExecutionDetails = null;
      _scenariosCompletedSoFar = <String>[];
    });
    if (suiteId == 'register' || suiteId == 'close_register') {
      _registerInputRepository.read(_profile.id).then((input) {
        if (mounted) {
          setState(() {
            _openingFloatAmount = input.openingFloatAmount;
            _closeTotalAmount = input.closeTotalAmount;
          });
        }
      });
    }
  }

  void _showCustomSuiteBuilderNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Custom suite builder is planned for upcoming release.'),
      ),
    );
  }
}
