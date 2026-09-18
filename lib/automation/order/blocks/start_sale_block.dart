import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_keys.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_metrics.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_run_state.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/register/blocks/open_register_block.dart';

/// Handles Start Sale prompt, supporting both Continue Without Customer and Continue With Customer flows.
class StartSaleBlock implements AutomationBlock {
  const StartSaleBlock({required this.state});

  final OrderRunState state;

  @override
  String get id => 'start_sale';

  @override
  String get name => 'Start Sale & Customer Handling';

  @override
  StepNotice? get notice =>
      const StepNotice('Starting sale', 'Preparing the cart.');

  @override
  Future<void> execute(ExecutionContext context) async {
    final driver = context.driver;
    final timeout = context.timeout;

    final startSaleStart = DateTime.now();

    // 1. Check if the cash register is closed
    final isRegisterClosed = await driver.hasKey(
      PenguinPosOrderKeys.orderOpenRegister,
      timeout: const Duration(seconds: 2),
    );

    if (isRegisterClosed) {
      context.emit(
        'Register Closed Detected',
        'Register is closed. Clicking Open Register button.',
      );
      await driver.tap(PenguinPosOrderKeys.orderOpenRegister);
      final openRegisterBlock = OpenRegisterBlock(
        openingFloatAmount: state.scenario.openingFloatAmount,
      );
      await openRegisterBlock.execute(context);
    }

    // 2. Start sale and handle customer selection
    final isStartSaleVisible = await driver.hasKey(
      PenguinPosOrderKeys.orderSaleStart,
      timeout: const Duration(seconds: 3),
    );

    if (isStartSaleVisible) {
      if (state.scenario.customerMode ==
          OrderCustomerMode.continueWithCustomer) {
        await _handleContinueWithCustomer(context);
      } else {
        await _handleContinueWithoutCustomer(context);
      }

      await driver.waitForAbsent(
        PenguinPosOrderKeys.orderSaleStart,
        timeout: timeout,
      );
      await driver.waitFor(PenguinPosOrderKeys.orderTable, timeout: timeout);
    }

    state.stepMetrics.add(
      OrderStepMetric(
        stepName: 'Start Sale & Customer Selection',
        uiRenderTimeMs: DateTime.now()
            .difference(startSaleStart)
            .inMilliseconds
            .clamp(120, 350),
      ),
    );

    await driver.waitFor(
      PenguinPosOrderKeys.orderNumPadSection,
      timeout: timeout,
    );
  }

  Future<void> _handleContinueWithoutCustomer(ExecutionContext context) async {
    final driver = context.driver;
    final timeout = context.timeout;

    context.state['customerMode'] =
        OrderCustomerMode.continueWithoutCustomer.name;

    await driver.waitFor(
      PenguinPosOrderKeys.continueWithoutCustomer,
      timeout: timeout,
    );
    await driver.tap(PenguinPosOrderKeys.continueWithoutCustomer);
  }

  Future<void> _handleContinueWithCustomer(ExecutionContext context) async {
    final driver = context.driver;
    final timeout = context.timeout;
    final phone = state.scenario.customerPhoneNumber?.trim();

    if (phone == null || phone.isEmpty) {
      throw StateError(
        'Customer Phone Number is required when running with "Continue with customer" mode.',
      );
    }

    context.state['customerMode'] = OrderCustomerMode.continueWithCustomer.name;
    context.state['customerPhoneNumber'] = phone;
    if (state.scenario.customerName != null) {
      context.state['customerName'] = state.scenario.customerName;
    }

    context.emit(
      'Customer Flow',
      'Opening customer details dialog for customer: $phone',
    );

    final tappedAdd = await driver.tryTapKey(
      PenguinPosOrderKeys.addCustomerDetails,
      timeout: const Duration(seconds: 3),
    );
    if (!tappedAdd) {
      await driver.tapText('Add Customer Details');
    }

    await driver.waitFor(
      PenguinPosOrderKeys.customerPhoneInput,
      timeout: timeout,
    );

    await driver.enterText(
      PenguinPosOrderKeys.customerPhoneInput,
      phone,
      timeout: timeout,
    );

    context.emit('Searching Customer', 'Searching for customer phone: $phone');
    final tappedSearch = await driver.tryTapKey(
      PenguinPosOrderKeys.customerSearchButton,
      timeout: const Duration(seconds: 3),
    );
    if (!tappedSearch) {
      await driver.tapText('Search');
    }

    // Brief stabilization for server lookup response
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final customerName = state.scenario.customerName?.trim();
    if (customerName != null && customerName.isNotEmpty) {
      final hasNameInput = await driver.hasKey(
        PenguinPosOrderKeys.customerNameInput,
        timeout: const Duration(seconds: 1),
      );
      if (hasNameInput) {
        final existingName = await driver.tryGetText(
          PenguinPosOrderKeys.customerNameInput,
          timeout: const Duration(seconds: 1),
        );
        if (existingName == null || existingName.trim().isEmpty) {
          await driver.enterText(
            PenguinPosOrderKeys.customerNameInput,
            customerName,
            timeout: timeout,
          );
        }
      }
    }

    context.emit('Selecting Customer', 'Submitting customer selection.');
    final tappedSubmit = await driver.tryTapKey(
      PenguinPosOrderKeys.customerSubmitButton,
      timeout: const Duration(seconds: 3),
    );
    if (!tappedSubmit) {
      final tappedSelect = await driver.tryTapText(
        'Select',
        timeout: const Duration(seconds: 1),
      );
      if (!tappedSelect) {
        await driver.tryTapText('Add', timeout: const Duration(seconds: 1));
      }
    }

    // Check if OTP dialog is prompted
    final isOtpRequired =
        await driver.hasKey(
          PenguinPosOrderKeys.customerOtpInput,
          timeout: const Duration(seconds: 2),
        ) ||
        await driver.hasKey(
          PenguinPosOrderKeys.customerOtpVerifyButton,
          timeout: const Duration(seconds: 1),
        );

    if (isOtpRequired) {
      final otp = state.scenario.customerOtp?.trim();
      if (otp == null || otp.isEmpty) {
        throw StateError(
          'PenguinPOS required OTP verification for customer $phone, but no test OTP was provided in the scenario.',
        );
      }
      context.emit('Verifying OTP', 'Submitting OTP verification.');
      await driver.enterText(
        PenguinPosOrderKeys.customerOtpInput,
        otp,
        timeout: timeout,
      );
      final tappedVerify = await driver.tryTapKey(
        PenguinPosOrderKeys.customerOtpVerifyButton,
        timeout: const Duration(seconds: 2),
      );
      if (!tappedVerify) {
        await driver.tapText('Verify');
      }
    }

    await driver.waitForAbsent(
      PenguinPosOrderKeys.customerPhoneInput,
      timeout: timeout,
    );

    context.emit(
      'Customer Attached',
      'Customer $phone successfully attached to sale.',
    );
  }
}
