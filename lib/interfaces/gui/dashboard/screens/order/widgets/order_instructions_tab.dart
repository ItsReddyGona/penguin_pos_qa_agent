import 'package:flutter/material.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/test_suite_model.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/order/widgets/scenario_card.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/widgets/qa_panel.dart';

/// Test Cases & Instructions Tab Widget for Order & Cash Payment Suite.
class OrderInstructionsTab extends StatelessWidget {
  const OrderInstructionsTab({
    super.key,
    required this.suite,
    required this.lastExecutionPassed,
    required this.wasAppClosedByUser,
    required this.scenariosCompleted,
    required this.lastExecutionDetails,
    required this.expandedMap,
    required this.allExpanded,
    required this.onToggleExpandAll,
    required this.onToggleExpandScenario,
  });

  final TestSuiteItem suite;
  final bool? lastExecutionPassed;
  final bool wasAppClosedByUser;
  final List<String> scenariosCompleted;
  final String? lastExecutionDetails;
  final Map<String, bool> expandedMap;
  final bool allExpanded;

  final VoidCallback onToggleExpandAll;
  final ValueChanged<String> onToggleExpandScenario;

  @override
  Widget build(BuildContext context) {
    final hasRun = lastExecutionPassed != null || wasAppClosedByUser;
    final scenarios = suite.scenarios;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Scenarios & Execution Steps Header
          Row(
            children: <Widget>[
              QaSectionTitle(
                'Order Test Cases & Scenarios (${scenarios.length})',
              ),
              const Spacer(),
              InkWell(
                onTap: onToggleExpandAll,
                child: Row(
                  children: <Widget>[
                    Icon(
                      allExpanded
                          ? Icons.unfold_less_rounded
                          : Icons.unfold_more_rounded,
                      size: 16,
                      color: const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      allExpanded ? 'Collapse All' : 'Expand All',
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
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: scenarios.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final scenario = scenarios[index];
              final isExpanded = expandedMap[scenario.id] ?? false;

              final isPassed =
                  hasRun &&
                  (lastExecutionPassed == true ||
                      scenariosCompleted.contains(scenario.name) ||
                      scenariosCompleted.contains(scenario.id));

              final isFailed =
                  hasRun &&
                  !isPassed &&
                  !wasAppClosedByUser &&
                  lastExecutionPassed == false &&
                  (scenariosCompleted.length == index ||
                      (!scenariosCompleted.contains(scenario.name) &&
                          !scenariosCompleted.contains(scenario.id)));

              return ScenarioCard(
                scenario: scenario,
                isExpanded: isExpanded,
                isPassed: isPassed,
                isFailed: isFailed,
                wasAppClosedByUser: wasAppClosedByUser,
                lastExecutionDetails: lastExecutionDetails,
                onToggleExpand: () => onToggleExpandScenario(scenario.id),
              );
            },
          ),
        ],
      ),
    );
  }
}
