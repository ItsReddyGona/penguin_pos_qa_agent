import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_register_input_repository.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/close_register_inputs_settings_tab.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/inputs_credentials_workspace.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/register_inputs_settings_tab.dart';

void main() {
  testWidgets(
    'InputsCredentialsWorkspace displays Register tab and navigates to it',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: InputsCredentialsWorkspace(
                profiles: QaProfile.values,
                selectedProfile: QaProfile.values.first,
                loadLoginCases: (_) async => const [],
                saveLoginCases: (_, _) async {},
                loadOrderItems: (_) async => const [],
                saveOrderItems: (_, _) async {},
                loadOrderCases: (_) async => const [],
                saveOrderCases: (_, _) async {},
                loadRegisterInput: (_) async => const QaRegisterInput(
                  openingFloatAmount: 1000.0,
                  notes: 'Default drawer',
                ),
                saveRegisterInput: (_, _) async {},
                onProfileChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check all 4 tabs are rendered
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Order Inputs'), findsOneWidget);
      expect(find.text('Open Register'), findsOneWidget);
      expect(find.text('Close Register'), findsOneWidget);

      // Tap Open Register tab
      await tester.tap(find.text('Open Register'));
      await tester.pumpAndSettle();

      // Open Register tab content should be visible
      expect(
        find.byKey(const ValueKey('register-opening-float-amount')),
        findsOneWidget,
      );
      expect(find.text('1000'), findsOneWidget);

      // Tap Close Register tab
      await tester.tap(find.text('Close Register'));
      await tester.pumpAndSettle();

      // Close Register tab content should be visible
      expect(
        find.byKey(const ValueKey('close-register-total-amount')),
        findsOneWidget,
      );
    },
  );

  testWidgets('RegisterInputsSettingsTab validates 0 to 5000 range and saves', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? savedProfileId;
    QaRegisterInput? savedInput;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: RegisterInputsSettingsTab(
              profiles: QaProfile.values,
              selectedProfile: QaProfile.values.first,
              loadInput: (_) async =>
                  const QaRegisterInput(openingFloatAmount: 500.0),
              saveInput: (profileId, input) async {
                savedProfileId = profileId;
                savedInput = input;
              },
              onProfileChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final amountFinder = find.byKey(
      const ValueKey('register-opening-float-amount'),
    );
    expect(amountFinder, findsOneWidget);
    expect(find.text('500'), findsOneWidget);

    // Test over maximum (e.g. 5001)
    await tester.enterText(amountFinder, '5001');
    await tester.tap(find.byKey(const ValueKey('save-register-inputs')));
    await tester.pumpAndSettle();

    expect(find.textContaining('cannot exceed'), findsOneWidget);
    expect(savedInput, isNull);

    // Enter valid amount: 2000
    await tester.enterText(amountFinder, '2000');
    await tester.pumpAndSettle();
    expect(find.text('2000'), findsOneWidget);

    // Save valid input
    await tester.tap(find.byKey(const ValueKey('save-register-inputs')));
    await tester.pumpAndSettle();

    expect(savedProfileId, QaProfile.values.first.id);
    expect(savedInput, isNotNull);
    expect(savedInput!.openingFloatAmount, 2000.0);
    expect(find.textContaining('Saved Register opening float'), findsOneWidget);
  });

  testWidgets(
    'CloseRegisterInputsSettingsTab validates range and saves closing amount',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? savedProfileId;
      QaRegisterInput? savedInput;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: CloseRegisterInputsSettingsTab(
                profiles: QaProfile.values,
                selectedProfile: QaProfile.values.first,
                loadInput: (_) async =>
                    const QaRegisterInput(closeTotalAmount: 1500.0),
                saveInput: (profileId, input) async {
                  savedProfileId = profileId;
                  savedInput = input;
                },
                onProfileChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final amountFinder = find.byKey(
        const ValueKey('close-register-total-amount'),
      );
      expect(amountFinder, findsOneWidget);
      expect(find.text('1500'), findsOneWidget);

      // Enter amount 3500 and notes
      await tester.enterText(amountFinder, '3500');
      await tester.enterText(
        find.byKey(const ValueKey('close-register-notes')),
        'Evening shift close',
      );
      await tester.tap(
        find.byKey(const ValueKey('save-close-register-inputs')),
      );
      await tester.pumpAndSettle();

      expect(savedProfileId, QaProfile.values.first.id);
      expect(savedInput, isNotNull);
      expect(savedInput!.closeTotalAmount, 3500.0);
      expect(savedInput!.closeNotes, 'Evening shift close');
      expect(
        find.textContaining('Saved Close Register total cash'),
        findsOneWidget,
      );
    },
  );
}
