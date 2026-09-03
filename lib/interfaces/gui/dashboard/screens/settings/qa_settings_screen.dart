import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/ai/providers/openai_compatible_provider.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_credential_vault.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_login_test_case_repository.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_order_input_repository.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_order_test_case_repository.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/repository/qa_target_preferences_repository.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/ai_models_settings_tab.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/credentials_settings_tab.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/profiles_settings_tab.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/qa_notices_settings_tab.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/settings_sidebar.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/ssh_settings_tab.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/support_settings_tab.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/system_paths_settings_tab.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/inputs_credentials_workspace.dart';

/// Full-screen modular Settings workspace with left navigation sidebar and right detail views.
class QaSettingsScreen extends StatefulWidget {
  const QaSettingsScreen({
    super.key,
    required this.profiles,
    required this.activeProfile,
    required this.aiModelConfig,
    required this.noticeDisplayMode,
    required this.flutterPath,
    required this.appRoot,
    required this.onProfileSelected,
    required this.onProfilesUpdated,
    required this.onAiModelConfigUpdated,
    required this.onNoticeDisplayModeUpdated,
    required this.onClose,
    this.onTestSshConnection,
    this.onSystemPathsUpdated,
  });

  final List<QaProfile> profiles;
  final QaProfile activeProfile;
  final AiModelConfig aiModelConfig;
  final QaTestNoticeDisplayMode noticeDisplayMode;
  final String flutterPath;
  final String appRoot;

  /// Optional seam for the runtime SSH layer. This settings slice does not
  /// open sockets or launch processes itself.
  final Future<String> Function(QaSshTarget target, String password)?
  onTestSshConnection;
  final void Function(String flutterPath, String appRoot)? onSystemPathsUpdated;

  final ValueChanged<QaProfile> onProfileSelected;
  final ValueChanged<List<QaProfile>> onProfilesUpdated;
  final ValueChanged<AiModelConfig> onAiModelConfigUpdated;
  final ValueChanged<QaTestNoticeDisplayMode> onNoticeDisplayModeUpdated;
  final VoidCallback onClose;

  @override
  State<QaSettingsScreen> createState() => _QaSettingsScreenState();
}

class _QaSettingsScreenState extends State<QaSettingsScreen> {
  final _credentialVault = QaCredentialVault();
  final _preferencesRepo = QaTargetPreferencesRepository();
  final _loginCasesRepo = SharedPreferencesQaLoginTestCaseRepository();
  final _orderInputRepo = SharedPreferencesQaOrderInputRepository();
  final _orderCasesRepo = SharedPreferencesQaOrderTestCaseRepository();

  SettingsTab _activeTab = SettingsTab.credentials;

  // Credentials tab state
  late QaProfile _selectedProfile;
  final _loginIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _unlockPinController = TextEditingController();
  bool _savingCredentials = false;

  // Profiles tab state
  final _newLabelController = TextEditingController();
  final _newEntityController = TextEditingController();
  final _newEnvController = TextEditingController();
  final _newAliasesController = TextEditingController();

  // AI Models tab state
  final _modelLabelController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _modelNameController = TextEditingController();
  final _maxOutputTokensController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _isCloud = false;
  bool _enableVerboseReasoning = false;
  late QaTestNoticeDisplayMode _noticeDisplayMode;
  bool _testingConnection = false;
  String? _testConnectionStatus;

  // System Paths state
  late String _flutterPath;
  late String _appRoot;

  // SSH target state
  bool _sshEnabled = false;
  final _sshHostController = TextEditingController();
  final _sshUsernameController = TextEditingController();
  final _sshPasswordController = TextEditingController();
  final _sshPortController = TextEditingController();
  final _sshIdentityFileController = TextEditingController();
  final _sshAppRootController = TextEditingController();
  final _sshFlutterPathController = TextEditingController();
  bool _testingSshConnection = false;
  String? _sshConnectionStatus;

  @override
  void initState() {
    super.initState();
    _selectedProfile = widget.activeProfile;
    _isCloud = widget.aiModelConfig.isCloud;
    _enableVerboseReasoning = widget.aiModelConfig.enableVerboseReasoning;
    _noticeDisplayMode = widget.noticeDisplayMode;
    _modelLabelController.text = widget.aiModelConfig.label;
    _baseUrlController.text = widget.aiModelConfig.baseUrl;
    _modelNameController.text = widget.aiModelConfig.model;
    _maxOutputTokensController.text = widget.aiModelConfig.maxOutputTokens
        .toString();
    _flutterPath = widget.flutterPath;
    _appRoot = widget.appRoot;

    _loadProfileCredentials(_selectedProfile);
    _loadApiKey();
    _loadSshSettings();
  }

