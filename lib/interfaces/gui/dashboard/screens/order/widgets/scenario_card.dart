import 'package:flutter/material.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/test_suite_model.dart';

/// Card widget rendering individual scenario details, steps checkmarks, tags, and error traces.
class ScenarioCard extends StatelessWidget {
  const ScenarioCard({
    super.key,
    required this.scenario,
    required this.isExpanded,
    required this.isPassed,
    required this.isFailed,
    required this.wasAppClosedByUser,
    required this.lastExecutionDetails,
    required this.onToggleExpand,
  });

  final TestSuiteScenario scenario;
  final bool isExpanded;
  final bool isPassed;
  final bool isFailed;
  final bool wasAppClosedByUser;
  final String? lastExecutionDetails;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final colonIdx = scenario.name.indexOf(':');
    final idBadge = colonIdx != -1
        ? scenario.name.substring(0, colonIdx).trim()
        : scenario.id.toUpperCase();
    final displayName = colonIdx != -1
        ? scenario.name.substring(colonIdx + 1).trim()
        : scenario.name;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row matching Login suite card style
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
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
                      idBadge,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Color(0xFF2C302E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  _statusChip(),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),

          // Steps Details Block
          if (isExpanded) ...<Widget>[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (scenario.purpose.isNotEmpty) ...<Widget>[
                    Text(
                      scenario.purpose,
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text(
                    'Execution Steps:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...scenario.stepsDescription.asMap().entries.map((entry) {
                    final stepIdx = entry.key;
                    final stepText = entry.value;
                    final isLastStep =
                        stepIdx == scenario.stepsDescription.length - 1;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${stepIdx + 1}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              stepText,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isFailed && isLastStep
                                    ? const Color(0xFF991B1B)
                                    : const Color(0xFF334155),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (isFailed) ...<Widget>[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Text(
                        lastExecutionDetails ??
                            'Error: Order & payment step execution failed.',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Color(0xFFB91C1C),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  if (scenario.expectedOutcomes.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      'Expected result: ${scenario.expectedOutcomes.join(", ")}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip() {
    final (label, color) = isPassed
        ? ('Passed', const Color(0xFF15803D))
        : (isFailed
              ? ('Failed', const Color(0xFFB91C1C))
              : (wasAppClosedByUser
                    ? ('Stopped', const Color(0xFFB45309))
                    : ('Pending', const Color(0xFF64748B))));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
