import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/login/blocks/perform_login_block.dart';
import 'package:penguin_pos_qa_agent/automation/login/blocks/select_terminal_block.dart';
import 'package:penguin_pos_qa_agent/automation/login/blocks/verify_home_screen_block.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_keys.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_keys.dart';

/// Composite factory that probes live UI state and yields atomic setup blocks needed for authentication.
abstract final class AuthenticationPipelineFactory {
  static Future<List<AutomationBlock>> createSetupPipeline(
    ExecutionContext context,
    LoginScenario scenario, {
    TextInputMode mode = TextInputMode.driverDirect,
  }) async {
    final activeState = await context.driver.waitForAnyKey([
      PenguinPosLoginKeys.loginId,
      PenguinPosLoginKeys.homeScreen,
      PenguinPosOrderKeys.orderScreen,
    ], timeout: context.timeout);

    if (activeState == PenguinPosLoginKeys.homeScreen ||
        activeState == PenguinPosOrderKeys.orderScreen) {
      // Already authenticated, no setup blocks needed
      return const <AutomationBlock>[];
    }

    return <AutomationBlock>[
      PerformLoginBlock(scenario: scenario, mode: mode),
      SelectTerminalBlock(scenario: scenario),
      VerifyHomeScreenBlock(scenario: scenario),
    ];
  }
}
