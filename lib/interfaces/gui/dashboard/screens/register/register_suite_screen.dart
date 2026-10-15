import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/automation/register/register_runner.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/test_suite_model.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/order/widgets/scenario_card.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/widgets/qa_panel.dart';

/// Screen dedicated to displaying and executing Cash Register test cases.
class RegisterSuiteScreen extends StatefulWidget {
  const RegisterSuiteScreen({
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
    this.lastRegisterRunResult,
    required this.wasAppClosedByUser,
    required this.scenariosCompleted,
    required this.openingFloatAmount,
    required this.onRunSuite,
    required this.onStopSuite,
    this.onOpenSettings,
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
  final RegisterRunResult? lastRegisterRunResult;
  final bool wasAppClosedByUser;
  final List<String> scenariosCompleted;
  final double openingFloatAmount;

  final VoidCallback onRunSuite;
  final VoidCallback onStopSuite;
  final VoidCallback? onOpenSettings;

  @override
  State<RegisterSuiteScreen> createState() => _RegisterSuiteScreenState();
}

class _RegisterSuiteScreenState extends State<RegisterSuiteScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Map<String, bool> _expandedMap = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    for (final s in widget.suite.scenarios) {
      _expandedMap[s.id] = true;
    }
  }

  @override
  void didUpdateWidget(RegisterSuiteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.running &&
        !widget.running &&
        (widget.lastExecutionPassed != null || widget.wasAppClosedByUser)) {
      _tabController.animateTo(1);
    }
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

