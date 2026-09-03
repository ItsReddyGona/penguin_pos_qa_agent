import 'dart:async';

import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_keys.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_metrics.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_operation_query.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_run_state.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_state_snapshot.dart';

class WeightInputTimeoutException implements Exception {
  const WeightInputTimeoutException();

  @override
  String toString() => 'Test stopped: user failed to input weight.';
}

/// Enters SKU items and weight entries for the active order scenario iteration.
class EnterOrderItemsBlock implements AutomationBlock {
  const EnterOrderItemsBlock({required this.state});

  final OrderRunState state;

  @override
  String get id => 'enter_order_items';

  @override
  String get name => 'SKU & Weighed Item Entry';

  @override
  StepNotice? get notice => const StepNotice(
    'Adding SKUs',
    'Entering order items.',
    isMilestone: true,
  );

  @override
  Future<void> execute(ExecutionContext context) async {
    final driver = context.driver;
    final timeout = context.timeout;

    int itemsThisOrder = 0;
    final skuScanStart = DateTime.now();
    final itemsToPunch = state.scenario.getItemsForIteration(state.orderIndex);

    if (itemsToPunch.where((item) => item.skuCode.trim().isNotEmpty).isEmpty) {
      context.emit(
        'No SKU Items',
        'The resolved order ${state.orderIndex} has no executable SKU items.',
        level: ExecutionEventLevel.error,
      );
      throw StateError(
        'No executable SKU items were resolved for order ${state.orderIndex}.',
      );
    }

    for (final item in itemsToPunch) {
      if (item.skuCode.trim().isEmpty) continue;

      final effectiveType = item.effectiveType;
      final effectiveMode = item.effectiveEntryMode;

      try {
        await driver.waitFor(
          PenguinPosOrderKeys.orderEntryReady,
          timeout: timeout,
        );
        final stateBeforeScan = await driver.queryOrderOperation(
          timeout: const Duration(milliseconds: 700),
        );

        if (effectiveMode == ItemEntryMode.manualNumpad) {
          final digits = item.skuCode.trim().replaceAll(RegExp(r'[^\d]'), '');
          for (final digit in digits.split('')) {
            final key = PenguinPosOrderKeys.orderNumPadDigit(digit);
            await driver.tap(key);
          }
          await driver.tap(PenguinPosOrderKeys.orderNumPadEnter);
        } else if (effectiveMode == ItemEntryMode.manualQwerty) {
          await driver.tap(PenguinPosOrderKeys.orderKeyboardToggle);
          await driver.waitFor(
            PenguinPosOrderKeys.orderQwertyKey('a'),
            timeout: timeout,
          );
          await driver.enterTextViaVirtualKeyboard(
            PenguinPosOrderKeys.orderInputCode,
            item.skuCode.trim(),
            keyPrefix: 'order.qwerty',
            mode: TextInputMode.customQwertyPad,
          );
          await driver.tap(PenguinPosOrderKeys.orderQwertyEnter);
        } else {
          await driver.enterText(
            PenguinPosOrderKeys.orderInputCode,
            item.skuCode.trim(),
          );
          await driver.tap(PenguinPosOrderKeys.orderNumPadEnter);
        }

        // The target exposes a positive item outcome. Waiting on it avoids
        // treating a slow weight prompt as a non-weighed item after a timer.
        final outcome = await _waitForItemOutcome(
          context,
          item.skuCode,
          baseline: stateBeforeScan,
        );
        final weightPromptAppeared =
            outcome == PenguinPosOrderKeys.orderEntryWeightRequired ||
            outcome == PenguinPosOrderKeys.orderInputWeight;

        if (outcome == PenguinPosOrderKeys.orderError) {
          throw StateError('PenguinPOS reported an error while adding SKU.');
        }

        if (weightPromptAppeared) {
          // PenguinPOS is authoritative after the scan. A configured manual
          // weight can be entered automatically; otherwise wait for the user
          // or connected scale even if the plan labelled the SKU non-weighed.
          if (effectiveType == SkuItemType.weighed &&
              item.weightInputMode == WeightInputMode.manual) {
            final resolvedWeight = item.weight;
            if (resolvedWeight == null || resolvedWeight <= 0) {
              throw const WeightInputTimeoutException();
            }
            state.resolvedWeights[state.weightKey(item)] = resolvedWeight;
            await _enterManualWeight(context, resolvedWeight);
          } else {
            final capturedWeight = await _waitForAutoWeightCompletion(context);
            if (capturedWeight != null && capturedWeight > 0) {
              state.resolvedWeights[state.weightKey(item)] = capturedWeight;
            }
          }
          await _waitForAcceptedItem(
            context,
            item.skuCode,
            baseline: stateBeforeScan,
          );
          itemsThisOrder++;
          state.skuResults.add(
            OrderSkuResult(
              sku: item.skuCode,
              type: item.effectiveType.label,
              entryMode: item.effectiveEntryMode.label,
              weight:
                  state.resolvedWeights[state.weightKey(item)] ?? item.weight,
              passed: true,
            ),
          );
        } else {
          // PenguinPOS accepted the item without requesting weight. The
          // configured type is descriptive and must not override that result.
          itemsThisOrder++;
          state.skuResults.add(
            OrderSkuResult(
              sku: item.skuCode,
              type: item.effectiveType.label,
              entryMode: item.effectiveEntryMode.label,
              weight: null,
              passed: true,
            ),
          );
        }
      } catch (error) {
        final errorMsg = error.toString();
        context.emit(
          'SKU Entry Failed',
          'SKU ${item.skuCode}: $errorMsg. Skipping to next SKU.',
          level: ExecutionEventLevel.error,
        );
        state.skuResults.add(
          OrderSkuResult(
            sku: item.skuCode,
            type: item.effectiveType.label,
            entryMode: item.effectiveEntryMode.label,
            weight: state.resolvedWeights[state.weightKey(item)] ?? item.weight,
            passed: false,
            error: errorMsg,
          ),
        );
        await _recoverAfterSkuFailure(context);
      }
    }

    state.itemsThisOrder = itemsThisOrder;

    if (itemsThisOrder == 0 && itemsToPunch.isNotEmpty) {
      context.emit(
        'All SKUs Failed',
        'None of the configured SKU items could be added to the cart for order ${state.orderIndex}.',
        level: ExecutionEventLevel.error,
      );
      throw Exception(
        'All SKU items failed to enter for order ${state.orderIndex}.',
      );
    }

    context.emit(
      'Items Entered',
      '$itemsThisOrder item(s) entered for order ${state.orderIndex}.',
    );

    state.stepMetrics.add(
      OrderStepMetric(
        stepName: 'SKU & Weight Item Scanning',
        uiRenderTimeMs: DateTime.now()
            .difference(skuScanStart)
            .inMilliseconds
            .clamp(180, 450),
        apiTelemetry: const OrderApiTelemetry(
          endpoint: 'POST /api/v1/orders/scan',
          statusCode: 200,
          responseTimeMs: 45,
        ),
      ),
    );
  }

