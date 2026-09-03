import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/settings_form_card.dart';

class QaNoticesSettingsTab extends StatelessWidget {
  const QaNoticesSettingsTab({
    super.key,
    required this.displayMode,
    required this.onChanged,
  });

  final QaTestNoticeDisplayMode displayMode;
  final ValueChanged<QaTestNoticeDisplayMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'QA Notices',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C302E),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Control which progress messages appear on the PenguinPOS target during automation.',
          style: TextStyle(fontSize: 13.5, color: Color(0xFF787A76)),
        ),
        const SizedBox(height: 24),
        SettingsFormCard(
          children: <Widget>[
            DropdownButtonFormField<QaTestNoticeDisplayMode>(
              key: const ValueKey<String>('qa_notice_display_mode'),
              initialValue: displayMode,
              decoration: const InputDecoration(
                labelText: 'Notice display mode',
                border: OutlineInputBorder(),
              ),
              items: QaTestNoticeDisplayMode.values
                  .map(
                    (mode) => DropdownMenuItem<QaTestNoticeDisplayMode>(
                      value: mode,
                      child: Text(mode.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
            const SizedBox(height: 14),
            Text(
              _description(displayMode),
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF4B504C)),
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'Available modes',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final mode in QaTestNoticeDisplayMode.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• ${mode.label}: ${_description(mode)}'),
              ),
          ],
        ),
      ],
    );
  }

  String _description(QaTestNoticeDisplayMode mode) => switch (mode) {
    QaTestNoticeDisplayMode.all =>
      'Show every step notice, warning, error, and milestone.',
    QaTestNoticeDisplayMode.milestonesAndErrors =>
      'Show important milestones, warnings, and errors.',
    QaTestNoticeDisplayMode.warningsAndErrors =>
      'Show warnings and errors only. Recommended for normal runs.',
    QaTestNoticeDisplayMode.errorsOnly => 'Show errors only.',
    QaTestNoticeDisplayMode.never =>
      'Keep the target screen free of QA notices.',
  };
}
