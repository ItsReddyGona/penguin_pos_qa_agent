import 'dart:async';

import 'package:penguin_pos_qa_agent/domain/plan/execution_plan.dart';

/// The non-secret properties of a configured QA target needed by preflight.
/// Concrete profile repositories map their own storage models into this type.
class PreflightProfile {
  const PreflightProfile({
    required this.id,
    required this.label,
    required this.isProduction,
  });

  final String id;
  final String label;
  final bool isProduction;
}

/// Runtime checks required before the local execution coordinator launches an
/// application. It intentionally does not launch or mutate anything.
class RuntimeReadiness {
  const RuntimeReadiness({
    required this.localExecutionSupported,
    required this.appRootIsValid,
    required this.flutterExecutableIsValid,
  });

  final bool localExecutionSupported;
  final bool appRootIsValid;
  final bool flutterExecutableIsValid;
}

enum PreflightCheckKind {
  plan,
  profile,
  nonProductionTarget,
  suite,
  credentials,
  runtime,
}

enum PreflightCheckStatus { passed, failed, skipped }

class PreflightCheck {
  const PreflightCheck({
    required this.kind,
    required this.status,
    required this.message,
  });

  final PreflightCheckKind kind;
  final PreflightCheckStatus status;
  final String message;
}

/// A UI-safe preflight outcome. Credentials are intentionally absent.
class PreflightResult {
  const PreflightResult({required this.checks, this.profile});

  final List<PreflightCheck> checks;
  final PreflightProfile? profile;

  bool get passed =>
      checks.every((check) => check.status != PreflightCheckStatus.failed);

  PreflightCheck? get failure {
    for (final check in checks) {
      if (check.status == PreflightCheckStatus.failed) return check;
    }
    return null;
  }
}

/// Ports supplied by persistence/runtime adapters. Keeping them as callbacks
/// keeps preflight deterministic and independent of Flutter, preferences,
/// app launching, and the dashboard.
class PreflightDependencies {
  const PreflightDependencies({
    required this.findProfile,
    required this.hasSavedLoginCredentials,
    required this.isSuiteImplemented,
    required this.checkRuntimeReadiness,
  });

  final FutureOr<PreflightProfile?> Function(String profileId) findProfile;
  final FutureOr<bool> Function(String profileId) hasSavedLoginCredentials;
  final FutureOr<bool> Function(QaSuiteId suiteId) isSuiteImplemented;
  final FutureOr<RuntimeReadiness> Function() checkRuntimeReadiness;
}

/// Validates a plan against the configured target without launching PenguinPOS.
class PreflightService {
  const PreflightService(this._dependencies);

  final PreflightDependencies _dependencies;

  Future<PreflightResult> check(ExecutionPlan plan) async {
    final checks = <PreflightCheck>[];
    final planIssues = plan.validate();
    if (planIssues.isNotEmpty) {
      checks.add(
        PreflightCheck(
          kind: PreflightCheckKind.plan,
          status: PreflightCheckStatus.failed,
          message: planIssues.first,
        ),
      );
      return PreflightResult(checks: checks);
    }
    checks.add(
      const PreflightCheck(
        kind: PreflightCheckKind.plan,
        status: PreflightCheckStatus.passed,
        message: 'Execution plan is valid.',
      ),
    );

    final profile = await _dependencies.findProfile(plan.profileId);
    if (profile == null) {
      checks.add(
        const PreflightCheck(
          kind: PreflightCheckKind.profile,
          status: PreflightCheckStatus.failed,
          message: 'The selected target profile is no longer configured.',
        ),
      );
      return PreflightResult(checks: checks);
    }
    checks.add(
      PreflightCheck(
        kind: PreflightCheckKind.profile,
        status: PreflightCheckStatus.passed,
        message: 'Matched target profile: ${profile.label}.',
      ),
    );

    if (profile.isProduction) {
      checks.add(
        const PreflightCheck(
          kind: PreflightCheckKind.nonProductionTarget,
          status: PreflightCheckStatus.failed,
          message:
              'Production environments are strictly prohibited. No application was launched.',
        ),
      );
      return PreflightResult(checks: checks, profile: profile);
    }
    checks.add(
      const PreflightCheck(
        kind: PreflightCheckKind.nonProductionTarget,
        status: PreflightCheckStatus.passed,
        message: 'Confirmed approved non-production target.',
      ),
    );

    final implemented = await _dependencies.isSuiteImplemented(plan.suiteId);
    if (!implemented) {
      checks.add(
        const PreflightCheck(
          kind: PreflightCheckKind.suite,
          status: PreflightCheckStatus.failed,
          message: 'The selected suite does not yet have an executable runner.',
        ),
      );
      return PreflightResult(checks: checks, profile: profile);
    }
    checks.add(
      const PreflightCheck(
        kind: PreflightCheckKind.suite,
        status: PreflightCheckStatus.passed,
        message: 'Confirmed suite runner is available.',
      ),
    );

    final hasCredentials = await _dependencies.hasSavedLoginCredentials(
      profile.id,
    );
    if (!hasCredentials) {
      checks.add(
        PreflightCheck(
          kind: PreflightCheckKind.credentials,
          status: PreflightCheckStatus.failed,
          message:
              'Save the login ID and password for ${profile.label} before running this plan.',
        ),
      );
      return PreflightResult(checks: checks, profile: profile);
    }
    checks.add(
      const PreflightCheck(
        kind: PreflightCheckKind.credentials,
        status: PreflightCheckStatus.passed,
        message: 'Checked saved login credentials.',
      ),
    );

    final readiness = await _dependencies.checkRuntimeReadiness();
    if (!readiness.localExecutionSupported) {
      checks.add(
        const PreflightCheck(
          kind: PreflightCheckKind.runtime,
          status: PreflightCheckStatus.failed,
          message:
              'Remote execution is not available yet. No application was launched.',
        ),
      );
    } else if (!readiness.appRootIsValid ||
        !readiness.flutterExecutableIsValid) {
      checks.add(
        const PreflightCheck(
          kind: PreflightCheckKind.runtime,
          status: PreflightCheckStatus.failed,
          message:
              'The local PenguinPOS app path or Flutter executable is not ready.',
        ),
      );
    } else {
      checks.add(
        const PreflightCheck(
          kind: PreflightCheckKind.runtime,
          status: PreflightCheckStatus.passed,
          message: 'Confirmed local launch is available.',
        ),
      );
    }
    return PreflightResult(checks: checks, profile: profile);
  }
}
