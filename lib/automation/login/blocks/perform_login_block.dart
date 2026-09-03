import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_keys.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_api_call_barrier.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_scenario.dart';

/// Atomic block for entering valid credentials and submitting login.
class PerformLoginBlock implements AutomationBlock {
  final LoginScenario scenario;
  final TextInputMode mode;
  final String keyPrefix;

  PerformLoginBlock({
    required this.scenario,
    this.mode = TextInputMode.driverDirect,
    this.keyPrefix = 'login.qwerty',
  });

  @override
  String get id => 'perform_login';

  @override
  String get name => 'Submit Credentials';

  @override
  StepNotice? get notice => const StepNotice(
    'Logging in',
    'Submitting credentials.',
    isMilestone: true,
  );

  @override
  Future<void> execute(ExecutionContext context) async {
    await context.driver.clearSnackBars();
    await context.driver.waitFor(
      PenguinPosLoginKeys.loginId,
      timeout: context.timeout,
    );
    // Explicitly focus loginId field to reset form focus state
    await context.driver.tap(PenguinPosLoginKeys.loginId);
    await context.driver.enterTextViaVirtualKeyboard(
      PenguinPosLoginKeys.loginId,
      scenario.loginId,
      keyPrefix: keyPrefix,
      mode: mode,
    );
    await context.driver.enterTextViaVirtualKeyboard(
      PenguinPosLoginKeys.password,
      scenario.password,
      keyPrefix: keyPrefix,
      mode: mode,
    );
    final loginApi = await LoginApiCallBarrier.arm(context.driver);
    await context.driver.tap(PenguinPosLoginKeys.submit);
    await loginApi.waitForCompletion(
      context.driver,
      expectation: LoginApiExpectation.accepted,
      timeout: context.timeout,
    );
  }
}
