import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/login_test_case.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/inputs_credentials_settings_tab.dart';

void main() {
  testWidgets('adds and saves a profile-scoped login test case', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? savedProfileId;
    List<LoginTestCaseDefinition>? savedCases;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: InputsCredentialsSettingsTab(
              profiles: QaProfile.values,
              selectedProfile: QaProfile.values.first,
              loadCases: (_) async => const <LoginTestCaseDefinition>[],
              saveCases: (profileId, cases) async {
                savedProfileId = profileId;
                savedCases = cases;
              },
              onProfileChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No Login test cases configured.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('add-login-test-case')));
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const ValueKey('save-login-test-cases')),
    );
    await tester.tap(find.byKey(const ValueKey('save-login-test-cases')));
    await tester.pumpAndSettle();

    expect(savedProfileId, QaProfile.values.first.id);
    expect(savedCases, hasLength(1));
    expect(savedCases!.single.username, isEmpty);
    expect(savedCases!.single.password, isEmpty);
    expect(
      savedCases!.single.expectedResult,
      LoginExpectedResult.requiredFieldValidation,
    );
    expect(find.textContaining('Saved 1 login test case'), findsOneWidget);
  });

  testWidgets('rejects an empty authentication-rejection case', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var saveCount = 0;
    const configured = LoginTestCaseDefinition(
      id: 'authentication-rejection',
      name: 'Authentication rejection',
      expectedResult: LoginExpectedResult.authenticationRejected,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: InputsCredentialsSettingsTab(
              profiles: QaProfile.values,
              selectedProfile: QaProfile.values.first,
              loadCases: (_) async => const <LoginTestCaseDefinition>[
                configured,
              ],
              saveCases: (_, _) async => saveCount++,
              onProfileChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('save-login-test-cases')),
    );
    await tester.tap(find.byKey(const ValueKey('save-login-test-cases')));
    await tester.pump();

    expect(saveCount, 0);
    expect(
      find.text(
        'Authentication rejection requires both username and password.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('offers only the three executable login outcomes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const configured = LoginTestCaseDefinition(
      id: 'successful-login',
      name: 'Successful login',
      username: 'configured-user',
      password: 'configured-password',
      expectedResult: LoginExpectedResult.successfulLogin,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: InputsCredentialsSettingsTab(
              profiles: QaProfile.values,
              selectedProfile: QaProfile.values.first,
              loadCases: (_) async => const <LoginTestCaseDefinition>[
                configured,
              ],
              saveCases: (_, _) async {},
              onProfileChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('expected-successful-login')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Successful login'), findsWidgets);
    expect(find.text('Invalid credentials'), findsOneWidget);
    expect(find.text('Validation error'), findsOneWidget);
    expect(find.text('Terminal selection shown'), findsNothing);
    expect(find.text('Home screen reached'), findsNothing);
    expect(find.text('Idle PIN rejected'), findsNothing);
  });

  testWidgets('keeps a stored idle PIN outcome parseable but hidden', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: InputsCredentialsSettingsTab(
              profiles: QaProfile.values,
              selectedProfile: QaProfile.values.first,
              loadCases: (_) async => const <LoginTestCaseDefinition>[
                LoginTestCaseDefinition(
                  id: 'idle-pin',
                  name: 'Stored idle PIN case',
                  expectedResult: LoginExpectedResult.idlePinRejected,
                ),
              ],
              saveCases: (_, _) async {},
              onProfileChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stored idle PIN case'), findsOneWidget);
    expect(find.text('Idle PIN rejected'), findsNothing);
    expect(find.text('Idle PIN outcomes are not supported yet.'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('save-login-test-cases')),
    );
    await tester.tap(find.byKey(const ValueKey('save-login-test-cases')));
    await tester.pump();

    expect(
      find.text('Idle PIN outcomes are not supported yet.'),
      findsOneWidget,
    );
  });
}
