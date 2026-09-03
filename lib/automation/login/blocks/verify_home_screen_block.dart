import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_scenario.dart';

/// Atomic block for verifying navigation into Home Screen.
class VerifyHomeScreenBlock implements AutomationBlock {
  final LoginScenario scenario;

  VerifyHomeScreenBlock({required this.scenario});

  @override
  String get id => 'verify_home_screen';

  @override
  String get name => 'Valid Login Flow';

  @override
  StepNotice? get notice => const StepNotice(
    'Opening home screen',
    'Confirming the login completed.',
    isMilestone: true,
  );

  @override
  Future<void> execute(ExecutionContext context) async {
    await context.driver.waitFor(
      scenario.expectedKey,
      timeout: context.timeout,
    );
  }
}
