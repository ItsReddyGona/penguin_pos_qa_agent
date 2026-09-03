import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_ui_tokens.dart';

/// Common frame used by completed suite and order reports.
class AssistantReportCard extends StatelessWidget {
  const AssistantReportCard({
    super.key,
    required this.passed,
    required this.child,
    this.showShadow = false,
  });

  final bool passed;
  final Widget child;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AssistantUiTokens.surface,
        borderRadius: AssistantUiTokens.cardRadius,
        border: Border.all(
          color: passed ? const Color(0xFFA5D6A7) : const Color(0xFFEF9A9A),
          width: 1.5,
        ),
        boxShadow: showShadow
            ? <BoxShadow>[
                BoxShadow(
                  color: passed
                      ? const Color(0x1A4CAF50)
                      : const Color(0x1AE53935),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

/// Header shared by reports that end in a pass or failure state.
class AssistantReportHeader extends StatelessWidget {
  const AssistantReportHeader({
    super.key,
    required this.passed,
    required this.title,
    required this.subtitle,
  });

  final bool passed;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final color = passed ? AssistantUiTokens.success : AssistantUiTokens.error;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: passed ? const Color(0xFFF1F8E9) : const Color(0xFFFFF3E0),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 22,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: passed
                        ? const Color(0xFF1B5E20)
                        : const Color(0xFFB71C1C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AssistantUiTokens.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact table of individual scenario/check outcomes.
class AssistantScenarioResultTable extends StatelessWidget {
  const AssistantScenarioResultTable({
    super.key,
    required this.results,
    required this.formatDuration,
  });

  final List<AiScenarioResult> results;
  final String Function(int milliseconds) formatDuration;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const <int, TableColumnWidth>{
        0: FixedColumnWidth(32),
        1: FlexColumnWidth(),
        2: FixedColumnWidth(40),
        3: FixedColumnWidth(56),
      },
      children: <TableRow>[
        const TableRow(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AssistantUiTokens.divider),
            ),
          ),
          children: <Widget>[
            _ResultHeader('#'),
            _ResultHeader('Scenario'),
            _ResultHeader(''),
            _ResultHeader('Time'),
          ],
        ),
        for (var index = 0; index < results.length; index++)
          TableRow(
            decoration: index < results.length - 1
                ? const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFF5F3EF)),
                    ),
                  )
                : null,
            children: <Widget>[
              _ResultCell('${index + 1}'),
              _ResultCell(results[index].name),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Icon(
                  results[index].passed
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 14,
                  color: results[index].passed
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFE53935),
                ),
              ),
              _ResultCell(formatDuration(results[index].durationMs)),
            ],
          ),
      ],
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AssistantUiTokens.mutedText,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ResultCell extends StatelessWidget {
  const _ResultCell(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Text(
        value,
        style: const TextStyle(fontSize: 11.5, color: AssistantUiTokens.text),
      ),
    );
  }
}

/// Formats durations consistently throughout assistant feedback.
String formatAssistantDuration(int milliseconds) {
  if (milliseconds < 1000) return '${milliseconds}ms';
  return '${(milliseconds / 1000).toStringAsFixed(1)}s';
}
