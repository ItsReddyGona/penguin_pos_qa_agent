import 'package:flutter/material.dart';

/// Thin 58px top bar for the AI Assistant Workspace matching the design mockup.
class AssistantTopBar extends StatelessWidget {
  const AssistantTopBar({
    super.key,
    required this.modelConfigured,
    this.sshTargetEnabled,
    this.onSshTargetChanged,
    required this.onOpenSettings,
    required this.onExitAiMode,
  });

  final bool modelConfigured;
  final bool? sshTargetEnabled;
  final ValueChanged<bool>? onSshTargetChanged;
  final VoidCallback onOpenSettings;
  final VoidCallback onExitAiMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFFFDFBF7),
        border: Border(bottom: BorderSide(color: Color(0xFFC7C9C4), width: 1)),
      ),
      child: Row(
        children: <Widget>[
          // Sparkle Logo Icon
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFFF3E8FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: Color(0xFF7C3AED),
            ),
          ),
          const SizedBox(width: 12),

          // Workspace Header Title & Status Dot
          const Text(
            'QA Assistant',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C302E),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 12),

          // A saved endpoint alone is not enough: only a successful model
          // connection earns the green state. Local commands remain available.
          if (modelConfigured)
            _ModelStatusTag()
          else
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB42318),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: onOpenSettings,
              icon: const Icon(Icons.error_outline_rounded, size: 15),
              label: const Text(
                'No model connected',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ),

          const Spacer(),

          if (sshTargetEnabled != null && onSshTargetChanged != null) ...[
            _TargetModeToggle(
              sshEnabled: sshTargetEnabled!,
              onChanged: onSshTargetChanged!,
            ),
            const SizedBox(width: 12),
          ],

          // Settings Text Button
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF494C4A),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined, size: 16),
            label: const Text(
              'Settings',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),

          const SizedBox(width: 8),

          // Manual Mode Toggle Switch Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2C302E),
              side: const BorderSide(color: Color(0xFFC7C9C4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: onExitAiMode,
            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
            label: const Text(
              'Manual mode',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetModeToggle extends StatelessWidget {
  const _TargetModeToggle({required this.sshEnabled, required this.onChanged});

  final bool sshEnabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(
        sshEnabled ? 'SSH' : 'Local',
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF475569),
        ),
      ),
      const SizedBox(width: 4),
      Switch.adaptive(value: sshEnabled, onChanged: onChanged),
    ],
  );
}

class _ModelStatusTag extends StatelessWidget {
  const _ModelStatusTag();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF6F4F0),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFC7C9C4)),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFF16A34A),
            shape: BoxShape.circle,
          ),
          child: SizedBox(width: 7, height: 7),
        ),
        SizedBox(width: 6),
        Text(
          'Ollama / OpenAI connected',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF494C4A),
          ),
        ),
      ],
    ),
  );
}
