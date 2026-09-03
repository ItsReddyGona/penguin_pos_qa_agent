import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/onboarding/widgets/credentials_step.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/onboarding/widgets/onboarding_step_header.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/onboarding/widgets/profile_preset_step.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/onboarding/widgets/target_environment_step.dart';
import 'package:penguin_pos_qa_agent/runtime/path_detector.dart';

/// Interactive 3-step setup onboarding wizard for target, environment, and credentials configuration.
class OnboardingSetupScreen extends StatefulWidget {
  const OnboardingSetupScreen({
    super.key,
    required this.initialTargetMode,
    required this.initialFlutterPath,
    required this.initialAppRoot,
    required this.initialProfile,
    required this.initialLoginId,
    required this.initialPassword,
    required this.initialUnlockPin,
    required this.onComplete,
  });

  final QaTargetMode initialTargetMode;
  final String initialFlutterPath;
  final String initialAppRoot;
  final QaProfile? initialProfile;
  final String initialLoginId;
  final String initialPassword;
  final String initialUnlockPin;

  final void Function({
    required QaTargetMode targetMode,
    required String flutterPath,
    required String appRoot,
    required QaProfile profile,
    required String loginId,
    required String password,
    required String unlockPin,
    required String sshUser,
    required String sshHost,
  })
  onComplete;

  @override
  State<OnboardingSetupScreen> createState() => _OnboardingSetupScreenState();
}

class _OnboardingSetupScreenState extends State<OnboardingSetupScreen> {
  int _currentStep = 0;

  late QaTargetMode _targetMode;
  late TextEditingController _flutterPathController;
  late TextEditingController _appRootController;
  late TextEditingController _sshUserController;
  late TextEditingController _sshHostController;

  QaProfile? _selectedProfile;

  late TextEditingController _loginIdController;
  late TextEditingController _passwordController;
  late TextEditingController _unlockPinController;

  bool _detectingPaths = false;
  bool _flutterPathValid = true;
  bool _appRootValid = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _targetMode = widget.initialTargetMode;
    _flutterPathController = TextEditingController(
      text: widget.initialFlutterPath,
    );
    _appRootController = TextEditingController(text: widget.initialAppRoot);
    _sshUserController = TextEditingController();
    _sshHostController = TextEditingController();
    _selectedProfile = widget.initialProfile ?? QaProfile.values.first;
    _loginIdController = TextEditingController(text: widget.initialLoginId);
    _passwordController = TextEditingController(text: widget.initialPassword);
    _unlockPinController = TextEditingController(text: widget.initialUnlockPin);

    _autoDetectSystemPaths();
  }

  Future<void> _autoDetectSystemPaths() async {
    setState(() => _detectingPaths = true);
    try {
      if (_flutterPathController.text.isEmpty ||
          _flutterPathController.text == 'flutter') {
        final detectedFlutter = await PathDetector.detectFlutterPath();
        _flutterPathController.text = detectedFlutter;
      }
      if (_appRootController.text.isEmpty) {
        final detectedAppRoot = await PathDetector.detectAppRoot();
        _appRootController.text = detectedAppRoot;
      }

      _flutterPathValid = await PathDetector.isValidFlutterExecutable(
        _flutterPathController.text,
      );
      _appRootValid = await PathDetector.isValidAppRoot(
        _appRootController.text,
      );
    } finally {
      if (mounted) {
        setState(() => _detectingPaths = false);
      }
    }
  }

  @override
  void dispose() {
    _flutterPathController.dispose();
    _appRootController.dispose();
    _sshUserController.dispose();
    _sshHostController.dispose();
    _loginIdController.dispose();
    _passwordController.dispose();
    _unlockPinController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_targetMode == QaTargetMode.local) {
        if (_flutterPathController.text.trim().isEmpty) {
          setState(
            () => _errorMessage = 'Flutter executable path cannot be empty.',
          );
          return;
        }
        if (_appRootController.text.trim().isEmpty) {
          setState(
            () => _errorMessage = 'PenguinPOS app root path cannot be empty.',
          );
          return;
        }
      }
    } else if (_currentStep == 2) {
      final phone = _loginIdController.text.trim();
      final password = _passwordController.text.trim();
      final pin = _unlockPinController.text.trim();

      if (phone.length != 10) {
        setState(
          () => _errorMessage =
              'Mobile phone number must be exactly 10 numeric digits.',
        );
        return;
      }
      if (password.isEmpty) {
        setState(() => _errorMessage = 'Account password cannot be empty.');
        return;
      }
      if (pin.length != 4) {
        setState(
          () => _errorMessage =
              'Idle unlock PIN must be exactly 4 numeric digits.',
        );
        return;
      }
    }

    setState(() {
      _errorMessage = null;
      if (_currentStep < 2) {
        _currentStep++;
      } else {
        _completeWizard();
      }
    });
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _errorMessage = null;
        _currentStep--;
      });
    }
  }

  void _completeWizard() {
    widget.onComplete(
      targetMode: _targetMode,
      flutterPath: _flutterPathController.text.trim(),
      appRoot: _appRootController.text.trim(),
      profile: _selectedProfile ?? QaProfile.values.first,
      loginId: _loginIdController.text.trim(),
      password: _passwordController.text.trim(),
      unlockPin: _unlockPinController.text.trim(),
      sshUser: _sshUserController.text.trim(),
      sshHost: _sshHostController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Container(
          width: 860,
          constraints: BoxConstraints(
            maxHeight: (screenHeight * 0.88).clamp(520, 720),
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              // Step Wizard Navigation Header
              OnboardingStepHeader(currentStep: _currentStep),

              // Error Message Banner (if any)
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFEF2F2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFDC2626),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

              // Step Content Body
              Expanded(
                child: IndexedStack(
                  index: _currentStep,
                  children: <Widget>[
                    TargetEnvironmentStep(
                      targetMode: _targetMode,
                      flutterPathController: _flutterPathController,
                      appRootController: _appRootController,
                      sshUserController: _sshUserController,
                      sshHostController: _sshHostController,
                      detectingPaths: _detectingPaths,
                      flutterPathValid: _flutterPathValid,
                      appRootValid: _appRootValid,
                      onTargetModeChanged: (mode) {
                        setState(() => _targetMode = mode);
                      },
                      onAutoDetectPaths: _autoDetectSystemPaths,
                    ),
                    ProfilePresetStep(
                      selectedProfile: _selectedProfile,
                      onProfileSelected: (profile) {
                        setState(() => _selectedProfile = profile);
                      },
                    ),
                    CredentialsStep(
                      loginIdController: _loginIdController,
                      passwordController: _passwordController,
                      unlockPinController: _unlockPinController,
                    ),
                  ],
                ),
              ),

              // Bottom Action Button Footer
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: <Widget>[
                    if (_currentStep > 0)
                      OutlinedButton(
                        onPressed: _previousStep,
                        child: const Text('Back'),
                      ),
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF155EEF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                      onPressed: _nextStep,
                      child: Text(
                        _currentStep == 2
                            ? 'Complete Setup & Open Dashboard'
                            : 'Next Step',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
