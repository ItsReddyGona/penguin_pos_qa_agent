import 'package:flutter/material.dart';

/// Centered Welcome Canvas with 64x64 sparkle icon and Bento Quick Action Cards.
class AssistantWelcomeCanvas extends StatelessWidget {
  const AssistantWelcomeCanvas({super.key, required this.onSelectBentoAction});

  final ValueChanged<String> onSelectBentoAction;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Circle Avatar Icon Badge
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFF6F4F0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 32,
                  color: Color(0xFF658A7A),
                ),
              ),
              const SizedBox(height: 20),

              // Headline & Subtitle
              const Text(
                'Good day. What shall we test today?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C302E),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: const Text(
                  "I'm ready to help you craft, review, and execute automated test suites for PenguinPOS. Choose an option below or ask a question.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.5,
                    color: Color(0xFF494C4A),
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // Bento Quick Action Cards
              Row(
                children: <Widget>[
                  Expanded(
                    child: _BentoQuickCard(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'Run Login Suite',
                      description:
                          'Execute configured Login test cases from Settings',
                      onTap: () => onSelectBentoAction('/login'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _BentoQuickCard(
                      icon: Icons.shopping_cart_outlined,
                      title: 'Punch Orders',
                      description:
                          'Execute configured Order & Cash checkout from Settings',
                      onTap: () => onSelectBentoAction('/order'),
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
}

class _BentoQuickCard extends StatelessWidget {
  const _BentoQuickCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFC7C9C4)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x06658A7A),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F4F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: const Color(0xFF658A7A)),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C302E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Color(0xFF787A76),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
