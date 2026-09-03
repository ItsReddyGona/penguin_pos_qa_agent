import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_keys.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_keys.dart';

/// Resets application session state back to Login screen.
class EnsureLoggedOutBlock implements AutomationBlock {
  @override
  String get id => 'ensure_logged_out';

  @override
  String get name => 'Session Reset';

  @override
  StepNotice? get notice => const StepNotice(
    'Preparing login test',
    'Resetting the session.',
    isMilestone: true,
  );

  @override
  Future<void> execute(ExecutionContext context) async {
    final initialState = await context.driver.waitForAnyKey([
      PenguinPosLoginKeys.loginId,
      PenguinPosLoginKeys.homeScreen,
      PenguinPosOrderKeys.orderScreen,
    ], timeout: context.timeout);

    final isInitialProbe = !context.state.containsKey('initial_screen');
    final isLoginScreen = initialState == PenguinPosLoginKeys.loginId;
    final sessionState = isLoginScreen ? 'logged_out' : 'logged_in';
    if (isInitialProbe) {
      // These fields describe launch state only. Cleanup invokes this block
      // again after login and must never overwrite the original decision.
      context.state['initial_screen'] = initialState;
      context.state['initial_session_state'] = sessionState;
      context.state['initial_logout_required'] = sessionState == 'logged_in';
    } else {
      context.state['cleanup_screen'] = initialState;
      context.state['cleanup_session_state'] = sessionState;
    }

    if (isLoginScreen) {
      return;
    }

    await context.driver.clearSnackBars();

    final hasKeyedLogout = await context.driver.hasKey(
      PenguinPosLoginKeys.logoutButton,
      timeout: const Duration(seconds: 1),
    );
    if (hasKeyedLogout) {
      await context.driver.tap(PenguinPosLoginKeys.logoutButton);
    } else {
      await context.driver.tapText('LOGOUT');
    }
    await context.driver.waitFor(
      PenguinPosLoginKeys.logoutConfirm,
      timeout: context.timeout,
    );
    await context.driver.tap(PenguinPosLoginKeys.logoutConfirm);
    await context.driver.waitFor(
      PenguinPosLoginKeys.loginId,
      timeout: context.timeout,
    );
  }
}
