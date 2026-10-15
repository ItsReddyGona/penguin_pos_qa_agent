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

  testWidgets(
    'CloseRegisterInputsSettingsTab updates total amount dynamically when typing notes and coins',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      QaRegisterInput? savedInput;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: CloseRegisterInputsSettingsTab(
                profiles: QaProfile.values,
                selectedProfile: QaProfile.values.first,
                loadInput: (_) async => const QaRegisterInput(
                  closeTotalAmount: 0.0,
                  closeNotesMap: <int, int>{},
                  closeCoinsMap: <int, int>{},
                ),
                saveInput: (_, input) async {
                  savedInput = input;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify ₹2000 is completely absent
      expect(
        find.byKey(const ValueKey<String>('close-register-note-2000')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('close-register-coin-2000')),
        findsNothing,
      );

      // Verify coins for denominations >= 50 are absent
      expect(
        find.byKey(const ValueKey<String>('close-register-coin-500')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('close-register-coin-200')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('close-register-coin-100')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('close-register-coin-50')),
        findsNothing,
      );

      // Verify coins for denominations <= 20 are present
      expect(
        find.byKey(const ValueKey<String>('close-register-coin-20')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('close-register-coin-10')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('close-register-coin-5')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('close-register-coin-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('close-register-coin-1')),
        findsOneWidget,
      );

      // Verify notes for denomination 5 is present, and < 5 (2, 1) are absent
      expect(
        find.byKey(const ValueKey<String>('close-register-note-5')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('close-register-note-2')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('close-register-note-1')),
        findsNothing,
      );

      // Enter 2 notes of 500
      final note500Finder = find.byKey(
        const ValueKey<String>('close-register-note-500'),
      );
      expect(note500Finder, findsOneWidget);
      await tester.enterText(note500Finder, '2');
      await tester.pumpAndSettle();

      // Enter 5 coins of 10
      final coin10Finder = find.byKey(
        const ValueKey<String>('close-register-coin-10'),
      );
      expect(coin10Finder, findsOneWidget);
      await tester.enterText(coin10Finder, '5');
      await tester.pumpAndSettle();

      // Total sum should be (2 * 500) + (5 * 10) = 1050
      expect(find.text('1050'), findsOneWidget);
      expect(find.text('Sum: ₹1050'), findsOneWidget);

      // Save
      await tester.tap(
        find.byKey(const ValueKey<String>('save-close-register-inputs')),
      );
      await tester.pumpAndSettle();

      expect(savedInput, isNotNull);
      expect(savedInput!.closeTotalAmount, 1050.0);
      expect(savedInput!.closeNotesMap[500], 2);
      expect(savedInput!.closeCoinsMap[10], 5);
    },
  );
}
