import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/test_suite_model.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/register/register_suite_screen.dart';

void main() {
  final registerSuite = TestSuiteItem.availableSuites.firstWhere(
    (suite) => suite.id == 'register',
  );
  final profile = QaProfile.values.first;

  testWidgets('RegisterSuiteScreen renders configuration, scenarios and runs', (
    tester,
  ) async {
    var runCount = 0;
    var stopCount = 0;
    var settingsCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RegisterSuiteScreen(
            suite: registerSuite,
            currentProfile: profile,
            targetMode: QaTargetMode.local,
            flutterPath: 'flutter',
            appRoot: '/mock/penguin_pos',
            running: false,
            lastExecutionPassed: null,
            lastExecutionDuration: null,
            lastExecutionDetails: null,
            wasAppClosedByUser: false,
            scenariosCompleted: const <String>[],
            openingFloatAmount: 1250.0,
            onRunSuite: () => runCount++,
            onStopSuite: () => stopCount++,
            onOpenSettings: () => settingsCount++,
          ),
        ),
      ),
    );

    // Verify UI components
    expect(find.text('Open Register'), findsOneWidget);
    expect(find.text('₹1250'), findsOneWidget);
    expect(find.text('Configured Opening Float Amount'), findsOneWidget);
    expect(find.text('Open Register Flow'), findsOneWidget);
    expect(find.text('Run Suite'), findsOneWidget);

    // Tap Run Suite
    await tester.tap(find.text('Run Suite'));
    await tester.pump();
    expect(runCount, equals(1));

    // Tap Change Float Cash
    await tester.tap(find.text('Change Float Cash'));
    await tester.pump();
    expect(settingsCount, equals(1));
  });

  testWidgets('RegisterSuiteScreen displays running and success states', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RegisterSuiteScreen(
            suite: registerSuite,
            currentProfile: profile,
            targetMode: QaTargetMode.local,
            flutterPath: 'flutter',
            appRoot: '/mock/penguin_pos',
            running: true,
            lastExecutionPassed: null,
            lastExecutionDuration: null,
            lastExecutionDetails: null,
            wasAppClosedByUser: false,
            scenariosCompleted: const <String>[],
            openingFloatAmount: 500.0,
            onRunSuite: () {},
            onStopSuite: () {},
          ),
        ),
      ),
    );

    expect(find.text('Stop Suite'), findsOneWidget);

    // Rebuild in passed state
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RegisterSuiteScreen(
            suite: registerSuite,
            currentProfile: profile,
            targetMode: QaTargetMode.local,
            flutterPath: 'flutter',
            appRoot: '/mock/penguin_pos',
            running: false,
            lastExecutionPassed: true,
            lastExecutionDuration: const Duration(seconds: 4),
            lastExecutionDetails: null,
            wasAppClosedByUser: false,
            scenariosCompleted: const <String>['Open Register Flow'],
            openingFloatAmount: 500.0,
            onRunSuite: () {},
            onStopSuite: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Execution output'), findsOneWidget);
    expect(find.text('PASSED'), findsOneWidget);
  });

  testWidgets('RegisterSuiteScreen displays reconciliation alert in Output tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RegisterSuiteScreen(
            suite: registerSuite,
            currentProfile: profile,
            targetMode: QaTargetMode.local,
            flutterPath: 'flutter',
            appRoot: '/mock/penguin_pos',
            running: false,
            lastExecutionPassed: false,
            lastExecutionDuration: const Duration(seconds: 2),
            lastExecutionDetails:
                'Complete the Reconciliation to open New Register',
            wasAppClosedByUser: false,
            scenariosCompleted: const <String>[],
            openingFloatAmount: 500.0,
            onRunSuite: () {},
            onStopSuite: () {},
          ),
        ),
      ),
    );

    // Tap Output tab
    await tester.tap(find.text('Output'));
    await tester.pumpAndSettle();

    expect(find.text('Execution output'), findsOneWidget);
    expect(find.text('FAILED'), findsOneWidget);
    expect(find.text('Reconciliation Required'), findsOneWidget);
    expect(
      find.text(
        'Complete the Reconciliation to open New Register. The previous register period must be reconciled and closed before opening a new register.',
      ),
      findsOneWidget,
    );
  });
}
