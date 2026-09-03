import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/login_test_case.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/test_suite_model.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/order/widgets/scenario_card.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/widgets/qa_panel.dart';

/// Screen dedicated to displaying and executing Login & Terminal test cases matching the design mockup.
class LoginSuiteScreen extends StatefulWidget {
  const LoginSuiteScreen({
    super.key,
    required this.suite,
    required this.currentProfile,
    required this.loginId,
    required this.password,
    required this.targetMode,
    required this.flutterPath,
    required this.appRoot,
    required this.running,
    required this.lastExecutionPassed,
    required this.lastExecutionDuration,
    required this.lastExecutionDetails,
    required this.wasAppClosedByUser,
    required this.scenariosCompleted,
    required this.onLoginIdChanged,
    required this.onPasswordChanged,
    required this.onRunSuite,
    required this.onStopSuite,
    this.configuredCases = const <LoginTestCaseDefinition>[],
    this.lastLoginSuiteResult,
  });

  final TestSuiteItem suite;
  final QaProfile currentProfile;
  final String loginId;
  final String password;
  final QaTargetMode targetMode;
  final String flutterPath;
  final String appRoot;

  final bool running;
  final bool? lastExecutionPassed;
  final Duration? lastExecutionDuration;
  final String? lastExecutionDetails;
  final bool wasAppClosedByUser;
  final List<String> scenariosCompleted;

  final ValueChanged<String> onLoginIdChanged;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onRunSuite;
  final VoidCallback onStopSuite;
  final List<LoginTestCaseDefinition> configuredCases;
  final LoginSuiteResult? lastLoginSuiteResult;

  @override
  State<LoginSuiteScreen> createState() => _LoginSuiteScreenState();
}