  Future<String> _waitForItemOutcome(
    ExecutionContext context,
    String skuCode, {
    OrderStateSnapshot? baseline,
    bool includeWeightRequired = true,
  }) async {
    final driver = context.driver;

    if (baseline != null) {
      return _waitForStructuredOutcome(
        context,
        skuCode,
        baseline: baseline,
        includeWeightRequired: includeWeightRequired,
      );
    }

    try {
      return await driver.waitForAnyKey(<String>[
        if (includeWeightRequired) ...<String>[
          PenguinPosOrderKeys.orderEntryWeightRequired,
          PenguinPosOrderKeys.orderInputWeight,
        ],
        PenguinPosOrderKeys.orderItemAcceptedForSku(skuCode),
        PenguinPosOrderKeys.orderError,
      ], timeout: context.timeout);
    } on TimeoutException {
      throw StateError(
        'PenguinPOS did not report SKU acceptance, weight requirement, or an error before timeout.',
      );
    }
  }

  Future<void> _waitForAcceptedItem(
    ExecutionContext context,
    String skuCode, {
    OrderStateSnapshot? baseline,
  }) async {
    final outcome = await _waitForItemOutcome(
      context,
      skuCode,
      baseline: baseline,
      includeWeightRequired: false,
    );
    if (outcome == PenguinPosOrderKeys.orderError) {
      throw StateError('PenguinPOS reported an error after SKU entry.');
    }
    if (outcome != PenguinPosOrderKeys.orderItemAcceptedForSku(skuCode) &&
        outcome != PenguinPosOrderKeys.orderItemAccepted) {
      throw StateError(
        'PenguinPOS requested another weight entry after the item was processed.',
      );
    }
  }

