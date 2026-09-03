import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/application/execution/preflight_service.dart';
import 'package:penguin_pos_qa_agent/domain/plan/execution_plan.dart';

PreflightDependencies dependencies({
  PreflightProfile? profile = const PreflightProfile(
    id: 'kpn-stage',
    label: 'KPN STAGE',
    isProduction: false,
  ),
  bool hasCredentials = true,
  bool suiteImplemented = true,
  RuntimeReadiness readiness = const RuntimeReadiness(
    localExecutionSupported: true,
    appRootIsValid: true,
    flutterExecutableIsValid: true,
  ),
}) => PreflightDependencies(
  findProfile: (_) => profile,
  hasSavedLoginCredentials: (_) => hasCredentials,
  isSuiteImplemented: (_) => suiteImplemented,
  checkRuntimeReadiness: () => readiness,
);

void main() {
  const loginPlan = ExecutionPlan(
    profileId: 'kpn-stage',
    suiteId: QaSuiteId.loginTerminal,
  );

  test('passes an eligible local login plan', () async {
    final result = await PreflightService(dependencies()).check(loginPlan);

    expect(result.passed, isTrue);
    expect(result.profile!.id, 'kpn-stage');
    expect(result.checks, hasLength(6));
  });

  test('blocks production before credential or runtime checks', () async {
    final result = await PreflightService(
      dependencies(
        profile: const PreflightProfile(
          id: 'kpn-prod',
          label: 'KPN PROD',
          isProduction: true,
        ),
      ),
    ).check(loginPlan.copyWith(profileId: 'kpn-prod'));

    expect(result.passed, isFalse);
    expect(result.failure!.kind, PreflightCheckKind.nonProductionTarget);
    expect(result.checks, hasLength(3));
  });

  test('blocks missing credentials without checking runtime', () async {
    var runtimeChecked = false;
    final base = dependencies(hasCredentials: false);
    final service = PreflightService(
      PreflightDependencies(
        findProfile: base.findProfile,
        hasSavedLoginCredentials: base.hasSavedLoginCredentials,
        isSuiteImplemented: base.isSuiteImplemented,
        checkRuntimeReadiness: () {
          runtimeChecked = true;
          return const RuntimeReadiness(
            localExecutionSupported: true,
            appRootIsValid: true,
            flutterExecutableIsValid: true,
          );
        },
      ),
    );

    final result = await service.check(loginPlan);

    expect(result.failure!.kind, PreflightCheckKind.credentials);
    expect(runtimeChecked, isFalse);
  });
}
