import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_keys.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_api_call_barrier.dart';

/// Tests authentication failure handling when invalid credentials are submitted.
class ValidateInvalidCredentialsBlock implements AutomationBlock {
  final TextInputMode mode;
  final String keyPrefix;
  final String username;
  final String password;

  ValidateInvalidCredentialsBlock({
    this.mode = TextInputMode.driverDirect,
    this.keyPrefix = 'login.qwerty',
    this.username = '0000000000',
    this.password = 'invalidpassword',
  });

  @override
  String get id => 'validate_invalid_credentials';

  @override
  String get name => 'Auth Failure Handling';

  @override
  StepNotice? get notice => const StepNotice(
    'Checking login',
    'Submitting expected invalid credentials.',
  );

  @override
  Future<void> execute(ExecutionContext context) async {
    await context.driver.waitFor(
      PenguinPosLoginKeys.loginId,
      timeout: context.timeout,
    );
    await context.driver.enterTextViaVirtualKeyboard(
      PenguinPosLoginKeys.loginId,
      username,
      keyPrefix: keyPrefix,
      mode: mode,
    );
    await context.driver.enterTextViaVirtualKeyboard(
      PenguinPosLoginKeys.password,
      password,
      keyPrefix: keyPrefix,
      mode: mode,
    );
    final loginApi = await LoginApiCallBarrier.arm(context.driver);
    await context.driver.tap(PenguinPosLoginKeys.submit);
    // Invalid credentials still make the normal asynchronous login API call.
    // Wait for its rendered rejection just as successful login waits for the
    // terminal/home result. The pre-existing login field is not proof that the
    // API request completed.
    await loginApi.waitForCompletion(
      context.driver,
      expectation: LoginApiExpectation.rejected,
      timeout: context.timeout,
    );

    // The completed 4xx trace is the authoritative result for this API-driven
    // scenario. PenguinPOS deployments use different rejection copy (for
    // example "Incorrect User ID" or "Invalid credentials"), so an exact
    // SnackBar string must not turn an expected rejection into a failed case.
    await context.driver.waitFor(
      PenguinPosLoginKeys.loginId,
      timeout: context.timeout,
    );
    await context.showNotice(
      QaTestNoticeSeverity.warning,
      'Expected authentication failure',
      'Invalid credentials were rejected as expected.',
    );
  }
}
