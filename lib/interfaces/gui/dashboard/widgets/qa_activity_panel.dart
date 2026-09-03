import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/widgets/qa_panel.dart';

/// Professional Vertical Stepper Timeline matching the design mockup.
class QaActivityPanel extends StatelessWidget {
  const QaActivityPanel({super.key, required this.messages});
  final List<QaActivityMessage> messages;

  @override
  Widget build(BuildContext context) {
    return QaPanel(
      title: 'Activity Log',
      subtitle: 'Real-time execution events and logs.',
      child: messages.isEmpty
          ? const Center(child: Text('No activity events logged.'))
          : ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[messages.length - 1 - index];
                final isLast = index == messages.length - 1;

                final (color, iconData, nodeBg) = switch (message.kind) {
                  QaActivityKind.success => (
                    const Color(0xFF16A34A),
                    Icons.check_circle_outline_rounded,
                    const Color(0xFFF0FDF4),
                  ),
                  QaActivityKind.error => (
                    const Color(0xFFDC2626),
                    Icons.cancel_outlined,
                    const Color(0xFFFEF2F2),
                  ),
                  QaActivityKind.info => (
                    message.title.toLowerCase().contains('processing')
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF2563EB),
                    message.title.toLowerCase().contains('processing')
                        ? Icons.sync_rounded
                        : Icons.outlined_flag_rounded,
                    const Color(0xFFEFF6FF),
                  ),
                };

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Stepper Node & Vertical Line
                      SizedBox(
                        width: 32,
                        child: Column(
                          children: <Widget>[
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: nodeBg,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: color.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(iconData, color: color, size: 16),
                            ),
                            if (!isLast)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Content Body
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                message.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                message.body,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF475569),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
