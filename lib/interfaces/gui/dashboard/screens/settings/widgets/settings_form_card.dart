import 'package:flutter/material.dart';

/// Reusable styled card container for settings forms.
class SettingsFormCard extends StatelessWidget {
  const SettingsFormCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
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
        children: children,
      ),
    );
  }
}
