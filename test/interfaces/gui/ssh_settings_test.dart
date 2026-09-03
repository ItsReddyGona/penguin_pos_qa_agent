import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/repository/qa_target_preferences_repository.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/ssh_settings_tab.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('SSH target defaults are empty and disabled', () async {
    final repository = QaTargetPreferencesRepository();

    final target = await repository.loadSshTarget();

    expect(target.enabled, isFalse);
    expect(target.host, isEmpty);
    expect(target.username, isEmpty);
    expect(target.port, isEmpty);
    expect(target.identityFile, isEmpty);
    expect(target.appRoot, isEmpty);
    expect(target.flutterPath, isEmpty);
    expect(await repository.loadSshPassword(), isEmpty);
  });

  test(
    'persists SSH target fields and password through the vault boundary',
    () async {
      final repository = QaTargetPreferencesRepository();
      const target = QaSshTarget(
        enabled: true,
        host: 'test-host',
        username: 'test-user',
        port: '2222',
        identityFile: '/tmp/test-key',
        appRoot: '/srv/penguin_pos',
        flutterPath: '/opt/flutter/bin/flutter',
      );

      await repository.saveSshTarget(target);
      await repository.saveSshPassword('test-password');

      expect(await repository.loadSshTarget(), isA<QaSshTarget>());
      final loaded = await repository.loadSshTarget();
      expect(loaded.enabled, isTrue);
      expect(loaded.host, target.host);
      expect(loaded.username, target.username);
      expect(loaded.port, target.port);
      expect(loaded.identityFile, target.identityFile);
      expect(loaded.appRoot, target.appRoot);
      expect(loaded.flutterPath, target.flutterPath);
      expect(await repository.loadSshPassword(), 'test-password');
    },
  );

  test('keeps SSH targets and passwords isolated by QA profile', () async {
    final repository = QaTargetPreferencesRepository();
    const target = QaSshTarget(
      enabled: true,
      host: '10.0.0.10',
      username: 'qa-user',
      port: '22',
      appRoot: '/opt/penguin_pos',
    );

    await repository.saveSshTarget(target, profileId: 'kpn-dev');
    await repository.saveSshPassword('profile-password', profileId: 'kpn-dev');

    final loaded = await repository.loadSshTarget(profileId: 'kpn-dev');
    expect(loaded.host, '10.0.0.10');
    expect(loaded.enabled, isTrue);
    expect(
      await repository.loadSshPassword(profileId: 'kpn-dev'),
      'profile-password',
    );
    expect(
      (await repository.loadSshTarget(profileId: 'ibo-dev')).host,
      isEmpty,
    );
  });

  testWidgets('SSH settings obscures password and exposes save/test actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controllers = <TextEditingController>[
      TextEditingController(),
      TextEditingController(),
      TextEditingController(text: 'secret'),
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
    ];
    addTearDown(() {
      for (final controller in controllers) {
        controller.dispose();
      }
    });

    var enabled = false;
    var tested = false;
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SshSettingsTab(
              profiles: QaProfile.values,
              selectedProfile: QaProfile.values.first,
              enabled: enabled,
              hostController: controllers[0],
              usernameController: controllers[1],
              passwordController: controllers[2],
              portController: controllers[3],
              identityFileController: controllers[4],
              appRootController: controllers[5],
              flutterPathController: controllers[6],
              testingConnection: false,
              connectionStatus: null,
              onEnabledChanged: (value) => enabled = value,
              onProfileChanged: (_) {},
              onTestConnection: () => tested = true,
              onSave: () => saved = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final passwordField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('ssh-password')),
    );
    expect(passwordField.obscureText, isTrue);

    await tester.tap(find.byKey(const ValueKey<String>('ssh-enabled-toggle')));
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('test-ssh-connection')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('test-ssh-connection')));
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('save-ssh-settings')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('save-ssh-settings')));

    expect(enabled, isTrue);
    expect(tested, isTrue);
    expect(saved, isTrue);
  });

  test('canonical target mode includes local and ssh', () {
    expect(
      QaTargetMode.values,
      containsAll(<QaTargetMode>[QaTargetMode.local, QaTargetMode.ssh]),
    );
  });
}
