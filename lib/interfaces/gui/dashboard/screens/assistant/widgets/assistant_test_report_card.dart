import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_report_widgets.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_ui_tokens.dart';

/// Detailed result card for a non-order test suite.
class AssistantTestReportCard extends StatelessWidget {
  const AssistantTestReportCard({super.key, required this.report});

  final AiRichTestReport report;

  @override
  Widget build(BuildContext context) {
    return AssistantReportCard(
      passed: report.passed,
      showShadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AssistantReportHeader(
            passed: report.passed,
            title: report.passed ? 'Suite Passed 🎉' : 'Suite Failed',
            subtitle:
                '${report.suiteTitle} · ${report.profileLabel} — Completed in ${formatAssistantDuration(report.totalDurationMs)}',
          ),
          const Divider(height: 1, color: AssistantUiTokens.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: AssistantScenarioResultTable(
              results: report.scenarioResults,
              formatDuration: formatAssistantDuration,
            ),
          ),
          if (report.cleanupPassed != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
              child: Text(
                report.cleanupPassed!
                    ? 'Cleanup: completed · Suite isolation: ready'
                    : 'Cleanup: failed · Suite isolation: not guaranteed',
                style: TextStyle(
                  fontSize: 12,
                  color: report.cleanupPassed!
                      ? AssistantUiTokens.success
                      : AssistantUiTokens.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          _SuiteSummary(report: report),
        ],
      ),
    );
  }
}

class _SuiteSummary extends StatelessWidget {
  const _SuiteSummary({required this.report});

  final AiRichTestReport report;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: <Widget>[
          _CountChip(
            label: '${report.passedCount} passed',
            textColor: AssistantUiTokens.success,
            backgroundColor: const Color(0xFFE8F5E9),
          ),
          const SizedBox(width: 8),
          if (report.failedCount > 0)
            _CountChip(
              label: '${report.failedCount} failed',
              textColor: AssistantUiTokens.error,
              backgroundColor: const Color(0xFFFFEBEE),
            ),
          const Spacer(),
          Text(
            'Total: ${report.scenarioResults.length} scenario${report.scenarioResults.length == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 11,
              color: AssistantUiTokens.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
  });

  final String label;
  final Color textColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
