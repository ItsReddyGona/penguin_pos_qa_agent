import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/ai/models/qa_gen_ui.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/login_test_case.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_message_list.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_rich_message.dart';

void main() {
  Widget host(AiRichContent content) => MaterialApp(
    home: Scaffold(body: AssistantRichMessage(content: content)),
  );

  testWidgets(
    'preparation activity shows decision history line by line by default',
    (tester) async {
      await tester.pumpWidget(
        host(
          const AiRichPlanningSummary(
            steps: <String>[
              'Parsing request…',
              'Matching target profile…',
              'Validating plan against guardrails…',
            ],
            elapsedMs: 250,
          ),
        ),
      );

      // Decision history is expanded line by line by default
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
      expect(find.text('Parsing request…'), findsOneWidget);
      expect(find.text('Matching target profile…'), findsOneWidget);
      expect(find.text('Validating plan against guardrails…'), findsOneWidget);
    },
  );

  testWidgets('completed activity keeps both reasoning and plan JSON', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AiRichPlanningSummary(
          steps: <String>['Building test plan…'],
          elapsedMs: 1200,
          reasoning: 'Allocate the requested SKU to order one.',
          rawContent: '{"ordersCount":1}',
        ),
      ),
    );

    expect(find.text('Thought Process'), findsOneWidget);
    expect(
      find.textContaining('Allocate the requested SKU to order one.'),
      findsOneWidget,
    );

    await tester.tap(find.text('View raw plan JSON'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Validated Plan JSON'), findsOneWidget);
    expect(find.textContaining('"ordersCount": 1'), findsOneWidget);
  });

  testWidgets('does not duplicate completed planning trace during execution', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssistantMessageList(
            messages: <AiChatMessage>[
              AiChatMessage(role: AiChatRole.user, text: 'Run order suite'),
            ],
            scrollController: scrollController,
            planningEvents: const <AiModelEvent>[
              AiModelEvent(
                kind: AiModelEventKind.status,
                message: 'Plan validated against guardrails.',
              ),
            ],
            planningRunning: false,
            executionSteps: const <AiExecutionStep>[
              AiExecutionStep(
                scenarioName: 'Order 1',
                status: AiScenarioStatus.running,
              ),
            ],
            executionSuiteTitle: 'Order & Cash Payment',
            executionProfileLabel: 'KPN DEV',
            executionRunning: true,
          ),
        ),
      ),
    );

    expect(find.text('Plan validated against guardrails.'), findsNothing);
    expect(find.text('Order 1'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'validated plan summary card displays profile and scenarios cleanly',
    (tester) async {
      await tester.pumpWidget(
        host(
          const AiRichPlanSummary(
            profileLabel: 'KPN DEV',
            workflowLabel: 'Login & Terminal',
            scenarios: <AiScenarioRow>[AiScenarioRow(name: 'Valid Login Flow')],
          ),
        ),
      );

      expect(find.text('KPN DEV'), findsOneWidget);
      expect(find.text('Login & Terminal'), findsOneWidget);
      expect(find.text('Valid Login Flow'), findsOneWidget);
    },
  );

  testWidgets(
    'order report shows a separate result for every requested order',
    (tester) async {
      await tester.pumpWidget(
        host(
          const AiRichOrderReport(
            suiteTitle: 'Order & Cash Payment',
            profileLabel: 'KPN DEV',
            passed: true,
            totalDurationMs: 3200,
            orders: <AiOrderResult>[
              AiOrderResult(
                orderNumber: 1,
                itemSummary: 'SKU 22 · Non-weighed · Manual entry',
                passed: true,
                durationMs: 1500,
                cashAmount: 40,
              ),
              AiOrderResult(
                orderNumber: 2,
                itemSummary: 'SKU 11 · Non-weighed · Scan',
                passed: true,
                durationMs: 1700,
                cashAmount: 30,
              ),
            ],
            testChecks: <AiScenarioResult>[
              AiScenarioResult(
                name: 'SKU entry accepted',
                passed: true,
                durationMs: 500,
              ),
              AiScenarioResult(
                name: 'Cash payment completed',
                passed: true,
                durationMs: 700,
              ),
            ],
          ),
        ),
      );

      expect(find.text('2 orders completed'), findsOneWidget);
      expect(find.text('Order results'), findsOneWidget);
      expect(find.text('Order 1'), findsOneWidget);
      expect(find.text('Order 2'), findsOneWidget);
      expect(find.textContaining('SKU 22'), findsOneWidget);
      expect(find.textContaining('SKU 11'), findsOneWidget);
      expect(find.text('Test checks applied to every order'), findsOneWidget);
      expect(find.text('SKU entry accepted'), findsOneWidget);
      expect(find.text('Cash payment completed'), findsOneWidget);
    },
  );

  testWidgets(
    'order report renders stages, SKU items, weight formatting, and failure callouts',
    (tester) async {
      await tester.pumpWidget(
        host(
          const AiRichOrderReport(
            suiteTitle: 'Order & Cash Payment',
            profileLabel: 'KPN DEV',
            passed: false,
            totalDurationMs: 4500,
            aggregateTotalPayable: 152.0,
            aggregatePayableAmount: 152,
            orders: <AiOrderResult>[
              AiOrderResult(
                orderNumber: 3,
                itemSummary: '3 SKU items',
                passed: false,
                durationMs: 1500,
                cashAmount: 152,
                totalPayable: 152.0,
                orderNumberLabel: 'ORD-10003',
                error: 'Order total mismatch detected',
                skuResults: <AiOrderSkuResult>[
                  AiOrderSkuResult(
                    sku: '22',
                    type: 'Non-Weighed SKU',
                    entryMode: 'Manual Numpad',
                    passed: true,
                  ),
                  AiOrderSkuResult(
                    sku: '1',
                    type: 'Non-Weighed SKU',
                    entryMode: 'Manual Numpad',
                    passed: false,
                    weight: 0.001,
                    error: 'Weight mismatch for non-weighed item',
                  ),
                ],
              ),
            ],
            testChecks: <AiScenarioResult>[],
          ),
        ),
      );

      expect(find.text('Order run finished with failures'), findsOneWidget);
      expect(find.text('Order 3'), findsOneWidget);
      expect(find.text('Login Check'), findsOneWidget);
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('SKUs Punched'), findsOneWidget);
      expect(find.text('(2 items)'), findsOneWidget);
      expect(find.text('22'), findsOneWidget);
      expect(find.text('0.001 kg'), findsOneWidget);
      expect(find.text('Weight mismatch for non-weighed item'), findsOneWidget);
      expect(find.text('Payment'), findsOneWidget);
      expect(find.text('Order Success'), findsOneWidget);
      expect(find.text('Order total mismatch detected'), findsOneWidget);
    },
  );

  testWidgets(
    'login report renders structured case table with IDs and status chips',
    (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        host(
          AiRichLoginReport(
            suiteTitle: 'Login & Terminal',
            profileLabel: 'KPN DEV',
            suite: LoginSuiteResult(
              startedAt: now.subtract(const Duration(seconds: 5)),
              finishedAt: now,
              results: <LoginTestCaseResult>[
                LoginTestCaseResult(
                  testCaseId: 'TC-LOG-01',
                  testCase: 'Valid Login Flow',
                  description: 'Logs into terminal with valid credentials',
                  credentials: '1001 / secret',
                  status: LoginTestCaseStatus.passed,
                  startedAt: now.subtract(const Duration(seconds: 4)),
                  finishedAt: now.subtract(const Duration(seconds: 1)),
                ),
              ],
            ),
            cleanupPassed: true,
            cleanupDetail: 'Session logout completed successfully.',
          ),
        ),
      );

      expect(find.text('Login suite output'), findsOneWidget);
      expect(find.text('TC-LOG-01'), findsOneWidget);
      expect(find.text('Valid Login Flow'), findsOneWidget);
      expect(
        find.text('Logs into terminal with valid credentials'),
        findsOneWidget,
      );
      expect(find.text('Logout Cleanup'), findsOneWidget);
      expect(
        find.text('Session logout completed successfully.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('keeps completed activity above its generated result', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssistantMessageList(
            messages: <AiChatMessage>[
              AiChatMessage(
                role: AiChatRole.assistant,
                text: 'Here is the login flow.',
                richContent: const AiRichKnowledgeAnswer(
                  answer: AiKnowledgeAnswer(
                    title: 'Login flow',
                    summary: 'Login coverage.',
                  ),
                ),
                activitySummary: const AiRichPlanningSummary(
                  steps: <String>[
                    'Reading QA request…',
                    'Matched Login & Terminal coverage.',
                  ],
                  elapsedMs: 2200,
                ),
              ),
            ],
            scrollController: scrollController,
          ),
        ),
      ),
    );

    expect(find.text('Worked for 2s · 2 checks'), findsOneWidget);
    expect(find.text('Reading QA request…'), findsOneWidget);
    expect(find.text('Matched Login & Terminal coverage.'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Worked for 2s · 2 checks')).dy,
      lessThan(tester.getTopLeft(find.text('Login flow')).dy),
    );
  });

  testWidgets(
    'keeps thinking, constructed plan, execution, and result in chronological order',
    (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.binding.setSurfaceSize(const Size(1280, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssistantMessageList(
              messages: <AiChatMessage>[
                AiChatMessage(role: AiChatRole.user, text: 'Run login tests'),
                AiChatMessage(
                  role: AiChatRole.assistant,
                  text: 'Plan validated.',
                  activitySummary: const AiRichPlanningSummary(
                    steps: <String>['Parsing request…'],
                    elapsedMs: 15000,
                  ),
                  richContent: const AiRichLaunchPreview(
                    profileLabel: 'KPN DEV',
                    workflowLabel: 'Login & Terminal',
                    orders: <AiOrderLaunchPreview>[],
                    steps: <String>['Run configured login cases'],
                  ),
                ),
                AiChatMessage(
                  role: AiChatRole.assistant,
                  text: 'Test suite completed successfully.',
                  richContent: const AiRichTestReport(
                    suiteTitle: 'Login & Terminal',
                    profileLabel: 'KPN DEV',
                    passed: true,
                    totalDurationMs: 1000,
                    scenarioResults: <AiScenarioResult>[],
                  ),
                ),
              ],
              scrollController: scrollController,
            ),
          ),
        ),
      );

      final thinkingY = tester
          .getTopLeft(find.text('Worked for 15s · 1 checks'))
          .dy;
      final planY = tester.getTopLeft(find.text('Login execution plan')).dy;
      final resultY = tester
          .getTopLeft(find.text('Test suite completed successfully.'))
          .dy;

      expect(thinkingY, lessThan(planY));
      expect(planY, lessThan(resultY));
      expect(find.text('Parsing request…'), findsOneWidget);
    },
  );

  testWidgets('knowledge answer progressively reveals a safe flow chart', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AiRichKnowledgeAnswer(
          answer: AiKnowledgeAnswer(
            title: 'Login flow',
            summary: 'Login coverage.',
            sections: <AiKnowledgeSection>[
              AiKnowledgeSection(
                title: 'Test cases',
                items: <String>['Login Validation'],
              ),
            ],
            diagrams: <AiKnowledgeDiagram>[
              AiKnowledgeDiagram(
                title: 'Login flow chart',
                nodes: <AiKnowledgeDiagramNode>[
                  AiKnowledgeDiagramNode(
                    id: 'validate',
                    label: 'Login Validation',
                    kind: AiKnowledgeDiagramNodeKind.decision,
                  ),
                  AiKnowledgeDiagramNode(
                    id: 'valid_login',
                    label: 'Valid Login Flow',
                    kind: AiKnowledgeDiagramNodeKind.end,
                  ),
                ],
                edges: <AiKnowledgeDiagramEdge>[
                  AiKnowledgeDiagramEdge(
                    fromNodeId: 'validate',
                    toNodeId: 'valid_login',
                    label: 'Yes',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Login flow'), findsOneWidget);
    expect(find.text('Login flow chart'), findsNothing);

    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Login Validation'), findsNWidgets(2));
    expect(find.text('Login flow chart'), findsOneWidget);
    expect(find.text('Valid Login Flow'), findsOneWidget);
    expect(find.text('DECISION'), findsOneWidget);
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
  });

  testWidgets('renders a validated API sequence with transport and mode', (
    tester,
  ) async {
    final document = QaGenUiDocument.tryParse(<String, Object?>{
      'components': <Object?>[
        <String, Object?>{
          'component': 'apiSequence',
          'title': 'Order API activity',
          'events': <Object?>[
            <String, Object?>{
              'method': 'GET',
              'endpoint': '/catalog/items/22',
              'durationMs': 184,
              'transport': 'http',
              'mode': 'local',
              'result': 'success',
              'statusCode': 200,
            },
          ],
        },
      ],
    });

    expect(document, isNotNull);
    await tester.pumpWidget(host(AiRichGenUi(document: document!)));

    expect(find.text('Order API activity'), findsOneWidget);
    expect(find.text('GET'), findsOneWidget);
    expect(find.text('/catalog/items/22'), findsOneWidget);
    expect(find.text('184ms'), findsOneWidget);
    expect(find.text('HTTP · Local · 200'), findsOneWidget);
  });

  testWidgets(
    'renders launch preview card with structured orders and monospace SKU items',
    (tester) async {
      await tester.pumpWidget(
        host(
          const AiRichLaunchPreview(
            profileLabel: 'kpn-dev',
            workflowLabel: 'Order & Cash Payment',
            dataSourceLabel: 'Settings → Order Inputs',
            allocationModeLabel: 'Common payload (same for all)',
            orders: <AiOrderLaunchPreview>[
              AiOrderLaunchPreview(
                orderNumber: 1,
                items: <AiOrderItemRow>[
                  AiOrderItemRow(
                    skuCode: '1',
                    typeLabel: 'Weighed',
                    entryModeLabel: 'Scan (Barcode)',
                    allocationLabel: 'Order 1',
                  ),
                  AiOrderItemRow(
                    skuCode: '22',
                    typeLabel: 'Non-Weighed',
                    entryModeLabel: 'Manual (Numpad)',
                    allocationLabel: 'Order 1',
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      expect(find.text('Final order allocation'), findsOneWidget);
      expect(find.text('Order & Cash Payment · kpn-dev'), findsOneWidget);
      expect(
        find.text('Settings → Order Inputs · Common payload (same for all)'),
        findsOneWidget,
      );
      expect(find.text('1 order'), findsOneWidget);
      expect(find.text('2 items'), findsNWidgets(2));
      expect(find.text('Order 1'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('22'), findsOneWidget);
      expect(find.text('Auto'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('Weighed'), findsOneWidget);
      expect(find.text('Scan (Barcode)'), findsOneWidget);
      expect(find.text('Non-Weighed'), findsOneWidget);
      expect(find.text('Manual (Numpad)'), findsOneWidget);
    },
  );

  testWidgets('renders login execution plan with sequential test cases table', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AiRichLaunchPreview(
          profileLabel: 'kpn-dev',
          workflowLabel: 'Login & Terminal',
          orders: <AiOrderLaunchPreview>[],
          loginCases: <LoginTestCaseDefinition>[
            LoginTestCaseDefinition(
              id: 'TC-01',
              name: 'Valid Login & Terminal Selection',
              expectedResult: LoginExpectedResult.successfulLogin,
            ),
            LoginTestCaseDefinition(
              id: 'TC-02',
              name: 'Invalid Credentials Validation',
              expectedResult: LoginExpectedResult.authenticationRejected,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Login execution plan'), findsOneWidget);
    expect(find.text('Login & Terminal · kpn-dev'), findsOneWidget);
    expect(find.text('2 Test Cases'), findsOneWidget);
    expect(find.text('TC-01'), findsOneWidget);
    expect(find.text('Valid Login & Terminal Selection'), findsOneWidget);
    expect(find.text('Successful login'), findsOneWidget);
    expect(find.text('TC-02'), findsOneWidget);
    expect(find.text('Invalid credentials'), findsOneWidget);
    expect(find.text('Ready'), findsNWidgets(2));
  });

  test('rejects unknown components and unsafe endpoint values', () {
    expect(
      QaGenUiDocument.tryParse(<String, Object?>{
        'components': <Object?>[
          <String, Object?>{'component': 'arbitraryWidget', 'title': 'Nope'},
        ],
      }),
      isNull,
    );
    expect(
      QaGenUiDocument.tryParse(<String, Object?>{
        'components': <Object?>[
          <String, Object?>{
            'component': 'apiSequence',
            'title': 'API activity',
            'events': <Object?>[
              <String, Object?>{
                'method': 'GET',
                'endpoint': 'https://host/path?token=secret',
                'durationMs': 2,
                'transport': 'https',
                'mode': 'cloud',
                'result': 'success',
              },
            ],
          },
        ],
      }),
      isNotNull,
    );
  });
}
