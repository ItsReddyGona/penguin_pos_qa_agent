import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_keys.dart';

/// Submits a login case with exactly one required credential left empty.
class ValidatePartialCredentialsBlock implements AutomationBlock {
  const ValidatePartialCredentialsBlock({
    required this.id,
    required this.name,
    required this.username,
    required this.password,
    this.mode = TextInputMode.driverDirect,
    this.keyPrefix = 'login.qwerty',
  });

  @override
  final String id;
  @override
  final String name;
  final String username;
  final String password;
  final TextInputMode mode;
  final String keyPrefix;

  @override
  StepNotice? get notice => StepNotice('Checking login', name);

  @override
  Future<void> execute(ExecutionContext context) async {
    await context.driver.waitFor(
      PenguinPosLoginKeys.loginId,
      timeout: context.timeout,
    );
    for (final entry in <String, String>{
      PenguinPosLoginKeys.loginId: username,
      PenguinPosLoginKeys.password: password,
    }.entries) {
      await context.driver.enterTextViaVirtualKeyboard(
        entry.key,
        entry.value,
        keyPrefix: keyPrefix,
        mode: mode,
      );
    }
    await context.driver.tap(PenguinPosLoginKeys.submit);
    await context.driver.waitFor(
      PenguinPosLoginKeys.loginId,
      timeout: context.timeout,
    );
  }
}
