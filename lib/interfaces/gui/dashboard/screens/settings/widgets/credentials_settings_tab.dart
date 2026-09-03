import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/settings_form_card.dart';

/// Tab view for managing target environment profile, login ID, password, and terminal unlock PIN.
class CredentialsSettingsTab extends StatelessWidget {
  const CredentialsSettingsTab({
    super.key,
    required this.profiles,
    required this.selectedProfile,
    required this.loginIdController,
    required this.passwordController,
    required this.unlockPinController,
    required this.savingCredentials,
    required this.onProfileChanged,
    required this.onSaveCredentials,
  });

  final List<QaProfile> profiles;
  final QaProfile selectedProfile;
  final TextEditingController loginIdController;
  final TextEditingController passwordController;
  final TextEditingController unlockPinController;
  final bool savingCredentials;
  final ValueChanged<QaProfile> onProfileChanged;
  final VoidCallback onSaveCredentials;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Target Environment & Credentials',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C302E),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Configure test credentials and PIN unlock codes for your target PenguinPOS instance.',
          style: TextStyle(fontSize: 13.5, color: Color(0xFF787A76)),
        ),
        const SizedBox(height: 24),

        SettingsFormCard(
          children: <Widget>[
            const Text(
              'Target Profile / Environment',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<QaProfile>(
              initialValue: selectedProfile,
              isDense: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: profiles
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                  .toList(),
              onChanged: (val) {
                if (val != null) onProfileChanged(val);
              },
            ),
            const SizedBox(height: 18),

            const Text(
              'Test Login ID (10-digits)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: loginIdController,
              decoration: InputDecoration(
                hintText: 'e.g. 8888888888',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 18),

            const Text(
              'Test Password',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Enter password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 18),

            const Text(
              'Terminal Unlock PIN',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: unlockPinController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'e.g. 1234 or 1359',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 24),

            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF658A7A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: savingCredentials ? null : onSaveCredentials,
                icon: savingCredentials
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save Credentials'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
