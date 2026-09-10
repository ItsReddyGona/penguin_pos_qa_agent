import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/ai/orchestration/ai_orchestrator.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';

void main() {
  final nonProductionProfiles = <QaProfile>[QaProfile.values.first];

  test(
    'explains an inline login reference without requiring a model',
    () async {
      final response = await AiOrchestrator(
        profiles: nonProductionProfiles,
        provider: null,
      ).respond(input: 'Explain /login', history: <AiChatMessage>[]);

      expect(response.kind, AiAssistantResponseKind.knowledge);
      expect(response.state, AiPlanState.needsInput);
      expect(response.plan, isNull);
      expect(response.canExecute, isFalse);
      expect(response.knowledge!.title, 'Login & Terminal flow');
      expect(response.knowledge!.sections.single.items, hasLength(7));
      expect(response.knowledge!.suiteIds, <String>['login_terminal']);
      expect(response.knowledge!.diagrams.single.edges, isNotEmpty);
    },
  );

  test(
    'answers Flutter testing knowledge without a model or execution plan',
    () async {
      final response =
          await AiOrchestrator(
            profiles: nonProductionProfiles,
            provider: null,
          ).respond(
            input: 'Can Flutter Driver read BLoC state or inspect dialogs?',
            history: <AiChatMessage>[],
          );

      expect(response.kind, AiAssistantResponseKind.knowledge);
      expect(response.plan, isNull);
      expect(response.knowledge!.title, 'Flutter QA testing knowledge');
      expect(response.knowledge!.summary, contains('Flutter Driver cannot'));
      expect(
        response.knowledge!.sections.map((section) => section.title),
        contains('BLoC'),
      );
      expect(
        response.knowledge!.sources,
        contains('https://pub.dev/packages/bloc_test'),
      );
    },
  );

  test('keeps explicit Flutter Driver login requests executable', () async {
    final response =
        await AiOrchestrator(
          profiles: nonProductionProfiles,
          provider: null,
        ).respond(
          input: '/login Flutter Driver /kpn-stage',
          history: <AiChatMessage>[],
        );

    expect(response.kind, isNot(AiAssistantResponseKind.knowledge));
    expect(response.plan?.workflow, AiWorkflow.loginFullSequence);
    expect(response.plan?.profileId, 'kpn-stage');
  });

  test('keeps natural Flutter Driver login test requests executable', () async {
    final response =
        await AiOrchestrator(
          profiles: nonProductionProfiles,
          provider: null,
        ).respond(
          input: 'Run Flutter Driver login test in KPN STAGE',
          history: <AiChatMessage>[],
        );

    expect(response.kind, isNot(AiAssistantResponseKind.knowledge));
    expect(response.plan?.workflow, AiWorkflow.loginFullSequence);
    expect(response.plan?.profileId, 'kpn-stage');
  });

  test(
    'scopes an above-flow follow-up to the prior knowledge answer',
    () async {
      final orchestrator = AiOrchestrator(
        profiles: nonProductionProfiles,
        provider: null,
      );
      final initial = await orchestrator.respond(
        input: 'Explain the login flow',
        history: <AiChatMessage>[],
      );
      final response = await orchestrator.respond(
        input: 'Can you explain the above with a flow chart?',
        history: <AiChatMessage>[
          AiChatMessage(role: AiChatRole.user, text: 'Explain the login flow'),
          AiChatMessage(
            role: AiChatRole.assistant,
            text: initial.message,
            richContent: AiRichKnowledgeAnswer(answer: initial.knowledge!),
          ),
        ],
      );

      expect(response.kind, AiAssistantResponseKind.knowledge);
      expect(response.knowledge!.suiteIds, <String>['login_terminal']);
      expect(response.knowledge!.sections, hasLength(1));
      expect(response.knowledge!.diagrams, hasLength(1));
      expect(response.knowledge!.diagrams.single.edges, hasLength(6));
    },
  );

  test(
    'asks for a flow choice when a reference has no prior context',
    () async {
      final response =
          await AiOrchestrator(
            profiles: nonProductionProfiles,
            provider: null,
          ).respond(
            input: 'Explain the above with a flow chart',
            history: <AiChatMessage>[],
          );

      expect(response.kind, AiAssistantResponseKind.clarification);
      expect(response.message, contains('Which QA flow'));
      expect(response.plan, isNull);
    },
  );

  test('lists catalogue test cases as a read-only response', () async {
    final response =
        await AiOrchestrator(
          profiles: nonProductionProfiles,
          provider: null,
        ).respond(
          input: 'What order test cases exist?',
          history: <AiChatMessage>[],
        );

    expect(response.kind, AiAssistantResponseKind.knowledge);
    expect(response.plan, isNull);
    expect(response.knowledge!.sections.single.title, 'Order & Cash Payment');
    expect(response.knowledge!.sections.single.items, hasLength(6));
  });

  test(
    'reports runnable suites for an approved non-production profile',
    () async {
      final response =
          await AiOrchestrator(
            profiles: nonProductionProfiles,
            provider: null,
          ).respond(
            input: 'What can I run in KPN STAGE?',
            history: <AiChatMessage>[],
          );

      expect(response.kind, AiAssistantResponseKind.knowledge);
      expect(response.canExecute, isFalse);
      expect(response.knowledge!.title, 'Runnable QA suites');
      expect(response.knowledge!.sections, hasLength(4));
    },
  );

  test(
    'recognizes a natural-language request for runnable KPN and SAVO suites',
    () async {
      final response =
          await AiOrchestrator(
            profiles: <QaProfile>[QaProfile.values[0], QaProfile.values[4]],
            provider: null,
          ).respond(
            input:
                'What are possible test cases available in KPN or SAVO I can run?',
            history: <AiChatMessage>[],
          );

      expect(response.kind, AiAssistantResponseKind.knowledge);
      expect(response.knowledge!.title, 'Runnable QA suites');
      expect(response.message, contains('KPN STAGE and SAVO STAGE'));
      expect(response.canExecute, isFalse);
    },
  );

  test('lists configured profiles without creating a test plan', () async {
    final response =
        await AiOrchestrator(
          profiles: nonProductionProfiles,
          provider: null,
        ).respond(
          input: 'Show configured environments',
          history: <AiChatMessage>[],
        );

    expect(response.kind, AiAssistantResponseKind.knowledge);
    expect(response.plan, isNull);
    expect(
      response.knowledge!.sections.single.items.single,
      contains('KPN STAGE'),
    );
  });

  test(
    'blocks a production runnable-suite query without returning a plan',
    () async {
      const production = QaProfile(
        id: 'kpn-prod',
        label: 'KPN PROD',
        entity: 'kpn',
        environment: 'production',
      );
      final response =
          await AiOrchestrator(
            profiles: const <QaProfile>[production],
            provider: null,
          ).respond(
            input: 'What can I run in KPN PROD?',
            history: <AiChatMessage>[],
          );

      expect(response.kind, AiAssistantResponseKind.blocked);
      expect(response.state, AiPlanState.unsupported);
      expect(response.plan, isNull);
      expect(response.canExecute, isFalse);
    },
  );

  test('parses model knowledge without accepting an attached plan', () {
    final response = AiAssistantResponse.fromJson(<String, Object?>{
      'kind': 'knowledge',
      'message': 'Login details.',
      'state': 'needsInput',
      'plan': <String, Object?>{
        'workflow': 'loginFullSequence',
        'profileId': 'kpn-stage',
      },
      'knowledge': <String, Object?>{
        'title': 'Login',
        'summary': 'Login coverage.',
        'sections': <Object?>[
          <String, Object?>{
            'title': 'Cases',
            'items': <String>['Login Validation'],
          },
        ],
        'sources': <String>['Login & Terminal'],
      },
    });

    expect(response.kind, AiAssistantResponseKind.knowledge);
    expect(response.knowledge!.sections.single.title, 'Cases');
    expect(response.plan, isNull);
    expect(response.canExecute, isFalse);
  });
}
