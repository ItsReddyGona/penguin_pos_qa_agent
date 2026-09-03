import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/ai_assistant_workspace.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/qa_settings_screen.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/qa_agent_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows AI-first setup prompt when preferences are missing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const QaAgentGuiApp());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(find.text('QA Assistant'), findsOneWidget);
    expect(find.text('Welcome to QA Assistant'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
  });

  testWidgets(
    'shows AI assistant workspace with top bar, composer, and execution log when setup is complete',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues(<String, Object>{
        'penguin_pos_qa_initial_setup_complete': true,
      });
      await tester.pumpWidget(const QaAgentGuiApp());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();

      expect(find.text('QA Assistant'), findsOneWidget);
      expect(find.text('Manual mode'), findsOneWidget);
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Terminal'), findsOneWidget);
    },
  );

  testWidgets(
    'switches mode via onExitAiMode callback in AiAssistantWorkspace',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var exitCalled = false;
      final messages = <AiChatMessage>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiAssistantWorkspace(
              modelConfigured: true,
              running: false,
              messages: messages,
              onAddMessage: (msg) => messages.add(msg),
              activityMessages: const <QaActivityMessage>[],
              apiTraces: const [],
              executionSteps: const <AiExecutionStep>[],
              executionSuiteTitle: '',
              executionProfileLabel: '',
              onSend: (input, history, onEvent) async =>
                  const AiAssistantResponse(
                    message: 'Ok',
                    state: AiPlanState.needsInput,
                    missingFields: <String>[],
                  ),
              onRunPlan: (_) {},
              onOpenSettings: () {},
              onExitAiMode: () => exitCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('QA Assistant'), findsOneWidget);
      expect(find.text('Manual mode'), findsOneWidget);

      await tester.tap(find.text('Manual mode'));
      expect(exitCalled, isTrue);
    },
  );

  testWidgets('shows a launch preview for a validated login plan', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final messages = <AiChatMessage>[];

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          home: Scaffold(
            body: AiAssistantWorkspace(
              modelConfigured: true,
              running: false,
              messages: messages,
              onAddMessage: (message) => setState(() => messages.add(message)),
              activityMessages: const <QaActivityMessage>[],
              apiTraces: const [],
              executionSteps: const <AiExecutionStep>[],
              executionSuiteTitle: '',
              executionProfileLabel: '',
              onSend: (input, history, onEvent) async =>
                  const AiAssistantResponse(
                    message: 'Login plan ready.',
                    state: AiPlanState.readyForConfirmation,
                    plan: AiTestPlan(
                      workflow: AiWorkflow.loginFullSequence,
                      profileId: 'kpn-stage',
                    ),
                  ),
              onRunPlan: (_) {},
              onOpenSettings: () {},
              onExitAiMode: () {},
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Run login test');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Login execution plan'), findsOneWidget);
    expect(find.textContaining('Login & Terminal · kpn-stage'), findsOneWidget);
    expect(find.text('Final order allocation'), findsNothing);
  });

  testWidgets(
    'shows full-screen QaSettingsScreen workspace with sidebar tabs and settings options',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var closeCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: QaSettingsScreen(
            profiles: QaProfile.values,
            activeProfile: QaProfile.values.first,
            aiModelConfig: const AiModelConfig(),
            noticeDisplayMode: QaTestNoticeDisplayMode.warningsAndErrors,

            flutterPath: 'flutter',
            appRoot: '/Users/reddygona/Documents/PenguinPOS/penguin_pos',
            onProfileSelected: (_) {},
            onProfilesUpdated: (_) {},
            onAiModelConfigUpdated: (_) {},
            onNoticeDisplayModeUpdated: (_) {},
            onClose: () => closeCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('QA Agent Settings'), findsOneWidget);
      expect(find.text('Credentials & PINs'), findsOneWidget);
      expect(find.text('Profiles & Environments'), findsOneWidget);
      expect(find.text('AI Models & Endpoint'), findsOneWidget);
      expect(find.text('QA Notices'), findsOneWidget);
      expect(find.text('System & Engine Paths'), findsOneWidget);
      expect(find.text('Support & System Info'), findsOneWidget);

      // Tap Profiles & Environments tab on left sidebar
      await tester.tap(find.text('Profiles & Environments'));
      await tester.pumpAndSettle();

      expect(find.text('Add New Profile'), findsOneWidget);

      await tester.tap(find.text('QA Notices'));
      await tester.pumpAndSettle();
      expect(find.text('Notice display mode'), findsOneWidget);
      expect(find.text('Warnings & errors'), findsOneWidget);

      // Tap Done button to exit Settings back to workspace
      await tester.tap(find.text('Done'));
      expect(closeCalled, isTrue);
    },
  );

  test('CancellationToken triggers listeners and updates isCancelled', () {
    final token = CancellationToken();
    expect(token.isCancelled, isFalse);

    var listenerFired = false;
    token.onCancel(() => listenerFired = true);

    token.cancel();
    expect(token.isCancelled, isTrue);
    expect(listenerFired, isTrue);

    // Subsequent listeners execute immediately when token is already cancelled
    var lateListenerFired = false;
    token.onCancel(() => lateListenerFired = true);
    expect(lateListenerFired, isTrue);
  });
}
