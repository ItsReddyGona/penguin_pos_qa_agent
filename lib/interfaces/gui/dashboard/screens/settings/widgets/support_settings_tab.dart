import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/settings_form_card.dart';

/// Tab view displaying version information, supported suites, and system details.
class SupportSettingsTab extends StatelessWidget {
  const SupportSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Support & System Information',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C302E),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Information about PenguinPOS QA Agent runtime and testing capabilities.',
          style: TextStyle(fontSize: 13.5, color: Color(0xFF787A76)),
        ),
        const SizedBox(height: 24),

        const SettingsFormCard(
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.verified_rounded, color: Color(0xFF658A7A)),
                SizedBox(width: 10),
                Text(
                  'PenguinPOS QA Agent v0.1.0',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'Automated execution driver and desktop GUI workspace for PenguinPOS testing.',
              style: TextStyle(fontSize: 13, color: Color(0xFF494C4A)),
            ),
            Divider(height: 28),
            Text(
              'Supported Test Suites:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text('• Login & Terminal Unlock Full Sequence'),
            Text('• Order & Cash Payment Checkout Sequence'),
            Text('• Multi-iteration batch order puncher'),
          ],
        ),
      ],
    );
  }
}
