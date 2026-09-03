import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/ai_assistant_workspace.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_message_list.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_model_trace.dart';

void main() {
  testWidgets(
    'reasoning chunks remain one stream and do not become planning checks',
    (tester) async {
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
                onAddMessage: (message) {
                  setState(() => messages.add(message));
                },
                activityMessages: const <QaActivityMessage>[],
                apiTraces: const [],
                executionSteps: const <AiExecutionStep>[],
                executionSuiteTitle: '',
                executionProfileLabel: '',
                onSend: (input, history, onEvent) async {
                  onEvent(
                    const AiModelEvent(
                      kind: AiModelEventKind.status,
                      message: 'Connecting to the configured model…',
                    ),
                  );
                  for (final chunk in <String>[
                    'The ',
                    'user ',
                    'wants ',
                    'three ',
                    'orders.',
                  ]) {
                    onEvent(
                      AiModelEvent(
                        kind: AiModelEventKind.reasoning,
                        message: chunk,
                      ),
                    );
                  }
                  onEvent(
                    const AiModelEvent(
                      kind: AiModelEventKind.status,
                      message: 'Validating plan against guardrails…',
                    ),
                  );
                  return const AiAssistantResponse(
                    message: 'More input is required.',
                    state: AiPlanState.needsInput,
                  );
                },
                onRunPlan: (_) {},
                onOpenSettings: () {},
                onExitAiMode: () {},
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Prepare an order plan');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      expect(find.textContaining('2 checks'), findsOneWidget);
      expect(find.textContaining('Thinking:'), findsNothing);
      expect(find.text('The'), findsNothing);
      expect(find.text('user'), findsNothing);
      expect(find.text('Thought Process'), findsOneWidget);
      expect(
        find.textContaining('The user wants three orders.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('live plan JSON uses distinct syntax token colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AssistantModelTrace(
            events: <AiModelEvent>[
              AiModelEvent(
                kind: AiModelEventKind.status,
                message: 'Building test plan via model…',
              ),
            ],
            running: true,
            liveStream: '{"skuCode":"22","ordersCount":1,"enabled":true}',
          ),
        ),
      ),
    );
    await tester.pump();

    final jsonText = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .firstWhere(
          (widget) =>
              widget.textSpan?.toPlainText().contains('skuCode') ?? false,
        );
    final colors = jsonText.textSpan!.children!
        .whereType<TextSpan>()
        .map((span) => span.style?.color)
        .whereType<Color>()
        .toSet();

    expect(colors.length, greaterThanOrEqualTo(4));
    expect(jsonText.textSpan!.toPlainText(), contains('"skuCode": "22"'));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'completed activity replaces the temporary trace instead of duplicating checks',
    (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssistantMessageList(
              messages: <AiChatMessage>[
                AiChatMessage(
                  role: AiChatRole.assistant,
                  text: 'Plan ready.',
                  activitySummary: const AiRichPlanningSummary(
                    steps: <String>['Parsing request…'],
                    reasoning: 'Selected the saved login suite.',
                  ),
                ),
              ],
              scrollController: scrollController,
              planningEvents: const <AiModelEvent>[
                AiModelEvent(
                  kind: AiModelEventKind.status,
                  message: 'Parsing request…',
                ),
              ],
              planningRunning: false,
              executionSteps: const <AiExecutionStep>[
                AiExecutionStep(
                  scenarioName: 'Login suite',
                  status: AiScenarioStatus.running,
                ),
              ],
              executionRunning: true,
            ),
          ),
        ),
      );

      expect(find.text('Parsing request…'), findsOneWidget);
      expect(find.text('Thought Process'), findsOneWidget);
      expect(find.byType(AssistantModelTrace), findsNothing);
    },
  );
}
