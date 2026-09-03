import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/ai/orchestration/ai_orchestrator.dart';
import 'package:penguin_pos_qa_agent/ai/orchestration/slash_command_parser.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';

void main() {
  group('AI planning guardrails', () {
    final profiles = QaProfile.values;

    test('slash command selects only a configured profile and workflow', () {
      final response = SlashCommandParser().parse('/kpn-dev /order', profiles);

      expect(response, isNotNull);
      expect(response!.plan!.profileId, 'kpn-dev');
      expect(response.plan!.workflow, AiWorkflow.orderCashPayment);
      expect(response.plan!.ordersCount, 1);
      expect(response.plan!.inputSource, AiInputSource.settings);
      expect(response.state, AiPlanState.readyForConfirmation);
      expect(response.missingFields, isEmpty);
    });

    test('only exposes singular login and order slash commands', () {
      final response = SlashCommandParser().parse(
        '/orders 3 kpn-dev',
        profiles,
      );

      expect(response, isNotNull);
      expect(response!.plan, isNull);
      expect(response.message, contains('/login'));
      expect(response.message, contains('/order'));
      expect(response.message, isNot(contains('/orders')));
    });

    test('slash login preserves an explicit back-to-back repeat count', () {
      final response = SlashCommandParser().parse(
        'test /login in kpn dev back to back 2 times',
        profiles,
      );

      expect(response, isNotNull);
      expect(response!.state, AiPlanState.readyForConfirmation);
      expect(response.plan!.workflow, AiWorkflow.loginFullSequence);
      expect(response.plan!.repeatCount, 2);
      expect(response.plan!.ordersCount, 2);
      expect(response.plan!.inputSource, AiInputSource.settings);
    });

    test('unknown profile cannot produce a runnable plan', () {
      final response = SlashCommandParser().parse(
        '/unknown-dev /login',
        profiles,
      );

      expect(response, isNotNull);
      expect(response!.plan, isNull);
      expect(response.missingFields, contains('profile'));
    });

    test(
      'natural-language login selects the configured dev profile locally',
      () {
        final response = SlashCommandParser().parseNaturalWorkflow(
          'test login case in kpn dev',
          profiles,
        );

        expect(response, isNotNull);
        expect(response!.state, AiPlanState.readyForConfirmation);
        expect(response.plan!.workflow, AiWorkflow.loginFullSequence);
        expect(response.plan!.profileId, 'kpn-dev');
      },
    );

    test('natural-language login without a profile asks for one', () {
      final response = SlashCommandParser().parseNaturalWorkflow(
        'verify the login flow',
        profiles,
      );

      expect(response, isNotNull);
      expect(response!.plan, isNull);
      expect(response.missingFields, contains('profile'));
      expect(response.pendingRequest!.workflow, AiWorkflow.loginFullSequence);
    });

    test(
      'natural language without a configured provider never executes a plan',
      () async {
        final response = await AiOrchestrator(
          profiles: profiles,
          provider: null,
        ).respond(input: 'run anything you want', history: <AiChatMessage>[]);

        expect(response.state, AiPlanState.needsInput);
        expect(response.plan, isNull);
        expect(response.message, contains('Configure'));
      },
    );

    test('multi-word profile spans normalize and match correctly', () {
      final parser = SlashCommandParser();

      final r1 = parser.findProfileInInput(
        'can you run /login in kpn staging',
        profiles,
      );
      expect(r1, isNotNull);
      expect(r1!.id, 'kpn-stage');

      final r2 = parser.findProfileInInput('KPN STAGE', profiles);
      expect(r2, isNotNull);
      expect(r2!.id, 'kpn-stage');

      final r3 = parser.findProfileInInput('kpn_stage', profiles);
      expect(r3, isNotNull);
      expect(r3!.id, 'kpn-stage');
    });

    test(
      'structured pending request resolves multi-turn profile follow-up deterministically',
      () async {
        final orchestrator = AiOrchestrator(profiles: profiles, provider: null);

        // Turn 1: User says /login without a profile
        final turn1Response = await orchestrator.respond(
          input: '/login',
          history: <AiChatMessage>[],
        );
        expect(turn1Response.state, AiPlanState.needsInput);
        expect(turn1Response.missingFields, contains('profile'));
        expect(turn1Response.pendingRequest, isNotNull);
        expect(
          turn1Response.pendingRequest!.workflow,
          AiWorkflow.loginFullSequence,
        );

        // Turn 2: User responds with "kpn staging" (no / token)
        final history = <AiChatMessage>[
          AiChatMessage(role: AiChatRole.user, text: '/login'),
          AiChatMessage(
            role: AiChatRole.assistant,
            text: turn1Response.message,
            pendingRequest: turn1Response.pendingRequest,
          ),
        ];

        final turn2Response = await orchestrator.respond(
          input: 'kpn staging',
          history: history,
        );

        expect(turn2Response.state, AiPlanState.readyForConfirmation);
        expect(turn2Response.canExecute, isTrue);
        expect(turn2Response.plan, isNotNull);
        expect(turn2Response.plan!.profileId, 'kpn-stage');
        expect(turn2Response.plan!.workflow, AiWorkflow.loginFullSequence);
      },
    );
  });
}
