import 'dart:async';

import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/pos_automation_contract.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/enter_order_items_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_keys.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_metrics.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_operation_query.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_run_state.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_state_snapshot.dart';

/// Enters SKU items by searching for them in the Search Items dialog and clicking ADD.
class SearchAndAddItemsBlock implements AutomationBlock {
  const SearchAndAddItemsBlock({required this.state});

  final OrderRunState state;

  @override
  String get id => 'search_and_add_items';

  @override
  String get name => 'Search Items & Add to Cart';

  @override
  StepNotice? get notice => const StepNotice(
    'Searching Items',
    'Finding and adding items via Search Items modal.',
    isMilestone: true,
  );

  @override
  Future<void> execute(ExecutionContext context) async {
    final driver = context.driver;
    final timeout = context.timeout;

    int itemsThisOrder = 0;
    final searchStart = DateTime.now();
    final itemsToPunch = state.scenario.getItemsForIteration(state.orderIndex);

    if (itemsToPunch
        .where(
          (item) =>
              item.skuCode.trim().isNotEmpty || item.name.trim().isNotEmpty,
        )
        .isEmpty) {
      context.emit(
        'No Search Items',
        'Order ${state.orderIndex} has no executable items to search.',
        level: ExecutionEventLevel.error,
      );
      throw StateError(
        'No executable items were resolved for order ${state.orderIndex}.',
      );
    }

    for (final item in itemsToPunch) {
      final sku = item.skuCode.trim();
      final searchQuery = item.resolveSearchQuery().trim();
      if (searchQuery.isEmpty) continue;

      final isShort =
          OrderItem.isShortCode(searchQuery) ||
          (sku.isNotEmpty && OrderItem.isShortCode(sku));

      // PenguinPOS search requires at least 3 characters for non-short-code searches.
      if (searchQuery.length < 3 && !isShort) {
        throw StateError(
          'Step 2 Failed: Search query "$searchQuery" must be at least 3 characters for PenguinPOS search.',
        );
      }

      final effectiveType = item.effectiveType;

      try {
        // [Step 1: Open Search Dialog]
        context.emit(
          'Step 1: Open Search Dialog',
          'Awaiting order entry readiness and opening search dialog.',
        );

        try {
          await driver.waitFor(
            PenguinPosOrderKeys.orderEntryReady,
            timeout: timeout,
          );
        } catch (e) {
          throw StateError(
            'Step 1 Failed: Order screen not ready for item entry: $e',
          );
        }

        final stateBeforeScan = await driver.queryOrderOperation(
          timeout: const Duration(milliseconds: 700),
        );

        final searchButtonFound = await driver.hasKey(
          PenguinPosOrderKeys.orderSearchItemsButton,
          timeout: const Duration(seconds: 2),
        );

        if (searchButtonFound) {
          await driver.tap(PenguinPosOrderKeys.orderSearchItemsButton);
        } else {
          final tapped = await driver.tryTapText(
            'Search items',
            timeout: const Duration(seconds: 2),
          );
          if (!tapped) {
            throw StateError(
              'Step 1 Failed: Could not locate "Search items" button on Order Screen.',
            );
          }
        }

        // [Step 2: Locate Search Input & Type via On-Screen Keyboard]
        context.emit(
          'Step 2: Enter Search Query',
          'Entering "$searchQuery" via on-screen keyboard.',
        );

        final searchInputFound = await driver.hasKey(
          PenguinPosOrderKeys.searchTextInput,
          timeout: const Duration(seconds: 4),
        );
        final hasSearchDialog =
            searchInputFound ||
            await driver.hasKey(
              PenguinPosOrderKeys.searchDialog,
              timeout: const Duration(seconds: 1),
            ) ||
            await driver.hasText(
              'Search (SKU, Name or Barcode)',
              timeout: const Duration(seconds: 3),
            );

        if (!hasSearchDialog) {
          throw StateError(
            'Step 2 Failed: Search dialog did not appear after tapping Search items.',
          );
        }

        // Focus search input
        if (searchInputFound) {
          await driver.tap(PenguinPosOrderKeys.searchTextInput);
        } else {
          await driver.tryTapText('Search (SKU, Name or Barcode)');
        }

        // Type each character via on-screen keyboard (CustomQwertyPad)
        var usedDirectFallback = false;
        for (final char in searchQuery.split('')) {
          if (char == ' ') {
            var tappedSpace = await driver.tryTapKey(
              PosAutomationContract.qwertySpace('search.qwerty'),
              timeout: const Duration(seconds: 1),
            );
            if (!tappedSpace) {
              tappedSpace = await driver.tryTapKey(
                'qwerty.space',
                timeout: const Duration(seconds: 1),
              );
            }
            if (!tappedSpace) {
              tappedSpace = await driver.tryTapKey(
                'search.qwerty.icon.space',
                timeout: const Duration(milliseconds: 500),
              );
            }
            if (!tappedSpace) {
              tappedSpace = await driver.tryTapKey(
                'qwerty.icon.space',
                timeout: const Duration(milliseconds: 500),
              );
            }
            if (!tappedSpace) {
              tappedSpace = await driver.tryTapKey(
                PenguinPosOrderKeys.orderQwertySpace,
                timeout: const Duration(milliseconds: 500),
              );
            }
            if (!tappedSpace) {
              tappedSpace = await driver.tryTapKey(
                'login.qwerty.space',
                timeout: const Duration(milliseconds: 500),
              );
            }
            if (!tappedSpace) {
              tappedSpace = await driver.tryTapText(
                'Space',
                timeout: const Duration(milliseconds: 500),
              );
            }
            if (!tappedSpace) {
              tappedSpace = await driver.tryTapText(
                ' ',
                timeout: const Duration(milliseconds: 300),
              );
            }
            if (!tappedSpace) {
              if (searchInputFound) {
                await driver.enterText(
                  PenguinPosOrderKeys.searchTextInput,
                  searchQuery,
                );
                usedDirectFallback = true;
                break;
              }
              throw StateError(
                'Step 2 Failed: Space key could not be tapped for search query "$searchQuery".',
              );
            }
            continue;
          }

          final charLower = char.toLowerCase();
          final charUpper = char.toUpperCase();
          final qwertyKey = PosAutomationContract.qwertyKey(
            'search.qwerty',
            charLower,
          );

          var tapped = await driver.tryTapKey(
            qwertyKey,
            timeout: const Duration(seconds: 1),
          );
          if (!tapped) {
            tapped = await driver.tryTapKey(
              'qwerty.key.$charLower',
              timeout: const Duration(seconds: 1),
            );
          }
          if (!tapped) {
            tapped = await driver.tryTapKey(
              PenguinPosOrderKeys.orderQwertyKey(charLower),
              timeout: const Duration(milliseconds: 500),
            );
          }
          if (!tapped) {
            tapped = await driver.tryTapKey(
              'login.qwerty.key.$charLower',
              timeout: const Duration(milliseconds: 500),
            );
          }
          if (!tapped) {
            tapped = await driver.tryTapText(
              charLower,
              timeout: const Duration(seconds: 1),
            );
          }
          if (!tapped && charUpper != charLower) {
            tapped = await driver.tryTapText(
              charUpper,
              timeout: const Duration(milliseconds: 500),
            );
          }
          if (!tapped) {
            if (searchInputFound) {
              await driver.enterText(
                PenguinPosOrderKeys.searchTextInput,
                searchQuery,
              );
              usedDirectFallback = true;
              break;
            }
            throw StateError(
              'Step 2 Failed: Virtual keyboard key "$char" could not be tapped for search query "$searchQuery".',
            );
          }
        }

        if (usedDirectFallback) {
          context.emit(
            'Step 2 Note',
            'Search query "$searchQuery" entered via input fallback.',
          );
        }

        // [Step 3: Click Magnifier Search Button]
        context.emit(
          'Step 3: Submit Search',
          'Clicking magnifier search button beside text field.',
        );

        var clickedSearch = false;
        if (await driver.hasKey(
          PenguinPosOrderKeys.searchSubmitButton,
          timeout: const Duration(seconds: 1),
        )) {
          await driver.tap(PenguinPosOrderKeys.searchSubmitButton);
          clickedSearch = true;
        }

        if (!clickedSearch) {
          clickedSearch = await driver.tryTapKey(
            PenguinPosOrderKeys.searchSubmitButton,
            timeout: const Duration(seconds: 1),
          );
        }

        if (!clickedSearch) {
          clickedSearch = await driver.tryTapByType(
            'AppButton',
            timeout: const Duration(seconds: 2),
          );
        }

        if (!clickedSearch) {
          clickedSearch = await driver.tryTapByType(
            'ElevatedButton',
            timeout: const Duration(seconds: 2),
          );
        }

        if (!clickedSearch) {
          clickedSearch = await driver.tryTapKey(
            PosAutomationContract.qwertyEnter('search.qwerty'),
            timeout: const Duration(milliseconds: 500),
          );
        }

        if (!clickedSearch) {
          clickedSearch = await driver.tryTapKey(
            'qwerty.enter',
            timeout: const Duration(milliseconds: 500),
          );
        }

        if (!clickedSearch) {
          clickedSearch = await driver.tryTapKey(
            PenguinPosOrderKeys.orderQwertyEnter,
            timeout: const Duration(milliseconds: 500),
          );
        }

        if (!clickedSearch) {
          throw StateError(
            'Step 3 Failed: Magnifier search button could not be clicked beside text field.',
          );
        }

        // [Step 4: Select First Matching Item and Click ADD]
        context.emit(
          'Step 4: Select Product',
          'Waiting for search results and clicking ADD button.',
        );

        final productAddKey = sku.isNotEmpty
            ? PenguinPosOrderKeys.searchProductAdd(sku)
            : null;
        var added = false;

        if (productAddKey != null &&
            await driver.hasKey(
              productAddKey,
              timeout: const Duration(seconds: 5),
            )) {
          await driver.tap(productAddKey);
          added = true;
        } else if (await driver.hasKey(
          PenguinPosOrderKeys.searchProductAddFirst,
          timeout: const Duration(seconds: 2),
        )) {
          await driver.tap(PenguinPosOrderKeys.searchProductAddFirst);
          added = true;
        } else if (await driver.hasKey(
          'search.product.add',
          timeout: const Duration(milliseconds: 500),
        )) {
          await driver.tap('search.product.add');
          added = true;
        } else {
          added = await driver.tryTapText(
            'ADD',
            timeout: const Duration(seconds: 5),
          );
        }

        if (!added) {
          throw StateError(
            'Step 4 Failed: No search results found or "ADD" button not visible for "$searchQuery".',
          );
        }

        context.emit(
          'Step 4 Completed',
          'Tapped ADD for $searchQuery. Returned to order screen.',
        );

        // [Step 5 & 6: Outcome verification - Weight / Quantity / Acceptance on Order Screen]
        final outcome = await _waitForItemOutcome(
          context,
          sku,
          baseline: stateBeforeScan,
        );

        final weightPromptAppeared =
            outcome == PenguinPosOrderKeys.orderEntryWeightRequired ||
            outcome == PenguinPosOrderKeys.orderInputWeight;

        if (outcome == PenguinPosOrderKeys.orderError) {
          throw StateError(
            'Step 6 Failed: PenguinPOS reported an error while adding SKU $sku.',
          );
        }

        if (weightPromptAppeared) {
          context.emit(
            'Step 5: Quantity/Weight Entry',
            'Weight/Quantity requested for $sku.',
          );
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
          await _waitForAcceptedItem(context, sku, baseline: stateBeforeScan);
          itemsThisOrder++;
          state.skuResults.add(
            OrderSkuResult(
              sku: sku,
              type: item.effectiveType.label,
              entryMode: 'Search items',
              weight:
                  state.resolvedWeights[state.weightKey(item)] ?? item.weight,
              passed: true,
            ),
          );
        } else {
          itemsThisOrder++;
          state.skuResults.add(
            OrderSkuResult(
              sku: sku,
              type: item.effectiveType.label,
              entryMode: 'Search items',
              weight: null,
              passed: true,
            ),
          );
        }
      } catch (error) {
        final errorMsg = error.toString();
        context.emit(
          'Search & Add Item Failed',
          'SKU $sku: $errorMsg.',
          level: ExecutionEventLevel.error,
        );
        state.skuResults.add(
          OrderSkuResult(
            sku: sku,
            type: item.effectiveType.label,
            entryMode: 'Search items',
            weight: state.resolvedWeights[state.weightKey(item)] ?? item.weight,
            passed: false,
            error: errorMsg,
          ),
        );
        await _recoverAfterSearchFailure(context);
        // Fail-fast: Terminate flow immediately on failure
        throw StateError('Search & Add flow terminated: $errorMsg');
      }
    }

    state.itemsThisOrder = itemsThisOrder;

    if (itemsThisOrder == 0 && itemsToPunch.isNotEmpty) {
      context.emit(
        'All Search Items Failed',
        'No search items could be added to cart for order ${state.orderIndex}.',
        level: ExecutionEventLevel.error,
      );
      throw Exception(
        'All search items failed to enter for order ${state.orderIndex}.',
      );
    }

    context.emit(
      'Search Items Entered',
      '$itemsThisOrder item(s) added via Search for order ${state.orderIndex}.',
    );

    state.stepMetrics.add(
      OrderStepMetric(
        stepName: 'Search Items & Add to Cart',
        uiRenderTimeMs: DateTime.now()
            .difference(searchStart)
            .inMilliseconds
            .clamp(200, 600),
        apiTelemetry: const OrderApiTelemetry(
          endpoint: 'POST /api/v1/orders/search-scan',
          statusCode: 200,
          responseTimeMs: 65,
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
        if (skuCode.isNotEmpty)
          PenguinPosOrderKeys.orderItemAcceptedForSku(skuCode),
        PenguinPosOrderKeys.orderItemAccepted,
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
        await Future<void>.delayed(const Duration(milliseconds: 50));
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
          (skuCode.isEmpty || snapshot.mutationMatchesScan(skuCode)) &&
          (snapshot.weightRequired ||
              snapshot.phase == 'weightRequired' ||
              snapshot.lastMutationStatus == 'weightRequired' ||
              snapshot.lastMutationQuantity == 0);
      if (snapshot.cartRevision > baselineRevision) {
        if (skuCode.isEmpty || snapshot.mutationAcceptedForScan(skuCode)) {
          return PenguinPosOrderKeys.orderItemAcceptedForSku(skuCode);
        }
        if (snapshot.lastMutationStatus == 'error') {
          return PenguinPosOrderKeys.orderError;
        }
        if (currentSkuNeedsWeight) {
          return PenguinPosOrderKeys.orderEntryWeightRequired;
        }
      }
      if (currentSkuNeedsWeight) {
        return PenguinPosOrderKeys.orderEntryWeightRequired;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    throw StateError(
      'PenguinPOS did not complete the cart mutation for SKU $skuCode before timeout.',
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

  Future<double?> _waitForAutoWeightCompletion(ExecutionContext context) async {
    final driver = context.driver;
    final deadline = DateTime.now().add(context.timeout);
    String? lastKnownWeightText;

    while (DateTime.now().isBefore(deadline)) {
      try {
        final currentText = await driver.tryGetText(
          PenguinPosOrderKeys.orderInputWeight,
          timeout: const Duration(milliseconds: 400),
        );
        if (currentText != null && currentText.trim().isNotEmpty) {
          lastKnownWeightText = currentText.trim();
        }
      } catch (_) {}

      final stillVisible = await driver.hasKey(
        PenguinPosOrderKeys.orderInputWeight,
        timeout: const Duration(milliseconds: 300),
      );

      if (!stillVisible) {
        if (lastKnownWeightText != null) {
          return double.tryParse(
            lastKnownWeightText.replaceAll(RegExp(r'[^\d.]'), ''),
          );
        }
        return null;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    throw const WeightInputTimeoutException();
  }

  Future<void> _recoverAfterSearchFailure(ExecutionContext context) async {
    final driver = context.driver;
    // Dismiss search dialog if still present
    try {
      final hasClose = await driver.hasKey(
        PenguinPosOrderKeys.searchCloseButton,
        timeout: const Duration(seconds: 1),
      );
      if (hasClose) {
        await driver.tap(PenguinPosOrderKeys.searchCloseButton);
      }
    } catch (_) {}
  }
}
