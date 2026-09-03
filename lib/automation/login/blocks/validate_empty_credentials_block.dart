import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_keys.dart';

/// Tests credential submit action on empty fields.
class ValidateEmptyCredentialsBlock implements AutomationBlock {
  @override
  String get id => 'validate_empty_credentials';

  @override
  String get name => 'Login Validation';

  @override
  StepNotice? get notice =>
      const StepNotice('Checking login', 'Validating required credentials.');

  @override
  Future<void> execute(ExecutionContext context) async {
    await context.driver.waitFor(
      PenguinPosLoginKeys.loginId,
      timeout: context.timeout,
    );
    await context.driver.tap(PenguinPosLoginKeys.submit);
    await context.driver.waitFor(
      PenguinPosLoginKeys.loginId,
      timeout: context.timeout,
    );
  }
}
