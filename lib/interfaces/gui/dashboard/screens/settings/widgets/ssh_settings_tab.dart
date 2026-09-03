import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/settings_form_card.dart';

/// Settings view for the optional remote PenguinPOS SSH target.
class SshSettingsTab extends StatelessWidget {
  const SshSettingsTab({
    super.key,
    required this.profiles,
    required this.selectedProfile,
    required this.enabled,
    required this.hostController,
    required this.usernameController,
    required this.passwordController,
    required this.portController,
    required this.identityFileController,
    required this.appRootController,
    required this.flutterPathController,
    required this.testingConnection,
    required this.connectionStatus,
    required this.onEnabledChanged,
    required this.onTestConnection,
    required this.onSave,
    required this.onProfileChanged,
  });

  final List<QaProfile> profiles;
  final QaProfile selectedProfile;
  final bool enabled;
  final TextEditingController hostController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final TextEditingController portController;
  final TextEditingController identityFileController;
  final TextEditingController appRootController;
  final TextEditingController flutterPathController;
  final bool testingConnection;
  final String? connectionStatus;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onTestConnection;
  final VoidCallback onSave;
  final ValueChanged<QaProfile> onProfileChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'SSH Remote Target',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C302E),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Configure the Linux machine where PenguinPOS will be launched for remote QA execution.',
          style: TextStyle(fontSize: 13.5, color: Color(0xFF787A76)),
        ),
        const SizedBox(height: 24),
        SettingsFormCard(
          children: <Widget>[
            DropdownButtonFormField<QaProfile>(
              key: const ValueKey<String>('ssh-profile'),
              initialValue: selectedProfile,
              decoration: const InputDecoration(
                labelText: 'QA profile',
                border: OutlineInputBorder(),
              ),
              items: profiles
                  .map(
                    (profile) => DropdownMenuItem<QaProfile>(
                      value: profile,
                      child: Text(profile.label),
                    ),
                  )
                  .toList(),
              onChanged: (profile) {
                if (profile != null) onProfileChanged(profile);
              },
            ),
            const SizedBox(height: 14),
            Material(
              color: Colors.transparent,
              child: SwitchListTile.adaptive(
                key: const ValueKey<String>('ssh-enabled-toggle'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Use SSH remote target'),
                subtitle: const Text(
                  'When enabled, the execution coordinator can select a Linux target over SSH.',
                ),
                value: enabled,
                onChanged: onEnabledChanged,
              ),
            ),
            const SizedBox(height: 12),
            _textField(
              controller: hostController,
              label: 'Host or IP address',
              key: const ValueKey<String>('ssh-host'),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: _textField(
                    controller: usernameController,
                    label: 'Username',
                    key: const ValueKey<String>('ssh-username'),
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 150,
                  child: _textField(
                    controller: portController,
                    label: 'Port',
                    key: const ValueKey<String>('ssh-port'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _textField(
              controller: passwordController,
              label: 'Password',
              key: const ValueKey<String>('ssh-password'),
              obscureText: true,
            ),
            const SizedBox(height: 14),
            _textField(
              controller: identityFileController,
              label: 'Identity file (optional)',
              key: const ValueKey<String>('ssh-identity-file'),
            ),
            const SizedBox(height: 14),
            _textField(
              controller: appRootController,
              label: 'Remote PenguinPOS app root',
              key: const ValueKey<String>('ssh-app-root'),
            ),
            const SizedBox(height: 14),
            _textField(
              controller: flutterPathController,
              label: 'Remote Flutter executable path',
              key: const ValueKey<String>('ssh-flutter-path'),
            ),
            if (connectionStatus != null) ...<Widget>[
              const SizedBox(height: 16),
              Container(
                key: const ValueKey<String>('ssh-connection-status'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F4F0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFC7C9C4)),
                ),
                child: Text(
                  connectionStatus!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF2C302E),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                OutlinedButton.icon(
                  key: const ValueKey<String>('test-ssh-connection'),
                  onPressed: testingConnection ? null : onTestConnection,
                  icon: testingConnection
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check_rounded, size: 18),
                  label: Text(
                    testingConnection ? 'Testing…' : 'Test SSH Connection',
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  key: const ValueKey<String>('save-ssh-settings'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF658A7A),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onSave,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save SSH Settings'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required Key key,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      key: key,
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