  @override
  void dispose() {
    _loginIdController.dispose();
    _passwordController.dispose();
    _unlockPinController.dispose();
    _newLabelController.dispose();
    _newEntityController.dispose();
    _newEnvController.dispose();
    _newAliasesController.dispose();
    _modelLabelController.dispose();
    _baseUrlController.dispose();
    _modelNameController.dispose();
    _maxOutputTokensController.dispose();
    _apiKeyController.dispose();
    _sshHostController.dispose();
    _sshUsernameController.dispose();
    _sshPasswordController.dispose();
    _sshPortController.dispose();
    _sshIdentityFileController.dispose();
    _sshAppRootController.dispose();
    _sshFlutterPathController.dispose();
    super.dispose();
  }

  Future<void> _loadSshSettings([QaProfile? profile]) async {
    final selected = profile ?? _selectedProfile;
    final target = await _preferencesRepo.loadSshTarget(profileId: selected.id);
    final password = await _preferencesRepo.loadSshPassword(
      profileId: selected.id,
    );
    if (!mounted) return;
    setState(() {
      _sshEnabled = target.enabled;
      _sshHostController.text = target.host;
      _sshUsernameController.text = target.username;
      _sshPortController.text = target.port;
      _sshIdentityFileController.text = target.identityFile;
      _sshAppRootController.text = target.appRoot;
      _sshFlutterPathController.text = target.flutterPath;
      _sshPasswordController.text = password;
    });
  }

  Future<void> _loadProfileCredentials(QaProfile profile) async {
    final credentials = await _credentialVault.read(profile.id);
    if (!mounted) return;
    setState(() {
      _loginIdController.text = credentials.loginId;
      _passwordController.text = credentials.password;
      _unlockPinController.text = credentials.unlockPin;
    });
  }

  Future<void> _loadApiKey() async {
    final key = await _credentialVault.readAiApiKey();
    if (!mounted) return;
    setState(() {
      _apiKeyController.text = key;
    });
  }

  Future<void> _saveCredentials() async {
    setState(() => _savingCredentials = true);
    final credentials = QaStoredCredentials(
      loginId: _loginIdController.text.trim(),
      password: _passwordController.text,
      unlockPin: _unlockPinController.text.trim(),
    );
    await _credentialVault.write(_selectedProfile.id, credentials);
    await _preferencesRepo.saveSelectedProfileId(_selectedProfile.id);
    await _preferencesRepo.markInitialSetupComplete();

    widget.onProfileSelected(_selectedProfile);

    if (!mounted) return;
    setState(() => _savingCredentials = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved credentials for ${_selectedProfile.label}.'),
        backgroundColor: const Color(0xFF658A7A),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _addProfile() async {
    final label = _newLabelController.text.trim();
    final entity = _newEntityController.text.trim().toLowerCase();
    final env = _newEnvController.text.trim().toLowerCase();
    if (label.isEmpty || entity.isEmpty || env.isEmpty) return;

    final id = '$entity-$env'.replaceAll(RegExp(r'[^a-z0-9-]'), '-');
    final aliases = _newAliasesController.text
        .split(',')
        .map((a) => a.trim().toLowerCase())
        .where((a) => a.isNotEmpty)
        .toSet()
        .toList();

    final nextProfiles = List<QaProfile>.from(widget.profiles)
      ..removeWhere((p) => p.id == id)
      ..add(
        QaProfile(
          id: id,
          label: label,
          entity: entity,
          environment: env,
          aliases: <String>[id, ...aliases],
        ),
      );

    await _preferencesRepo.saveProfiles(nextProfiles);
    await _preferencesRepo.markInitialSetupComplete();
    widget.onProfilesUpdated(nextProfiles);

    _newLabelController.clear();
    _newEntityController.clear();
    _newEnvController.clear();
    _newAliasesController.clear();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Created profile "$label".'),
        backgroundColor: const Color(0xFF658A7A),
      ),
    );
  }

  Future<void> _deleteProfile(QaProfile profile) async {
    final next = List<QaProfile>.from(widget.profiles)
      ..removeWhere((candidate) => candidate.id == profile.id);
    await _preferencesRepo.saveProfiles(next);
    widget.onProfilesUpdated(next);
  }

