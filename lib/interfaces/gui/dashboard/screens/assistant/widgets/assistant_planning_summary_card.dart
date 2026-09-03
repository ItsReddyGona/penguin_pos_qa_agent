import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_model_trace.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_ui_tokens.dart';

/// A polished, expandable transcript of completed AI planning activity.
///
/// Shares the exact same sleek card container, border, and typography as
/// the live thinking widget to ensure a seamless transition with zero layout jump.
/// Operators can also toggle inspection of the model's raw JSON or reasoning.
class AssistantPlanningSummaryCard extends StatefulWidget {
  const AssistantPlanningSummaryCard({super.key, required this.summary});

  final AiRichPlanningSummary summary;

  @override
  State<AssistantPlanningSummaryCard> createState() =>
      _AssistantPlanningSummaryCardState();
}

class _AssistantPlanningSummaryCardState
    extends State<AssistantPlanningSummaryCard> {
  var _expanded = true;
  var _showRawDetails = false;

  @override
  Widget build(BuildContext context) {
    final stepCount = widget.summary.steps.length;
    final elapsedLabel = _formatElapsed(widget.summary.elapsedMs);
    final reasoning = widget.summary.reasoning?.trim() ?? '';
    final hasReasoning = reasoning.isNotEmpty;
    final hasRawContent =
        widget.summary.rawContent != null &&
        widget.summary.rawContent!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Header Bar matching AssistantModelTrace exactly
          InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: const Color(0xFFE0E7FF)),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 15,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      elapsedLabel == null
                          ? 'Preparation activity · $stepCount checks'
                          : 'Worked for $elapsedLabel · $stepCount checks',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),

          // Animated Smooth Expand/Collapse Checklist & Raw Stream Inspection Body
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 14,
                          right: 14,
                          top: 10,
                          bottom: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            for (final entry in widget.summary.steps.indexed)
                              _PlanningStepLine(
                                label: entry.$2,
                                failed: widget.summary.failedStep == entry.$1,
                              ),

                            // Preserve the exact thought process that was
                            // visible while streaming. Keeping it expanded in
                            // the completed card avoids the abrupt
                            // "evaporation" that previously occurred when the
                            // live planning widget was replaced.
                            if (hasReasoning) ...<Widget>[
                              const SizedBox(height: 8),
                              _CompletedReasoningPanel(reasoning: reasoning),
                            ],

                            // The structured model payload is still available
                            // for technical inspection without competing with
                            // the operator-friendly reasoning transcript.
                            if (hasRawContent) ...<Widget>[
                              const SizedBox(height: 8),
                              InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () => setState(
                                  () => _showRawDetails = !_showRawDetails,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Icon(
                                        _showRawDetails
                                            ? Icons.code_off_rounded
                                            : Icons.code_rounded,
                                        size: 14,
                                        color: const Color(0xFF4F46E5),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _showRawDetails
                                            ? 'Hide raw plan JSON'
                                            : 'View raw plan JSON',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF4F46E5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                                child: _showRawDetails
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: AssistantJsonCodeView(
                                          text: widget.summary.rawContent ?? '',
                                          title: 'Validated Plan JSON',
                                          maxHeight: 320,
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  String? _formatElapsed(int? elapsedMs) {
    if (elapsedMs == null || elapsedMs < 0) return null;
    if (elapsedMs < 1000) return '1s';
    final totalSeconds = (elapsedMs / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return minutes == 0 ? '${seconds}s' : '${minutes}m ${seconds}s';
  }
}

class _CompletedReasoningPanel extends StatelessWidget {
  const _CompletedReasoningPanel({required this.reasoning});

  final String reasoning;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(
                Icons.psychology_outlined,
                size: 14,
                color: Color(0xFF4F46E5),
              ),
              SizedBox(width: 6),
              Text(
                'Thought Process',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4338CA),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            reasoning,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              fontStyle: FontStyle.italic,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanningStepLine extends StatelessWidget {
  const _PlanningStepLine({required this.label, this.failed = false});

  final String label;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 16,
            width: 16,
            child: Icon(
              failed ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              size: 15,
              color: failed ? AssistantUiTokens.error : const Color(0xFF10B981),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: failed
                    ? AssistantUiTokens.error
                    : const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
