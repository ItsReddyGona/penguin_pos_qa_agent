import 'package:flutter/material.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/inputs_credentials_settings_tab.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/order_inputs_settings_tab.dart';

class InputsCredentialsWorkspace extends StatefulWidget {
  const InputsCredentialsWorkspace({
    super.key,
    required this.profiles,
    required this.selectedProfile,
    required this.loadLoginCases,
    required this.saveLoginCases,
    required this.loadOrderItems,
    required this.saveOrderItems,
    required this.loadOrderCases,
    required this.saveOrderCases,
    required this.onProfileChanged,
  });

  final List<QaProfile> profiles;
  final QaProfile selectedProfile;
  final LoginCasesLoader loadLoginCases;
  final LoginCasesSaver saveLoginCases;
  final OrderInputsLoader loadOrderItems;
  final OrderInputsSaver saveOrderItems;
  final OrderCasesLoader loadOrderCases;
  final OrderCasesSaver saveOrderCases;
  final ValueChanged<QaProfile> onProfileChanged;

  @override
  State<InputsCredentialsWorkspace> createState() =>
      _InputsCredentialsWorkspaceState();
}

class _InputsCredentialsWorkspaceState extends State<InputsCredentialsWorkspace>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Inputs & Credentials',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C302E),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Configure reusable manual inputs for Login and Order test suites.',
                  style: TextStyle(fontSize: 13.5, color: Color(0xFF787A76)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<QaProfile>(
              key: ValueKey<String>(widget.selectedProfile.id),
              initialValue: widget.selectedProfile,
              isDense: true,
              decoration: InputDecoration(
                labelText: 'Target Profile / Environment',
                labelStyle: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF555953),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
              ),
              items: widget.profiles
                  .map(
                    (profile) => DropdownMenuItem<QaProfile>(
                      value: profile,
                      child: Text(
                        profile.label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (profile) {
                if (profile != null) widget.onProfileChanged(profile);
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Container(
        key: const ValueKey<String>('inputs-credentials-segmented-tabs'),
        height: 42,
        width: 340,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFE9E9EE),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabs,
          labelColor: const Color(0xFF202124),
          unselectedLabelColor: const Color(0xFF7A7D85),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          tabs: const <Widget>[
            Tab(text: 'Login'),
            Tab(text: 'Order Inputs'),
          ],
        ),
      ),
      const SizedBox(height: 18),
      AnimatedBuilder(
        animation: _tabs,
        builder: (context, _) => IndexedStack(
          index: _tabs.index,
          children: <Widget>[
            InputsCredentialsSettingsTab(
              profiles: widget.profiles,
              selectedProfile: widget.selectedProfile,
              loadCases: widget.loadLoginCases,
              saveCases: widget.saveLoginCases,
              onProfileChanged: widget.onProfileChanged,
              showProfileSelector: false,
            ),
            OrderInputsSettingsTab(
              profiles: widget.profiles,
              selectedProfile: widget.selectedProfile,
              loadItems: widget.loadOrderItems,
              saveItems: widget.saveOrderItems,
              loadCases: widget.loadOrderCases,
              saveCases: widget.saveOrderCases,
              onProfileChanged: widget.onProfileChanged,
            ),
          ],
        ),
      ),
    ],
  );
}
