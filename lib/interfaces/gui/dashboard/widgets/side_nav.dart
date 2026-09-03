import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/test_suite_model.dart';

/// Side Navigation Bar matching the reference design layout & material design tokens.
class SideNav extends StatelessWidget {
  const SideNav({
    super.key,
    required this.suites,
    required this.selectedSuiteId,
    required this.onSelectSuite,
    required this.onNewSuite,
    required this.onOpenSettings,
    required this.onOpenSupport,
    required this.activeProfileLabel,
    required this.targetMode,
  });

  final List<TestSuiteItem> suites;
  final String selectedSuiteId;
  final ValueChanged<String> onSelectSuite;
  final VoidCallback onNewSuite;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenSupport;
  final String activeProfileLabel;
  final QaTargetMode targetMode;

  @override
  Widget build(BuildContext context) => Container(
    width: 250,
    decoration: const BoxDecoration(
      color: Color(0xFFF6F4F0),
      border: Border(right: BorderSide(color: Color(0xFFC7C9C4), width: 1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // App Branding & Profile Badge
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFBCEBE5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF182A22),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'QA Agent',
                      style: TextStyle(
                        color: Color(0xFF2C302E),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      '$activeProfileLabel • ${targetMode == QaTargetMode.local ? "Local" : "SSH"}',
                      style: const TextStyle(
                        color: Color(0xFF494C4A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Primary Action: + New Suite Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF658A7A),
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(double.infinity, 42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: onNewSuite,
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'New Suite',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ),

        const SizedBox(height: 8),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Divider(color: Color(0xFFC7C9C4), height: 1),
        ),

        // Section Header
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Text(
            'TEST SUITES',
            style: TextStyle(
              color: Color(0xFF787A76),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),

        // Suites List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: suites.length,
            itemBuilder: (context, index) {
              final suite = suites[index];
              final isSelected = suite.id == selectedSuiteId;
              return _SideNavItem(
                icon: suite.icon,
                label: suite.title,
                active: isSelected,
                onTap: () => onSelectSuite(suite.id),
              );
            },
          ),
        ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Divider(color: Color(0xFFC7C9C4), height: 1),
        ),

        // Footer Action Items
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            children: <Widget>[
              _QuickLinkItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: onOpenSettings,
              ),
              _QuickLinkItem(
                icon: Icons.contact_support_outlined,
                label: 'Support',
                onTap: onOpenSupport,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _QuickLinkItem extends StatelessWidget {
  const _QuickLinkItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: const Color(0xFF494C4A)),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF2C302E),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideNavItem extends StatelessWidget {
  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Material(
      color: active ? const Color(0xFFDCE4DF) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                size: 18,
                color: active
                    ? const Color(0xFF182A22)
                    : const Color(0xFF494C4A),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active
                        ? const Color(0xFF182A22)
                        : const Color(0xFF2C302E),
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