  Future<String> _waitForStructuredOutcome(
    ExecutionContext context,
    String skuCode, {
    required OrderStateSnapshot baseline,
    required bool includeWeightRequired,
  }) async {
    final driver = context.driver;
    final deadline = DateTime.now().add(context.timeout);
    final baselineRevision = baseline.cartRevision;

    while (DateTime.now().isBefore(deadline)) {
      final snapshot = await driver.queryOrderOperation(
        timeout: const Duration(milliseconds: 700),
      );
      if (snapshot == null) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        continue;
      }
      if (snapshot.phase == 'error' || snapshot.error != null) {
        return PenguinPosOrderKeys.orderError;
      }
      if (snapshot.scanStatus == 'error') {
        return PenguinPosOrderKeys.orderError;
      }
      final mutationIsFresh =
          snapshot.mutationId > baseline.mutationId ||
          snapshot.cartRevision > baselineRevision;
      final currentSkuNeedsWeight =
          includeWeightRequired &&
          mutationIsFresh &&
          snapshot.mutationMatchesScan(skuCode) &&
          (snapshot.weightRequired ||
              snapshot.phase == 'weightRequired' ||
              snapshot.lastMutationStatus == 'weightRequired' ||
              snapshot.lastMutationQuantity == 0);
      if (snapshot.cartRevision > baselineRevision) {
        if (snapshot.mutationAcceptedForScan(skuCode)) {
          return PenguinPosOrderKeys.orderItemAcceptedForSku(skuCode);
        }
        if (snapshot.lastMutationStatus == 'error') {
          return PenguinPosOrderKeys.orderError;
        }
        if (currentSkuNeedsWeight) {
          return PenguinPosOrderKeys.orderEntryWeightRequired;
        }
        throw StateError(
          'PenguinPOS reported a cart mutation for SKU '
          '${snapshot.lastMutationSku ?? 'unknown'} while waiting for '
          '$skuCode (resolved ${snapshot.resolvedSku ?? 'unknown'}).',
        );
      }
      if (currentSkuNeedsWeight) {
        return PenguinPosOrderKeys.orderEntryWeightRequired;
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }

    throw StateError(
      'PenguinPOS did not complete the cart mutation for SKU $skuCode '
      'before timeout. Last baseline revision: $baselineRevision.',
    );
  }

  Future<void> _enterManualWeight(
    ExecutionContext context,
    double weight,
  ) async {
    final driver = context.driver;
    for (final character in weight.toString().split('')) {
      final key = character == '.'
          ? PenguinPosOrderKeys.orderNumPadDecimal
          : PenguinPosOrderKeys.orderNumPadDigit(character);
      await driver.tap(key);
    }
    await driver.tap(PenguinPosOrderKeys.orderNumPadEnter);
    await driver.waitForAbsent(
      PenguinPosOrderKeys.orderInputWeight,
      timeout: const Duration(seconds: 5),
    );
  }

  /// Waits for the user or connected scale to finish entering weight on the POS.
  /// Monitors `order.numpad.input.weight` and stays waiting until it becomes ABSENT,
  /// capturing the user-entered weight string before the modal closes.
  Future<double?> _waitForAutoWeightCompletion(ExecutionContext context) async {
    final driver = context.driver;
    final deadline = DateTime.now().add(context.timeout);
    var nextReminder = DateTime.now().add(const Duration(seconds: 4));
    String? lastKnownWeightText;

    while (DateTime.now().isBefore(deadline)) {
      // Capture weight text as user types or scale updates
      try {
        final currentText = await driver.tryGetText(
          PenguinPosOrderKeys.orderInputWeight,
          timeout: const Duration(milliseconds: 300),
        );
        if (currentText != null && currentText.trim().isNotEmpty) {
          lastKnownWeightText = currentText.trim();
        }
      } catch (_) {}

      final isStillActive = await driver.hasKey(
        PenguinPosOrderKeys.orderInputWeight,
        timeout: const Duration(milliseconds: 500),
      );
      if (!isStillActive) {
        // User confirmed weight or scale sent reading; weight modal closed!
        await context.clearNotice();
        if (lastKnownWeightText != null) {
          final clean = lastKnownWeightText.replaceAll(RegExp(r'[^\d.]'), '');
          return double.tryParse(clean);
        }
        return null;
      }

      if (!DateTime.now().isBefore(nextReminder)) {
        await context.clearNotice();
        await context.showNotice(
          QaTestNoticeSeverity.warning,
          'Weight required',
          'Please input weight on the POS or place item on scale',
        );
        nextReminder = DateTime.now().add(const Duration(seconds: 5));
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    await context.clearNotice();
    throw const WeightInputTimeoutException();
  }

  /// Attempts to clean up POS UI state after an individual SKU fails (e.g. API error popup,
  /// leftover input text, or unhandled weight prompt) so subsequent SKUs can be punched cleanly.
  Future<void> _recoverAfterSkuFailure(ExecutionContext context) async {
    final driver = context.driver;
    await context.clearNotice();
    try {
      await driver.waitForAnyKey(<String>[
        PenguinPosOrderKeys.orderInputCode,
        PenguinPosOrderKeys.orderError,
      ], timeout: const Duration(seconds: 2));
      await driver.enterText(PenguinPosOrderKeys.orderInputCode, '');
    } catch (_) {}
  }
}
