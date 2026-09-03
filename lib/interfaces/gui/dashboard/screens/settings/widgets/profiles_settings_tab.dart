import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/settings_form_card.dart';

/// Tab view for adding, listing, and deleting entity/environment profiles.
class ProfilesSettingsTab extends StatelessWidget {
  const ProfilesSettingsTab({
    super.key,
    required this.profiles,
    required this.activeProfile,
    required this.newLabelController,
    required this.newEntityController,
    required this.newEnvController,
    required this.newAliasesController,
    required this.onAddProfile,
    required this.onDeleteProfile,
  });

  final List<QaProfile> profiles;
  final QaProfile activeProfile;
  final TextEditingController newLabelController;
  final TextEditingController newEntityController;
  final TextEditingController newEnvController;
  final TextEditingController newAliasesController;
  final VoidCallback onAddProfile;
  final ValueChanged<QaProfile> onDeleteProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Profiles & Environments',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C302E),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Create and manage reusable entity/environment profiles for test routing.',
          style: TextStyle(fontSize: 13.5, color: Color(0xFF787A76)),
        ),
        const SizedBox(height: 24),

        SettingsFormCard(
          children: <Widget>[
            const Text(
              'Add New Profile',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newLabelController,
              decoration: const InputDecoration(
                labelText: 'Label (e.g. KPN DEV)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newEntityController,
              decoration: const InputDecoration(
                labelText: 'PenguinPOS entity (e.g. kpn)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newEnvController,
              decoration: const InputDecoration(
                labelText: 'Environment (e.g. dev)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newAliasesController,
              decoration: const InputDecoration(
                labelText: 'Slash command aliases (comma-separated)',
                hintText: 'kpn-dev, kpn dev',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF658A7A),
                  foregroundColor: Colors.white,
                ),
                onPressed: onAddProfile,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Profile'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        const Text(
          'Active Profiles',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...profiles.map(
          (profile) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFC7C9C4)),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.dns_rounded,
                  size: 20,
                  color: activeProfile.id == profile.id
                      ? const Color(0xFF658A7A)
                      : const Color(0xFF787A76),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        profile.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'ID: ${profile.id} · Entity: ${profile.entity} · Env: ${profile.environment}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF787A76),
                        ),
                      ),
                    ],
                  ),
                ),
                if (profiles.length > 1)
                  IconButton(
                    tooltip: 'Delete Profile',
                    onPressed: () => onDeleteProfile(profile),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
