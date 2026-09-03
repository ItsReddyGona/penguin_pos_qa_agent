import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/login_test_case.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_report_widgets.dart';

/// Login output in the same clean, structured case table shape as the Manual Login suite.
class AssistantLoginReportCard extends StatelessWidget {
  const AssistantLoginReportCard({super.key, required this.report});

  final AiRichLoginReport report;

  @override
  Widget build(BuildContext context) {
    final suite = report.suite;
    final allPassed = suite.passed && report.cleanupPassed != false;

    return AssistantReportCard(
      passed: allPassed,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AssistantReportHeader(
                passed: allPassed,
                title: allPassed
                    ? 'Login suite output'
                    : 'Login run finished with failures',
                subtitle: '${report.suiteTitle} · ${report.profileLabel}',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  _chip('Total ${suite.totalCount}', const Color(0xFF475569)),
                  _chip('Passed ${suite.passedCount}', const Color(0xFF15803D)),
                  _chip('Failed ${suite.failedCount}', const Color(0xFFB91C1C)),
                  if (suite.notExecutedCount > 0)
                    _chip(
                      'Not executed ${suite.notExecutedCount}',
                      const Color(0xFF64748B),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _buildCaseTable(suite.results),
              if (report.cleanupPassed != null) ...<Widget>[
                const SizedBox(height: 14),
                _statusRow(
                  'Logout Cleanup',
                  report.cleanupPassed == true,
                  report.cleanupDetail ?? 'Session cleanup completed.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaseTable(List<LoginTestCaseResult> results) {
    if (results.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text(
            'No test case results available.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: <Widget>[
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: const Row(
              children: <Widget>[
                Expanded(
                  flex: 4,
                  child: Text(
                    'Test Case',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Color(0xFF475569),
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
                      fontSize: 12,
                      color: Color(0xFF475569),
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
                      fontSize: 12,
                      color: Color(0xFF475569),
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
                      fontSize: 12,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Table Rows with alternating zebra striping
          ...results.asMap().entries.map((entry) {
            final idx = entry.key;
            final result = entry.value;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: idx.isEven ? Colors.white : const Color(0xFFFAFAFA),
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
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            result.testCaseId,
                            style: const TextStyle(
                              fontSize: 10.5,
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
                            fontSize: 12,
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
                      result.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Status (Width 80)
                  SizedBox(
                    width: 80,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _statusChip(result.status.label, result.passed),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Reason / Error (Flex 3)
                  Expanded(
                    flex: 3,
                    child: Text(
                      result.failureReason ?? '—',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: result.passed
                            ? const Color(0xFF64748B)
                            : const Color(0xFFB91C1C),
                        fontWeight: result.passed
                            ? FontWeight.w400
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _statusRow(String title, bool passed, String detail) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: passed ? const Color(0xFFF8FAFC) : const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: passed ? const Color(0xFFE2E8F0) : const Color(0xFFFCA5A5),
      ),
    ),
    child: Row(
      children: <Widget>[
        Icon(
          passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
          size: 16,
          color: passed ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            detail,
            style: TextStyle(
              fontSize: 12,
              color: passed ? const Color(0xFF334155) : const Color(0xFFB91C1C),
            ),
          ),
        ),
        _statusChip(passed ? 'Pass' : 'Fail', passed),
      ],
    ),
  );

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );

  Widget _statusChip(String label, bool passed) {
    final color = passed ? const Color(0xFF15803D) : const Color(0xFFB91C1C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
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
