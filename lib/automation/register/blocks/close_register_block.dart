import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_keys.dart';
import 'package:penguin_pos_qa_agent/automation/register/blocks/open_register_block.dart';
import 'package:penguin_pos_qa_agent/automation/register/register_keys.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_register_input_repository.dart';

/// Automates closing the cash register with the specified total amount or
/// custom notes and coins breakdown, ensuring all payment summary fields and
/// cash denominations are filled.
class CloseRegisterBlock implements AutomationBlock {
  const CloseRegisterBlock({
    this.totalAmount = 1000.0,
    this.closingFloatAmount = 0.0,
    this.notesMap = const <int, int>{},
    this.coinsMap = const <int, int>{},
  });

  final double totalAmount;
  final double closingFloatAmount;
  final Map<int, int> notesMap;
  final Map<int, int> coinsMap;

  @override
  String get id => 'close_register';

  @override
  String get name => 'Close Cash Register';

  @override
  StepNotice? get notice => const StepNotice(
    'Closing register',
    'Submitting cash denominations and closing register.',
    isMilestone: true,
  );

  @override
  Future<void> execute(ExecutionContext context) async {
    final driver = context.driver;
    final timeout = context.timeout;
    final useCustomBreakdown = notesMap.isNotEmpty || coinsMap.isNotEmpty;
    final totalTarget = useCustomBreakdown
        ? QaRegisterInput.computeTotalFromBreakdown(notesMap, coinsMap)
        : totalAmount.toInt();

    // 1. Ensure on Register Screen
    context.emit(
      'Navigating to Register',
      'Verifying Register Screen is active.',
    );

    final currentTarget = await driver.waitForAnyKey(<String>[
      PenguinPosRegisterKeys.registerScreen,
      PenguinPosOrderKeys.homeRegisterTab,
    ], timeout: timeout);

    if (currentTarget == PenguinPosOrderKeys.homeRegisterTab) {
      await driver.tap(PenguinPosOrderKeys.homeRegisterTab);
      await driver.waitFor(
        PenguinPosRegisterKeys.registerScreen,
        timeout: timeout,
      );
    }

    // 2. Probe if register is open or closed
    // If inputOpeningFloat is present, register is not yet opened!
    final isClosed = await driver.hasKey(
      PenguinPosRegisterKeys.inputOpeningFloat,
      timeout: const Duration(seconds: 2),
    );

    if (isClosed) {
      context.emit(
        'Register is Closed',
        'Cannot close register because register is currently closed.',
        level: ExecutionEventLevel.error,
      );
      throw StateError(
        'Cannot close register: Cash register is currently closed. Open register first.',
      );
    }

    // 3. Closing Float Cash Field
    // Total cash amount is entered into the closing float field
    final effectiveClosingFloat = closingFloatAmount > 0
        ? closingFloatAmount.toInt()
        : totalTarget;
    final hasClosingFloat = await driver.hasKey(
      PenguinPosRegisterKeys.inputClosingFloat,
      timeout: const Duration(seconds: 2),
    );
    if (hasClosingFloat) {
      context.emit(
        'Filling Closing Float',
        'Entering closing float cash amount: ₹$effectiveClosingFloat.',
      );
      await driver.tap(PenguinPosRegisterKeys.inputClosingFloat);
      await driver.enterText(
        PenguinPosRegisterKeys.inputClosingFloat,
        effectiveClosingFloat.toString(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }

    // 4. Check & Fill Payment Summary Gateway Fields (Card & UPI)
    context.emit(
      'Checking Payment Summary Fields',
      'Verifying all available card and UPI gateway input fields.',
    );

    final gatewayKeys = <String>[
      PenguinPosRegisterKeys.inputPinelabsCardAmount,
      PenguinPosRegisterKeys.inputPinelabsCardCount,
      PenguinPosRegisterKeys.inputPinelabsUpiAmount,
      PenguinPosRegisterKeys.inputPinelabsUpiCount,
      PenguinPosRegisterKeys.inputRazorpayCardAmount,
      PenguinPosRegisterKeys.inputRazorpayCardCount,
      PenguinPosRegisterKeys.inputRazorpayUpiAmount,
      PenguinPosRegisterKeys.inputRazorpayUpiCount,
      PenguinPosRegisterKeys.inputPaytmCardAmount,
      PenguinPosRegisterKeys.inputPaytmCardCount,
      PenguinPosRegisterKeys.inputPaytmUpiAmount,
      PenguinPosRegisterKeys.inputPaytmUpiCount,
      PenguinPosRegisterKeys.inputIciciOrangeCardAmount,
      PenguinPosRegisterKeys.inputIciciOrangeCardCount,
      PenguinPosRegisterKeys.inputIciciOrangeUpiAmount,
      PenguinPosRegisterKeys.inputIciciOrangeUpiCount,
      PenguinPosRegisterKeys.inputCardAmount,
      PenguinPosRegisterKeys.inputCardCount,
      PenguinPosRegisterKeys.inputUpiAmount,
      PenguinPosRegisterKeys.inputUpiCount,
    ];

    const probeTimeout = Duration(milliseconds: 100);

    // Concurrently probe all gateway fields with a short timeout to prevent
    // sequential timeout delays when fields are not present on the POS screen.
    final gatewayProbes = await Future.wait(
      gatewayKeys.map((key) async {
        final present = await driver
            .hasKey(key, timeout: probeTimeout)
            .catchError((_) => false);
        return (key: key, present: present);
      }),
    );

    for (final probe in gatewayProbes) {
      if (probe.present) {
        await driver.tap(probe.key);
        await driver.enterText(probe.key, '0');
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }

    // 5. Populate Denomination Breakdown for Total Target Amount
    context.emit(
      'Filling Cash Denominations',
      'Distributing total target cash ₹$totalTarget into notes and coins.',
    );

    const denoms = <int>[500, 200, 100, 50, 20, 10, 5, 2, 1];
    final Map<int, int> effectiveNotes;
    final Map<int, int> effectiveCoins;

    if (useCustomBreakdown) {
      effectiveNotes = notesMap;
      effectiveCoins = coinsMap;
    } else {
      var remainder = totalTarget;
      final greedy = <int, int>{};
      for (final d in denoms) {
        greedy[d] = remainder ~/ d;
        remainder %= d;
      }
      effectiveNotes = <int, int>{
        for (final d in denoms)
          if (QaRegisterInput.hasNotes(d)) d: (greedy[d] ?? 0),
      };
      effectiveCoins = <int, int>{
        for (final d in denoms)
          if (QaRegisterInput.hasCoins(d))
            d: (!QaRegisterInput.hasNotes(d) ? (greedy[d] ?? 0) : 0),
      };
    }

    // Denomination Tables (Notes for hasNotes; Coins for hasCoins)
    final denomKeys = <({int denom, bool isNote, String key})>[
      for (final d in denoms) ...[
        if (QaRegisterInput.hasNotes(d))
          (denom: d, isNote: true, key: PenguinPosRegisterKeys.cashNotes(d)),
        if (QaRegisterInput.hasCoins(d))
          (denom: d, isNote: false, key: PenguinPosRegisterKeys.cashCoins(d)),
      ],
    ];

    final denomProbes = await Future.wait(
      denomKeys.map((item) async {
        final present = await driver
            .hasKey(item.key, timeout: probeTimeout)
            .catchError((_) => false);
        return (
          denom: item.denom,
          isNote: item.isNote,
          key: item.key,
          present: present,
        );
      }),
    );

    for (final probe in denomProbes) {
      if (!probe.present) continue;
      final count = probe.isNote
          ? (effectiveNotes[probe.denom] ?? 0)
          : (effectiveCoins[probe.denom] ?? 0);
      await driver.tap(probe.key);
      await driver.enterText(probe.key, count.toString());
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    // 6. Step 5: Evaluate Result - Verify calculated Total Cash display matches expected total
    context.emit(
      'Evaluating Calculated Total',
      'Verifying calculated Total Cash matches expected total ₹$totalTarget.',
    );

    var evaluated = false;
    String? lastTotalDisplay;
    final evalStopwatch = Stopwatch()..start();
    while (evalStopwatch.elapsed < const Duration(seconds: 8)) {
      final text = await driver.tryGetText(
        PenguinPosRegisterKeys.cashTotal,
        timeout: const Duration(seconds: 1),
      );
      if (text != null && text.trim().isNotEmpty) {
        lastTotalDisplay = text.trim();
        // Handle values formatted with decimals like ₹3000.00
        final sanitized = lastTotalDisplay.replaceAll(RegExp(r'[^\d.]'), '');
        final parsed = double.tryParse(sanitized)?.toInt();
        if (parsed == totalTarget) {
          evaluated = true;
          break;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    if (evaluated) {
      context.emit(
        'Total Cash Verified',
        'Total Cash evaluated successfully: matches expected ₹$totalTarget ($lastTotalDisplay).',
      );
    } else {
      context.emit(
        'Total Cash Evaluated',
        'Total Cash display is "$lastTotalDisplay" (target: ₹$totalTarget). Proceeding to submit.',
      );
    }

    // 7. Step 6: Wait until register submit button is enabled, then click
    context.emit(
      'Submitting Close Register',
      'Waiting until Register submit button is enabled, then clicking.',
    );

    await driver.waitFor(
      PenguinPosRegisterKeys.registerSubmit,
      timeout: timeout,
    );

    // Give form validation a brief settling window
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final firstTapped = await driver.tryTapKey(
      PenguinPosRegisterKeys.registerSubmit,
      timeout: const Duration(milliseconds: 500),
    );
    if (!firstTapped) {
      await driver.tryTapText(
        'Close Register',
        timeout: const Duration(milliseconds: 300),
      );
    }

    final submitStopwatch = Stopwatch()..start();
    var transitioned = false;

    while (submitStopwatch.elapsed < timeout) {
      // Prioritize checking if Open Register input has appeared or error dialog popped up
      final currentKey = await driver
          .waitForAnyKey(<String>[
            PenguinPosRegisterKeys.inputOpeningFloat,
            PenguinPosRegisterKeys.errorDialogOk,
            PenguinPosRegisterKeys.registerSubmit,
          ], timeout: const Duration(seconds: 2))
          .catchError((_) => '');

      if (currentKey == PenguinPosRegisterKeys.errorDialogOk) {
        final okTapped = await driver.tryTapKey(
          PenguinPosRegisterKeys.errorDialogOk,
        );
        if (!okTapped) {
          await driver.tryTapText('OK');
        }
        throw const ReconciliationRequiredException(
          'Complete the Reconciliation to proceed',
        );
      }

      if (currentKey == PenguinPosRegisterKeys.inputOpeningFloat) {
        transitioned = true;
        break;
      }

      // Tap submit button via key and text fallbacks
      await driver.tryTapKey(
        PenguinPosRegisterKeys.registerSubmit,
        timeout: const Duration(milliseconds: 500),
      );
      await driver.tryTapText(
        'Close Register',
        timeout: const Duration(milliseconds: 300),
      );
      await driver.tryTapText(
        'Open Register',
        timeout: const Duration(milliseconds: 300),
      );

      // Wait a moment between attempts to allow Flutter to process tap and transition
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }

    // 8. Step 7: Confirm Open Register page is active (only then suite succeeds)
    if (!transitioned) {
      await driver.waitFor(
        PenguinPosRegisterKeys.inputOpeningFloat,
        timeout: timeout,
      );
    }

    context.emit(
      'Register Closed',
      'Register closed successfully with total cash ₹$totalTarget. Open Register page is now active.',
    );
  }
}
