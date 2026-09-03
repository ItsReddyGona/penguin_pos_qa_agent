import 'package:flutter/material.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';

/// Step 1 Widget: Target Machine Mode & Paths Auto-Detection Configuration.
class TargetEnvironmentStep extends StatelessWidget {
  const TargetEnvironmentStep({
    super.key,
    required this.targetMode,
    required this.flutterPathController,
    required this.appRootController,
    required this.sshUserController,
    required this.sshHostController,
    required this.detectingPaths,
    required this.flutterPathValid,
    required this.appRootValid,
    required this.onTargetModeChanged,
    required this.onAutoDetectPaths,
  });

  final QaTargetMode targetMode;
  final TextEditingController flutterPathController;
  final TextEditingController appRootController;
  final TextEditingController sshUserController;
  final TextEditingController sshHostController;
  final bool detectingPaths;
  final bool flutterPathValid;
  final bool appRootValid;
  final ValueChanged<QaTargetMode> onTargetModeChanged;
  final VoidCallback onAutoDetectPaths;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Select Execution Target',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose where PenguinPOS will be launched and executed for automated testing.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),

          // Target Machine Mode Cards
          Row(
            children: <Widget>[
              Expanded(
                child: _buildModeCard(
                  mode: QaTargetMode.local,
                  title: 'Local Machine',
                  subtitle: 'Launch PenguinPOS directly on this macOS desktop',
                  icon: Icons.desktop_mac_rounded,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildModeCard(
                  mode: QaTargetMode.ssh,
                  title: 'SSH Remote Target',
                  subtitle: 'Connect and control POS over SSH / Remote Device',
                  icon: Icons.terminal_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Path Auto-Detection Box for Local Mode
          if (targetMode == QaTargetMode.local) ...<Widget>[
            Row(
              children: <Widget>[
                const Text(
                  'Environment Paths',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: detectingPaths ? null : onAutoDetectPaths,
                  icon: detectingPaths
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.autorenew_rounded, size: 16),
                  label: const Text('Auto-Detect Paths'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Flutter Executable Path Field
            TextField(
              controller: flutterPathController,
              decoration: InputDecoration(
                labelText: 'Flutter SDK Executable Path',
                hintText: '/Users/.../flutter/bin/flutter',
                border: const OutlineInputBorder(),
                suffixIcon: Icon(
                  flutterPathValid
                      ? Icons.check_circle_rounded
                      : Icons.warning_amber_rounded,
                  color: flutterPathValid
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFD97706),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // PenguinPOS App Root Directory Field
            TextField(
              controller: appRootController,
              decoration: InputDecoration(
                labelText: 'PenguinPOS Application Root Directory',
                hintText: '/Users/.../PenguinPOS/penguin_pos',
                border: const OutlineInputBorder(),
                suffixIcon: Icon(
                  appRootValid
                      ? Icons.check_circle_rounded
                      : Icons.warning_amber_rounded,
                  color: appRootValid
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFD97706),
                ),
              ),
            ),
          ] else ...<Widget>[
            // SSH Host Inputs
            const Text(
              'SSH Remote Connection Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: sshUserController,
              decoration: const InputDecoration(
                labelText: 'SSH Username',
                hintText: 'e.g. posuser',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: sshHostController,
              decoration: const InputDecoration(
                labelText: 'SSH Host / IP Address',
                hintText: 'e.g. 192.168.1.100',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required QaTargetMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = targetMode == mode;

    return InkWell(
      onTap: () => onTargetModeChanged(mode),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              icon,
              size: 28,
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isSelected
                    ? const Color(0xFF1E40AF)
                    : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}