class _LoginSuiteScreenState extends State<LoginSuiteScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Map<String, bool> _expandedMap = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Default: expand scenario 1 & 2, collapse 3 to match mockup
    for (int i = 0; i < widget.suite.scenarios.length; i++) {
      _expandedMap[widget.suite.scenarios[i].id] = i < 2;
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
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF155EEF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: widget.running ? null : widget.onRunSuite,
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
              widget.running ? 'Running Suite...' : 'Run Suite',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          if (widget.running) ...<Widget>[
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: widget.onStopSuite,
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: const Text('Stop Test Case'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            key: const ValueKey<String>('login-suite-segmented-tabs'),
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
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[_buildTestCases(hasRun), _buildOutput(hasRun)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCases(bool hasRun) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      // Description Box
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
                Icons.info_outline_rounded,
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
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),

      // Scenarios Header & Expand/Collapse All Control
      Row(
        children: <Widget>[
          QaSectionTitle(
            widget.configuredCases.isEmpty
                ? 'Scenarios & Execution Steps (${widget.suite.scenarios.length})'
                : 'Login Test Cases (${widget.configuredCases.length})',
          ),
          const Spacer(),
          InkWell(
            onTap: _toggleExpandAll,
            child: Row(
              children: <Widget>[
                Icon(
                  _allExpanded
                      ? Icons.unfold_less_rounded
                      : Icons.unfold_more_rounded,
                  size: 16,
                  color: const Color(0xFF2563EB),
                ),
                const SizedBox(width: 4),
                Text(
                  _allExpanded ? 'Collapse All' : 'Expand All',
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),

      // Scenarios Cards List
      Expanded(
        child: widget.configuredCases.isNotEmpty
            ? _buildConfiguredCaseList(hasRun)
            : ListView.separated(
                itemCount: widget.suite.scenarios.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final scenario = widget.suite.scenarios[index];
                  final isExpanded = _expandedMap[scenario.id] ?? false;

                  final isPassed =
                      hasRun &&
                      (widget.lastExecutionPassed == true ||
                          widget.scenariosCompleted.contains(scenario.name) ||
                          widget.scenariosCompleted.contains(scenario.id));

                  final isFailed =
                      hasRun &&
                      !isPassed &&
                      !widget.wasAppClosedByUser &&
                      widget.lastExecutionPassed == false &&
                      (widget.scenariosCompleted.length == index ||
                          (!widget.scenariosCompleted.contains(scenario.name) &&
                              !widget.scenariosCompleted.contains(
                                scenario.id,
                              )));

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
                },
              ),
      ),
    ],
  );

  Widget _buildConfiguredCaseList(bool hasRun) => ListView.separated(
    itemCount: widget.configuredCases.length,
    separatorBuilder: (_, _) => const SizedBox(height: 12),
    itemBuilder: (context, index) {
      final testCase = widget.configuredCases[index];
      final matchingResults = widget.lastLoginSuiteResult?.results
          .where((item) => item.testCaseId == testCase.id)
          .toList(growable: false);
      final result = matchingResults == null || matchingResults.isEmpty
          ? null
          : matchingResults.first;
      return Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5ECE8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      testCase.id,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      testCase.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _statusChip(
                    result?.status ??
                        (hasRun
                            ? LoginTestCaseStatus.notExecuted
                            : LoginTestCaseStatus.pending),
                  ),
                ],
              ),
              if (testCase.description.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  testCase.description,
                  style: const TextStyle(color: Color(0xFF475569)),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Expected result: ${testCase.expectedResult.label}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              if (result?.failureReason != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  result!.failureReason!,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );

  Widget _statusChip(LoginTestCaseStatus status) {
    final color = switch (status) {
      LoginTestCaseStatus.passed => const Color(0xFF15803D),
      LoginTestCaseStatus.failed => const Color(0xFFB91C1C),
      LoginTestCaseStatus.notExecuted => const Color(0xFF64748B),
      _ => const Color(0xFF64748B),
    };
    return Chip(
      label: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.10),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildOutput(bool hasRun) => Card(
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
          Text(
            hasRun ? 'Execution output' : 'Output',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          if (widget.lastLoginSuiteResult != null)
            Expanded(
              child: _buildConfiguredOutput(widget.lastLoginSuiteResult!),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  hasRun
                      ? (widget.lastExecutionDetails ??
                            'Execution completed without additional details.')
                      : 'Run the login suite to see execution output here.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _buildConfiguredOutput(LoginSuiteResult suite) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Wrap(
        spacing: 10,
        runSpacing: 8,
        children: <Widget>[
          _summaryChip('Total ${suite.totalCount}', const Color(0xFF475569)),
          _summaryChip('Passed ${suite.passedCount}', const Color(0xFF15803D)),
          _summaryChip('Failed ${suite.failedCount}', const Color(0xFFB91C1C)),
          if (suite.notExecutedCount > 0)
            _summaryChip(
              'Not executed ${suite.notExecutedCount}',
              const Color(0xFF64748B),
            ),
        ],
      ),
      const SizedBox(height: 12),
      // Table Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
          border: Border(
            top: BorderSide(color: Color(0xFFE2E8F0)),
            left: BorderSide(color: Color(0xFFE2E8F0)),
            right: BorderSide(color: Color(0xFFE2E8F0)),
            bottom: BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        child: const Row(
          children: <Widget>[
            Expanded(
              flex: 4,
              child: Text(
                'Test Case',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: Color(0xFF334155),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: Text(
                'Description',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: Color(0xFF334155),
                ),
              ),
            ),
            SizedBox(width: 12),
            SizedBox(
              width: 80,
              child: Text(
                'Status',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: Color(0xFF334155),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                'Reason / Error',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
      // Table Body
      Expanded(
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0xFFE2E8F0)),
              right: BorderSide(color: Color(0xFFE2E8F0)),
              bottom: BorderSide(color: Color(0xFFE2E8F0)),
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
          ),
          child: ListView.separated(
            itemCount: suite.results.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, index) {
              final result = suite.results[index];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                color: index.isEven ? Colors.white : const Color(0xFFFAFAFA),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    // Test Case ID + Name (Flex 4)
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              result.testCaseId,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            result.testCase,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Description (Flex 4)
                    Expanded(
                      flex: 4,
                      child: Text(
                        result.description.isEmpty ? '—' : result.description,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Status (Width 80)
                    SizedBox(
                      width: 80,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _statusChip(result.status),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Reason / Error (Flex 3)
                    Expanded(
                      flex: 3,
                      child: Text(
                        result.failureReason ?? '—',
                        style: TextStyle(
                          color: result.failureReason == null
                              ? const Color(0xFF64748B)
                              : const Color(0xFFB91C1C),
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ],
  );

  Widget _summaryChip(String label, Color color) => Chip(
    label: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
    ),
    backgroundColor: color.withValues(alpha: 0.10),
    side: BorderSide.none,
    visualDensity: VisualDensity.compact,
  );
}
