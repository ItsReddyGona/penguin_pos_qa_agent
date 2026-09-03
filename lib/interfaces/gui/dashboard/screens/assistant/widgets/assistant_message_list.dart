import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_execution_tracker.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_model_trace.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_rich_message.dart';

/// Conversation message list displaying left-aligned assistant text & right-aligned user bubbles.
class AssistantMessageList extends StatelessWidget {
  const AssistantMessageList({
    super.key,
    required this.messages,
    required this.scrollController,
    this.planningEvents = const <AiModelEvent>[],
    this.planningRunning = false,
    this.liveStream = '',
    this.liveReasoning = '',
    this.executionSteps = const <AiExecutionStep>[],
    this.executionSuiteTitle = '',
    this.executionProfileLabel = '',
    this.executionRunning = false,
    this.onEditAndRetrigger,
    this.onRetrigger,
    this.onCopyText,
    this.onRunPlan,
    this.onOpenPlanInManualMode,
  });

  final List<AiChatMessage> messages;
  final ScrollController scrollController;
  final List<AiModelEvent> planningEvents;
  final bool planningRunning;
  final String liveStream;
  final String liveReasoning;
  final List<AiExecutionStep> executionSteps;
  final String executionSuiteTitle;
  final String executionProfileLabel;
  final bool executionRunning;
  final void Function(int index, String newText)? onEditAndRetrigger;
  final void Function(int index)? onRetrigger;
  final void Function(String text)? onCopyText;
  final ValueChanged<AiTestPlan>? onRunPlan;
  final ValueChanged<AiTestPlan>? onOpenPlanInManualMode;

  @override
  Widget build(BuildContext context) {
    final showExecution = executionSteps.isNotEmpty;
    // Once planning finishes, the same activity is retained on the completed
    // assistant message. Keeping this temporary trace during execution would
    // render every planning check twice.
    final showPlanning = planningEvents.isNotEmpty && planningRunning;
    final inlineStatusCount = (showPlanning ? 1 : 0) + (showExecution ? 1 : 0);
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.only(top: 16, bottom: 24),
        itemCount: messages.length + inlineStatusCount,
        itemBuilder: (context, index) {
          if (showPlanning && index == messages.length) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.only(top: 3, right: 12),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          size: 16,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                      Expanded(
                        child: AssistantModelTrace(
                          events: planningEvents,
                          running: planningRunning,
                          liveStream: liveStream,
                          liveReasoning: liveReasoning,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          if (showExecution &&
              index == messages.length + (showPlanning ? 1 : 0)) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: AssistantExecutionTracker(
                steps: executionSteps,
                suiteTitle: executionSuiteTitle,
                profileLabel: executionProfileLabel,
                running: executionRunning,
              ),
            );
          }
          final message = messages[index];
          if (message.role == AiChatRole.user) {
            return _UserMessageTile(
              messageIndex: index,
              message: message,
              onEditAndRetrigger: onEditAndRetrigger,
              onCopyText: onCopyText,
            );
          }

          return _AssistantMessageTile(
            messageIndex: index,
            message: message,
            onRetrigger: onRetrigger,
            onCopyText: onCopyText,
            onRunPlan: onRunPlan,
            onOpenPlanInManualMode: onOpenPlanInManualMode,
          );
        },
      ),
    );
  }
}

class _UserMessageTile extends StatefulWidget {
  const _UserMessageTile({
    required this.messageIndex,
    required this.message,
    this.onEditAndRetrigger,
    this.onCopyText,
  });

  final int messageIndex;
  final AiChatMessage message;
  final void Function(int index, String newText)? onEditAndRetrigger;
  final void Function(String text)? onCopyText;

  @override
  State<_UserMessageTile> createState() => _UserMessageTileState();
}

class _UserMessageTileState extends State<_UserMessageTile> {
  bool _isEditing = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.message.text);
  }

  @override
  void didUpdateWidget(covariant _UserMessageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.text != widget.message.text && !_isEditing) {
      _controller.text = widget.message.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitEdit() {
    final updatedText = _controller.text.trim();
    if (updatedText.isNotEmpty) {
      setState(() => _isEditing = false);
      widget.onEditAndRetrigger?.call(widget.messageIndex, updatedText);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 580),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F4F0),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF7C3AED), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: _controller,
                  maxLines: null,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF2C302E),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: (_) => _submitEdit(),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isEditing = false;
                          _controller.text = widget.message.text;
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _submitEdit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Save & Re-trigger',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Container(
              constraints: const BoxConstraints(maxWidth: 700),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F4F0),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFC7C9C4)),
              ),
              child: SelectableText(
                widget.message.text,
                style: const TextStyle(
                  fontSize: 14.5,
                  color: Color(0xFF2C302E),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _ActionButton(
                  icon: Icons.copy_rounded,
                  tooltip: 'Copy text',
                  onTap: () => widget.onCopyText?.call(widget.message.text),
                ),
                const SizedBox(width: 4),
                _ActionButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit & Re-trigger',
                  onTap: () => setState(() => _isEditing = true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantMessageTile extends StatelessWidget {
  const _AssistantMessageTile({
    required this.messageIndex,
    required this.message,
    this.onRetrigger,
    this.onCopyText,
    this.onRunPlan,
    this.onOpenPlanInManualMode,
  });

  final int messageIndex;
  final AiChatMessage message;
  final void Function(int index)? onRetrigger;
  final void Function(String text)? onCopyText;
  final ValueChanged<AiTestPlan>? onRunPlan;
  final ValueChanged<AiTestPlan>? onOpenPlanInManualMode;

  @override
  Widget build(BuildContext context) {
    final richContent = message.richContent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 3, right: 12),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: Color(0xFF7C3AED),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (message.activitySummary != null) ...<Widget>[
                      AssistantRichMessage(content: message.activitySummary!),
                      if (message.text.isNotEmpty || richContent != null)
                        const SizedBox(height: 8),
                    ],
                    if (message.text.isNotEmpty)
                      SelectableText(
                        message.text,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.55,
                          color: Color(0xFF2C302E),
                          letterSpacing: -0.1,
                        ),
                      ),
                    if (richContent != null) ...<Widget>[
                      if (message.text.isNotEmpty) const SizedBox(height: 12),
                      AssistantRichMessage(
                        content: richContent,
                        onRunValidatedPlan: message.executablePlan == null
                            ? null
                            : () => onRunPlan?.call(message.executablePlan!),
                        onOpenInManualMode: message.executablePlan == null
                            ? null
                            : () => onOpenPlanInManualMode?.call(
                                message.executablePlan!,
                              ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (message.text.isNotEmpty)
                          _ActionButton(
                            icon: Icons.copy_rounded,
                            tooltip: 'Copy response',
                            onTap: () => onCopyText?.call(message.text),
                          ),
                        if (onRetrigger != null) ...<Widget>[
                          const SizedBox(width: 4),
                          _ActionButton(
                            icon: Icons.refresh_rounded,
                            tooltip: 'Re-trigger response',
                            onTap: () => onRetrigger?.call(messageIndex),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
        ),
      ),
    );
  }
}
