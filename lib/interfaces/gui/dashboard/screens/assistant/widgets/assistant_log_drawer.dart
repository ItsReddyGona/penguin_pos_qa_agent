import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/automation/core/telemetry/api_trace_event.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';

/// DevTools-inspired terminal drawer for execution logs and captured requests.
class AssistantLogDrawer extends StatefulWidget {
  const AssistantLogDrawer({
    super.key,
    required this.activityMessages,
    required this.apiTraces,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final List<QaActivityMessage> activityMessages;
  final List<ApiTraceEvent> apiTraces;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  State<AssistantLogDrawer> createState() => _AssistantLogDrawerState();
}

class _AssistantLogDrawerState extends State<AssistantLogDrawer> {
  @override
  Widget build(BuildContext context) {
    final lastMessage = widget.activityMessages.isEmpty
        ? null
        : widget.activityMessages.last;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Divider(height: 1, thickness: 1, color: Color(0xFFD7DAD6)),
        InkWell(
          onTap: widget.onToggleExpanded,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            color: const Color(0xFFF5F4F1),
            child: Row(
              children: <Widget>[
                const Icon(Icons.terminal_rounded, size: 17),
                const SizedBox(width: 9),
                const Text(
                  'Terminal',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 10),
                _CountBadge(label: '${widget.activityMessages.length} logs'),
                const SizedBox(width: 14),
                if (!widget.expanded && lastMessage != null)
                  Expanded(
                    child: Text(
                      '${lastMessage.title} — ${lastMessage.body}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B706D),
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                Icon(
                  widget.expanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                ),
              ],
            ),
          ),
        ),
        if (widget.expanded) _buildTerminal(),
      ],
    );
  }

  Widget _buildTerminal() => Container(
    height: 330,
    color: const Color(0xFF151A18),
    child: Column(
      children: <Widget>[
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF303936))),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.subject_rounded,
                size: 16,
                color: Color(0xFF9EAAA4),
              ),
              const SizedBox(width: 7),
              const Text(
                'Logs',
                style: TextStyle(color: Color(0xFFD6DED9), fontSize: 12),
              ),
              const Spacer(),
              Text(
                '${widget.activityMessages.length} entries',
                style: const TextStyle(color: Color(0xFF9EAAA4), fontSize: 11),
              ),
            ],
          ),
        ),
        Expanded(child: _buildLogs()),
      ],
    ),
  );

  Widget _buildLogs() {
    if (widget.activityMessages.isEmpty) {
      return const Center(
        child: Text('No terminal output yet.', style: _terminalMuted),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.activityMessages.length,
      itemBuilder: (context, index) {
        final entry = widget.activityMessages[index];
        final color = switch (entry.kind) {
          QaActivityKind.success => const Color(0xFF70D18C),
          QaActivityKind.error => const Color(0xFFFF9188),
          QaActivityKind.info => const Color(0xFF7CB7FF),
        };
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                color: Color(0xFFD6DED9),
              ),
              children: <InlineSpan>[
                TextSpan(
                  text: '● ',
                  style: TextStyle(color: color),
                ),
                TextSpan(
                  text: '${entry.title}: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: entry.body),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFFE3EBE5),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: Color(0xFF355342),
      ),
    ),
  );
}

const _terminalMuted = TextStyle(
  fontFamily: 'monospace',
  fontSize: 12,
  color: Color(0xFF9EAAA4),
);
