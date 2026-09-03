import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/system_paths_settings_tab.dart';

void main() {
  testWidgets('saves both edited system paths together', (tester) async {
    String? savedFlutterPath;
    String? savedAppRoot;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SystemPathsSettingsTab(
              flutterPath: 'flutter',
              appRoot: '/old/app/root',
              onSave: (flutterPath, appRoot) async {
                savedFlutterPath = flutterPath;
                savedAppRoot = appRoot;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '/opt/flutter/bin/flutter');
    await tester.enterText(fields.at(1), '/srv/penguin_pos');
    await tester.tap(find.byKey(const ValueKey<String>('save-system-paths')));
    await tester.pumpAndSettle();

    expect(savedFlutterPath, '/opt/flutter/bin/flutter');
    expect(savedAppRoot, '/srv/penguin_pos');
  });
}