  Future<void> _testAiConnection() async {
    setState(() {
      _testingConnection = true;
      _testConnectionStatus = 'Connecting to AI model endpoint…';
    });

    final draft = AiModelConfig(
      label: _modelLabelController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      model: _modelNameController.text.trim(),
      maxOutputTokens: _readMaxOutputTokens(),
      isCloud: _isCloud,
      enableVerboseReasoning: _enableVerboseReasoning,
    );

    try {
      final models = await OpenAiCompatibleProvider(
        config: draft,
        apiKey: _apiKeyController.text,
      ).listModels();

      if (!mounted) return;
      setState(() {
        _testConnectionStatus = models.isEmpty
            ? 'No model connected. Server returned 0 models.'
            : 'Connected successfully! Models found: ${models.take(4).join(', ')}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testConnectionStatus = 'Connection error: $e';
      });
    } finally {
      if (mounted) setState(() => _testingConnection = false);
    }
  }

  Future<void> _saveAiModel() async {
    final config = AiModelConfig(
      label: _modelLabelController.text.trim().isEmpty
          ? 'OpenAI-compatible'
          : _modelLabelController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      model: _modelNameController.text.trim(),
      maxOutputTokens: _readMaxOutputTokens(),
      isCloud: _isCloud,
      enableVerboseReasoning: _enableVerboseReasoning,
    );

    await _preferencesRepo.saveAiModelConfig(config);
    await _credentialVault.writeAiApiKey(_apiKeyController.text.trim());
    await _preferencesRepo.markInitialSetupComplete();

    widget.onAiModelConfigUpdated(config);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AI model settings updated successfully.'),
        backgroundColor: Color(0xFF658A7A),
      ),
    );
  }

  QaSshTarget _readSshTarget() => QaSshTarget(
    enabled: _sshEnabled,
    host: _sshHostController.text.trim(),
    username: _sshUsernameController.text.trim(),
    port: _sshPortController.text.trim(),
    identityFile: _sshIdentityFileController.text.trim(),
    appRoot: _sshAppRootController.text.trim(),
    flutterPath: _sshFlutterPathController.text.trim(),
  );

  Future<void> _setSshEnabled(bool enabled) async {
    setState(() => _sshEnabled = enabled);
    await _preferencesRepo.saveSshEnabled(
      enabled,
      profileId: _selectedProfile.id,
    );
  }

  Future<void> _saveSshSettings() async {
    await _preferencesRepo.saveSshTarget(
      _readSshTarget(),
      profileId: _selectedProfile.id,
    );
    await _preferencesRepo.saveSshPassword(
      _sshPasswordController.text,
      profileId: _selectedProfile.id,
    );
    await _preferencesRepo.markInitialSetupComplete();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SSH target settings updated successfully.'),
        backgroundColor: Color(0xFF658A7A),
      ),
    );
  }

  Future<void> _saveSystemPaths(String flutterPath, String appRoot) async {
    await Future.wait(<Future<void>>[
      _preferencesRepo.saveFlutterPath(flutterPath),
      _preferencesRepo.saveAppRoot(appRoot),
    ]);
    await _preferencesRepo.markInitialSetupComplete();

    if (!mounted) return;
    setState(() {
      _flutterPath = flutterPath;
      _appRoot = appRoot;
    });
    widget.onSystemPathsUpdated?.call(flutterPath, appRoot);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('System paths updated successfully.'),
        backgroundColor: Color(0xFF658A7A),
      ),
    );
  }

  Future<void> _testSshConnection() async {
    setState(() {
      _testingSshConnection = true;
      _sshConnectionStatus = 'Testing SSH connection…';
    });

    try {
      final callback = widget.onTestSshConnection;
      final result = callback == null
          ? 'SSH connection test is not configured yet.'
          : await callback(_readSshTarget(), _sshPasswordController.text);
      if (!mounted) return;
      setState(() => _sshConnectionStatus = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sshConnectionStatus = 'Connection error: $e');
    } finally {
      if (mounted) setState(() => _testingSshConnection = false);
    }
  }

  int _readMaxOutputTokens() {
    final parsed = int.tryParse(_maxOutputTokensController.text.trim());
    final value = (parsed ?? AiModelConfig.defaultMaxOutputTokens).clamp(
      256,
      AiModelConfig.maxOutputTokenLimit,
    );
    _maxOutputTokensController.text = value.toString();
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      body: Column(
        children: <Widget>[
          _buildTopBar(),
          const Divider(height: 1, thickness: 1, color: Color(0xFFC7C9C4)),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SettingsSidebar(
                  activeTab: _activeTab,
                  onSelectTab: (tab) => setState(() => _activeTab = tab),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0xFFC7C9C4),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: double.infinity,
                        child: _buildActiveTabContent(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() => SizedBox(
    height: 64,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Back to Assistant',
            onPressed: widget.onClose,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF2C302E),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.settings_outlined,
            size: 22,
            color: Color(0xFF658A7A),
          ),
          const SizedBox(width: 10),
          const Text(
            'QA Agent Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C302E),
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF658A7A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: widget.onClose,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Done'),
          ),
        ],
      ),
    ),
  );

  Widget _buildActiveTabContent() => switch (_activeTab) {
    SettingsTab.inputsCredentials => InputsCredentialsWorkspace(
      profiles: widget.profiles,
      selectedProfile: _selectedProfile,
      loadLoginCases: _loginCasesRepo.read,
      saveLoginCases: _loginCasesRepo.write,
      loadOrderItems: _orderInputRepo.read,
      saveOrderItems: _orderInputRepo.write,
      loadOrderCases: _orderCasesRepo.read,
      saveOrderCases: _orderCasesRepo.write,
      onProfileChanged: (profile) {
        setState(() => _selectedProfile = profile);
        widget.onProfileSelected(profile);
        _loadSshSettings(profile);
      },
    ),
    SettingsTab.credentials => CredentialsSettingsTab(
      profiles: widget.profiles,
      selectedProfile: _selectedProfile,
      loginIdController: _loginIdController,
      passwordController: _passwordController,
      unlockPinController: _unlockPinController,
      savingCredentials: _savingCredentials,
      onProfileChanged: (profile) {
        setState(() => _selectedProfile = profile);
        widget.onProfileSelected(profile);
        _loadProfileCredentials(profile);
        _loadSshSettings(profile);
      },
      onSaveCredentials: _saveCredentials,
    ),
    SettingsTab.profiles => ProfilesSettingsTab(
      profiles: widget.profiles,
      activeProfile: widget.activeProfile,
      newLabelController: _newLabelController,
      newEntityController: _newEntityController,
      newEnvController: _newEnvController,
      newAliasesController: _newAliasesController,
      onAddProfile: _addProfile,
      onDeleteProfile: _deleteProfile,
    ),
    SettingsTab.sshTarget => SshSettingsTab(
      profiles: widget.profiles,
      selectedProfile: _selectedProfile,
      enabled: _sshEnabled,
      hostController: _sshHostController,
      usernameController: _sshUsernameController,
      passwordController: _sshPasswordController,
      portController: _sshPortController,
      identityFileController: _sshIdentityFileController,
      appRootController: _sshAppRootController,
      flutterPathController: _sshFlutterPathController,
      testingConnection: _testingSshConnection,
      connectionStatus: _sshConnectionStatus,
      onEnabledChanged: (enabled) {
        _setSshEnabled(enabled);
      },
      onProfileChanged: (profile) {
        setState(() => _selectedProfile = profile);
        widget.onProfileSelected(profile);
        _loadSshSettings(profile);
      },
      onTestConnection: _testSshConnection,
      onSave: _saveSshSettings,
    ),
    SettingsTab.aiModels => AiModelsSettingsTab(
      isCloud: _isCloud,
      enableVerboseReasoning: _enableVerboseReasoning,
      noticeDisplayMode: _noticeDisplayMode,
      modelLabelController: _modelLabelController,
      baseUrlController: _baseUrlController,
      modelNameController: _modelNameController,
      maxOutputTokensController: _maxOutputTokensController,
      apiKeyController: _apiKeyController,
      testingConnection: _testingConnection,
      testConnectionStatus: _testConnectionStatus,
      onCloudToggle: (val) => setState(() => _isCloud = val),
      onVerboseReasoningToggle: (value) {
        setState(() => _enableVerboseReasoning = value);
      },
      onNoticeDisplayModeChanged: (value) {
        setState(() => _noticeDisplayMode = value);
        widget.onNoticeDisplayModeUpdated(value);
      },
      onTestConnection: _testAiConnection,
      onSaveAiModel: _saveAiModel,
    ),
    SettingsTab.qaNotices => QaNoticesSettingsTab(
      displayMode: _noticeDisplayMode,
      onChanged: (value) {
        setState(() => _noticeDisplayMode = value);
        widget.onNoticeDisplayModeUpdated(value);
      },
    ),
    SettingsTab.systemPaths => SystemPathsSettingsTab(
      flutterPath: _flutterPath,
      appRoot: _appRoot,
      onSave: _saveSystemPaths,
    ),
    SettingsTab.support => const SupportSettingsTab(),
  };
}
