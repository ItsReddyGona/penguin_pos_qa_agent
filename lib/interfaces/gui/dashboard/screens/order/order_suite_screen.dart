import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/automation/order/order_runner.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/test_suite_model.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/order/widgets/order_instructions_tab.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/order/widgets/order_results_tab.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/widgets/qa_panel.dart';

/// Screen dedicated to configuring SKU lists, orders count, and running Order & Cash Payment automation test suites.
class OrderSuiteScreen extends StatefulWidget {
  const OrderSuiteScreen({
    super.key,
    required this.suite,
    required this.currentProfile,
    required this.targetMode,
    required this.flutterPath,
    required this.appRoot,
    required this.running,
    required this.lastExecutionPassed,
    required this.lastExecutionDuration,
    required this.lastExecutionDetails,
    required this.wasAppClosedByUser,
    required this.scenariosCompleted,
    required this.orderScenario,
    this.lastOrderRunResult,
    required this.onUpdateScenario,
    required this.onRunSuite,
    required this.onStopSuite,
  });

  final TestSuiteItem suite;
  final QaProfile currentProfile;
  final QaTargetMode targetMode;
  final String flutterPath;
  final String appRoot;

  final bool running;
  final bool? lastExecutionPassed;
  final Duration? lastExecutionDuration;
  final String? lastExecutionDetails;
  final bool wasAppClosedByUser;
  final List<String> scenariosCompleted;

  final OrderScenario orderScenario;
  final OrderRunResult? lastOrderRunResult;
  final ValueChanged<OrderScenario> onUpdateScenario;
  final VoidCallback onRunSuite;
  final VoidCallback onStopSuite;

  @override
  State<OrderSuiteScreen> createState() => _OrderSuiteScreenState();
}

class _OrderSuiteScreenState extends State<OrderSuiteScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Map<String, bool> _expandedMap = <String, bool>{};
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    for (int i = 0; i < widget.suite.scenarios.length; i++) {
      _expandedMap[widget.suite.scenarios[i].id] = true;
    }
  }

  @override
  void didUpdateWidget(OrderSuiteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _allExpanded =>
      widget.suite.scenarios.every((s) => _expandedMap[s.id] == true);

  void _toggleExpandAll() {
    final nextState = !_allExpanded;
    setState(() {
      for (final s in widget.suite.scenarios) {
        _expandedMap[s.id] = nextState;
      }
    });
  }

  void _toggleExpandScenario(String id) {
    setState(() {
      _expandedMap[id] = !(_expandedMap[id] ?? false);
    });
  }

  bool _validateScenario() {
    if (widget.orderScenario.effectiveOrdersCount < 1) {
      setState(
        () =>
            _validationError = 'Number of orders to punch must be at least 1.',
      );
      return false;
    }

    if (widget.orderScenario.inputSourceMode != InputSourceMode.uiForm) {
      final hasParsedOrders =
          widget.orderScenario.effectiveOrdersCount > 0 &&
          widget.orderScenario.getItemsForIteration(1).isNotEmpty;
      if (!hasParsedOrders) {
        setState(
          () => _validationError =
              'The selected import payload does not contain any valid orders.',
        );
        return false;
      }
    }

    for (
      var iteration = 1;
      iteration <= widget.orderScenario.effectiveOrdersCount;
      iteration++
    ) {
      final items = widget.orderScenario.getItemsForIteration(iteration);
      if (items.isEmpty) {
        setState(
          () =>
              _validationError = 'Order #$iteration must contain an SKU item.',
        );
        return false;
      }
      for (var itemIndex = 0; itemIndex < items.length; itemIndex++) {
        final item = items[itemIndex];
        if (item.skuCode.trim().isEmpty) {
          setState(
            () => _validationError =
                'Order #$iteration, item #${itemIndex + 1}: SKU code cannot be empty.',
          );
          return false;
        }
        if (item.isWeighed &&
            item.weightInputMode != WeightInputMode.auto &&
            (item.weight == null || item.weight! <= 0)) {
          setState(
            () => _validationError =
                'Order #$iteration, item #${itemIndex + 1}: enter a positive weight.',
          );
          return false;
        }
      }
    }

    setState(() => _validationError = null);
    return true;
  }

  void _handleRunSuite() {
    if (!_validateScenario()) return;

    if (widget.orderScenario.effectiveOrdersCount > 10) {
      showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Row(
            children: <Widget>[
              Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
              SizedBox(width: 10),
              Text('Large Order Batch Confirmation'),
            ],
          ),
          content: Text(
            'You are about to punch ${widget.orderScenario.effectiveOrdersCount} back-to-back orders in PenguinPOS. Do you want to proceed?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF155EEF),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                widget.onRunSuite();
              },
              child: const Text('Proceed Batch'),
            ),
          ],
        ),
      );
    } else {
      widget.onRunSuite();
    }
  }

  @override
  Widget build(BuildContext context) {
    return QaPanel(
      titleWidget: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.suite.title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.currentProfile.label} · ${widget.targetMode == QaTargetMode.local ? "Local Machine" : "SSH Target"}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          if (widget.running) ...<Widget>[
            OutlinedButton.icon(
              onPressed: widget.onStopSuite,
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: const Text('Stop Test Suite'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF155EEF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: widget.running ? null : _handleRunSuite,
            icon: widget.running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(
              widget.running ? 'Punching Orders...' : 'Run Order Suite',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Suite Description Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.suite.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Executable: ${widget.flutterPath} · App: ${widget.appRoot}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Segmented TabBar matching Login suite design
          Container(
            key: const ValueKey<String>('order-suite-segmented-tabs'),
            width: 340,
            height: 42,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFE9E9EE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF202124),
              unselectedLabelColor: const Color(0xFF7A7D85),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              tabs: const <Widget>[
                Tab(text: 'Test cases'),
                Tab(text: 'Output'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_validationError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _validationError!,
                style: const TextStyle(color: Color(0xFFB91C1C)),
              ),
            ),

          // Tab Body Content View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                OrderInstructionsTab(
                  suite: widget.suite,
                  lastExecutionPassed: widget.lastExecutionPassed,
                  wasAppClosedByUser: widget.wasAppClosedByUser,
                  scenariosCompleted: widget.scenariosCompleted,
                  lastExecutionDetails: widget.lastExecutionDetails,
                  expandedMap: _expandedMap,
                  allExpanded: _allExpanded,
                  onToggleExpandAll: _toggleExpandAll,
                  onToggleExpandScenario: _toggleExpandScenario,
                ),
                OrderResultsTab(
                  result: widget.lastOrderRunResult,
                  lastExecutionPassed: widget.lastExecutionPassed,
                  lastExecutionDetails: widget.lastExecutionDetails,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
