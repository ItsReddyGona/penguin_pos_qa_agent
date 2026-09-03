import 'package:flutter/material.dart';

enum SettingsTab {
  inputsCredentials,
  credentials,
  profiles,
  sshTarget,
  aiModels,
  qaNotices,
  systemPaths,
  support,
}

/// Left navigation sidebar for QaSettingsScreen.
class SettingsSidebar extends StatelessWidget {
  const SettingsSidebar({
    super.key,
    required this.activeTab,
    required this.onSelectTab,
  });

  final SettingsTab activeTab;
  final ValueChanged<SettingsTab> onSelectTab;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: const Color(0xFFF6F4F0),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 16),
          _SidebarItem(
            active: activeTab == SettingsTab.inputsCredentials,
            icon: Icons.fact_check_outlined,
            label: 'Inputs & Credentials',
            onTap: () => onSelectTab(SettingsTab.inputsCredentials),
          ),
          _SidebarItem(
            active: activeTab == SettingsTab.credentials,
            icon: Icons.key_rounded,
            label: 'Credentials & PINs',
            onTap: () => onSelectTab(SettingsTab.credentials),
          ),
          _SidebarItem(
            active: activeTab == SettingsTab.profiles,
            icon: Icons.account_tree_outlined,
            label: 'Profiles & Environments',
            onTap: () => onSelectTab(SettingsTab.profiles),
          ),
          _SidebarItem(
            active: activeTab == SettingsTab.sshTarget,
            icon: Icons.terminal_rounded,
            label: 'SSH Remote Target',
            onTap: () => onSelectTab(SettingsTab.sshTarget),
          ),
          _SidebarItem(
            active: activeTab == SettingsTab.aiModels,
            icon: Icons.auto_awesome_outlined,
            label: 'AI Models & Endpoint',
            onTap: () => onSelectTab(SettingsTab.aiModels),
          ),
          _SidebarItem(
            active: activeTab == SettingsTab.qaNotices,
            icon: Icons.notifications_active_outlined,
            label: 'QA Notices',
            onTap: () => onSelectTab(SettingsTab.qaNotices),
          ),
          _SidebarItem(
            active: activeTab == SettingsTab.systemPaths,
            icon: Icons.folder_open_rounded,
            label: 'System & Engine Paths',
            onTap: () => onSelectTab(SettingsTab.systemPaths),
          ),
          _SidebarItem(
            active: activeTab == SettingsTab.support,
            icon: Icons.info_outline_rounded,
            label: 'Support & System Info',
            onTap: () => onSelectTab(SettingsTab.support),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: active ? const Color(0xFFDCE4DF) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: 18,
                  color: active
                      ? const Color(0xFF182A22)
                      : const Color(0xFF494C4A),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: active
                          ? const Color(0xFF182A22)
                          : const Color(0xFF2C302E),
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
}