  @override
  Widget build(BuildContext context) {
    final hasRun =
        widget.lastExecutionPassed != null || widget.wasAppClosedByUser;

    return QaPanel(
      titleWidget: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFE5ECE8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.suite.icon,
              size: 20,
              color: const Color(0xFF658A7A),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.suite.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C302E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.suite.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF494C4A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (widget.running)
            ElevatedButton.icon(
              onPressed: widget.onStopSuite,
              icon: const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              label: const Text('Stop Suite'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: widget.onRunSuite,
              icon: const Icon(Icons.play_arrow_rounded, size: 16),
              label: const Text('Run Suite'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF658A7A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            key: const ValueKey<String>('register-suite-segmented-tabs'),
            width: 340,
            height: 42,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFECE6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF2C302E),
              unselectedLabelColor: const Color(0xFF787A76),
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
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                _buildTestCases(hasRun, context),
                _buildOutput(hasRun),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCases(bool hasRun, BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: <Widget>[
        _buildConfigurationBanner(context),
        const SizedBox(height: 16),
        if (hasRun) ...<Widget>[_buildResultCard(), const SizedBox(height: 16)],
        _buildScenariosHeader(),
        const SizedBox(height: 12),
        ...widget.suite.scenarios.map((scenario) {
          final isExpanded = _expandedMap[scenario.id] ?? true;
          final isCompleted =
              widget.scenariosCompleted.contains(scenario.id) ||
              widget.scenariosCompleted.contains(scenario.name);
          final isPassed = widget.lastExecutionPassed == true && isCompleted;
          final isFailed = widget.lastExecutionPassed == false;

          return ScenarioCard(
            scenario: scenario,
            isExpanded: isExpanded,
            isPassed: isPassed,
            isFailed: isFailed,
            wasAppClosedByUser: widget.wasAppClosedByUser,
            lastExecutionDetails: widget.lastExecutionDetails,
            onToggleExpand: () {
              setState(() {
                _expandedMap[scenario.id] = !isExpanded;
              });
            },
          );
        }),
      ],
    );
  }

  Widget _buildOutput(bool hasRun) {
    final passed = widget.lastExecutionPassed == true;
    final closedByUser = widget.wasAppClosedByUser;
    final isReconciliation =
        widget.lastRegisterRunResult?.requiresReconciliation == true ||
        (widget.lastExecutionDetails?.contains('Reconciliation') ?? false);

    return Card(
      elevation: 0,
      color: const Color(0xFFFFFFFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  hasRun ? 'Execution output' : 'Output',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                if (hasRun)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: closedByUser
                          ? const Color(0xFFFEF3C7)
                          : (passed
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFFEE2E2)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      closedByUser
                          ? 'CANCELLED'
                          : (passed ? 'PASSED' : 'FAILED'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: closedByUser
                            ? const Color(0xFFD97706)
                            : (passed
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasRun)
              const Expanded(
                child: Center(
                  child: Text(
                    'Run the Open Register suite to see execution output here.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(
                  children: <Widget>[
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: <Widget>[
                        _summaryChip(
                          'Float: ₹${widget.openingFloatAmount.toInt()}',
                          const Color(0xFF2563EB),
                          const Color(0xFFEFF6FF),
                        ),
                        if (widget.lastExecutionDuration != null)
                          _summaryChip(
                            'Duration: ${(widget.lastExecutionDuration!.inMilliseconds / 1000).toStringAsFixed(1)}s',
                            const Color(0xFF475569),
                            const Color(0xFFF1F5F9),
                          ),
                        _summaryChip(
                          widget.currentProfile.label,
                          const Color(0xFF4F46E5),
                          const Color(0xFFEEF2FF),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (isReconciliation) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFD97706),
                              size: 22,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Reconciliation Required',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Complete the Reconciliation to open New Register. The previous register period must be reconciled and closed before opening a new register.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFB45309),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Execution Details',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.lastExecutionDetails ??
                                (passed
                                    ? 'Register opened successfully with float amount ₹${widget.openingFloatAmount.toInt()}. POS is ready on Orders screen.'
                                    : 'Register opening did not complete successfully.'),
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Color(0xFF1E293B),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildConfigurationBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFBF7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E6E1)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE5ECE8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: Color(0xFF658A7A),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Configured Opening Float Amount',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF494C4A),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Text(
                      '₹${widget.openingFloatAmount.toInt()}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C302E),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5ECE8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.currentProfile.label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C302E),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.onOpenSettings != null)
            OutlinedButton.icon(
              onPressed: widget.onOpenSettings,
              icon: const Icon(Icons.tune_rounded, size: 15),
              label: const Text('Change Float Cash'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2C302E),
                side: const BorderSide(color: Color(0xFFC7C9C4)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final passed = widget.lastExecutionPassed == true;
    final closedByUser = widget.wasAppClosedByUser;

    Color bg;
    Color border;
    IconData icon;
    String title;
    Color iconColor;

    if (closedByUser) {
      bg = const Color(0xFFFFFBEB);
      border = const Color(0xFFFDE68A);
      icon = Icons.cancel_outlined;
      title = 'Execution Cancelled';
      iconColor = const Color(0xFFD97706);
    } else if (passed) {
      bg = const Color(0xFFF0FDF4);
      border = const Color(0xFFBBF7D0);
      icon = Icons.check_circle_outline_rounded;
      title = 'Register Opening Succeeded';
      iconColor = const Color(0xFF16A34A);
    } else {
      bg = const Color(0xFFFEF2F2);
      border = const Color(0xFFFECACA);
      icon = Icons.error_outline_rounded;
      title = 'Register Opening Failed';
      iconColor = const Color(0xFFDC2626);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
                if (widget.lastExecutionDuration != null)
                  Text(
                    'Duration: ${(widget.lastExecutionDuration!.inMilliseconds / 1000).toStringAsFixed(1)}s • Float: ₹${widget.openingFloatAmount.toInt()}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                if (widget.lastExecutionDetails != null && !passed)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      widget.lastExecutionDetails!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenariosHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Text(
              'Test Scenarios',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C302E),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE5ECE8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${widget.suite.scenarios.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C302E),
                ),
              ),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: _toggleExpandAll,
          icon: Icon(
            _allExpanded
                ? Icons.unfold_less_rounded
                : Icons.unfold_more_rounded,
            size: 16,
            color: const Color(0xFF658A7A),
          ),
          label: Text(
            _allExpanded ? 'Collapse All' : 'Expand All',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF658A7A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
