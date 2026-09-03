import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';

/// Fast local shortcuts. These never invoke the model and never execute a test.
class SlashCommandParser {
  AiAssistantResponse? parse(
    String input,
    List<QaProfile> profiles, {
    AiWorkflow? pendingWorkflow,
    List<String>? pendingMissingFields,
    int pendingOrdersCount = 1,
  }) {
    final rawTokens = input
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();

    final hasSlashToken = rawTokens.any((token) => token.startsWith('/'));

    // Slot-filling continuation for pending structured requests (e.g. missing profile)
    if (!hasSlashToken &&
        pendingWorkflow != null &&
        pendingMissingFields != null &&
        pendingMissingFields.contains('profile')) {
      final matchedProfile = findProfileInInput(input, profiles);
      if (matchedProfile != null) {
        return _buildResponseForWorkflowAndProfile(
          pendingWorkflow,
          matchedProfile,
          ordersCount: pendingWorkflow == AiWorkflow.loginFullSequence
              ? pendingOrdersCount
              : 1,
        );
      }
    }

    if (rawTokens.isEmpty || !hasSlashToken) {
      return null;
    }

    final profile = findProfileInInput(input, profiles);
    AiWorkflow? workflow;
    var ordersCount = 1;
    // Login repetitions use the same explicit count syntax as order commands:
    // `/login in kpn dev back to back 2 times`. Keep this local so an
    // unambiguous slash command does not need a model round-trip.
    var loginRepeatCount = _repeatCountIn(input.toLowerCase());

    for (var index = 0; index < rawTokens.length; index++) {
      final token = rawTokens[index].replaceFirst('/', '');
      if (token == 'login') workflow = AiWorkflow.loginFullSequence;
      if (token == 'order') {
        workflow = AiWorkflow.orderCashPayment;
        if (index + 1 < rawTokens.length) {
          final countFromToken = int.tryParse(
            rawTokens[index + 1],
          )?.clamp(1, 50);
          if (countFromToken != null) {
            ordersCount = countFromToken;
          }
        }
      }
    }

    if (workflow == AiWorkflow.orderCashPayment && loginRepeatCount > 1) {
      ordersCount = loginRepeatCount;
    }

    // A bare `/login` remains one run; only an explicit repetition marker
    // should increase the count.
    if (!RegExp(
      r'\b(?:repeat|back\s+to\s+back|run|test)?\s*\d+\s*(?:times?|x|iterations?|reps?)\b',
      caseSensitive: false,
    ).hasMatch(input)) {
      loginRepeatCount = 1;
    }

    if (workflow == null) {
      return const AiAssistantResponse(
        state: AiPlanState.needsInput,
        message: 'Choose a workflow: `/login` or `/order`.',
        missingFields: <String>['workflow'],
      );
    }

    if (profile == null) {
      return AiAssistantResponse(
        state: AiPlanState.needsInput,
        plan: null,
        message:
            'Choose an approved target profile, for example `${profiles.isEmpty ? 'kpn-stage' : profiles.first.id}`.',
        missingFields: const <String>['profile'],
        pendingRequest: AiPendingRequest(
          workflow: workflow,
          missingFields: const <String>['profile'],
          ordersCount: ordersCount,
        ),
      );
    }

    return _buildResponseForWorkflowAndProfile(
      workflow,
      profile,
      ordersCount: workflow == AiWorkflow.loginFullSequence
          ? loginRepeatCount
          : ordersCount,
    );
  }

  /// Handles unambiguous login and order requests without sending them to a model.
  ///
  /// Phrases such as "test login in kpn dev" or "punch 3 orders in kpn dev"
  /// have deterministic behaviour and use saved Settings inputs.
  AiAssistantResponse? parseNaturalWorkflow(
    String input,
    List<QaProfile> profiles,
  ) {
    final normalized = input.trim().toLowerCase();
    if (normalized.isEmpty ||
        RegExp(
          r'\b(explain|what|how|why|meaning|define)\b',
        ).hasMatch(normalized)) {
      return null;
    }

    // 1. Natural Login
    if (RegExp(r'\b(login|log\s+in|sign\s+in)\b').hasMatch(normalized)) {
      final profile = findProfileInInput(input, profiles);
      if (profile == null) {
        return AiAssistantResponse(
          state: AiPlanState.needsInput,
          message:
              'Choose an approved target profile, for example `${profiles.isEmpty ? 'kpn-stage' : profiles.first.id}`.',
          missingFields: const <String>['profile'],
          pendingRequest: const AiPendingRequest(
            workflow: AiWorkflow.loginFullSequence,
            missingFields: <String>['profile'],
          ),
        );
      }

      return _buildResponseForWorkflowAndProfile(
        AiWorkflow.loginFullSequence,
        profile,
        ordersCount: _repeatCountIn(normalized),
      );
    }

    // 2. Natural Orders (e.g. "punch 3 orders in kpn dev", "run order in kpn dev", "place 5 orders")
    // When no specific SKU codes, custom items, or repeat requests are named in the prompt, uses saved Settings inputs.
    if (RegExp(
      r'\b(orders?|punch|checkout|place\s+orders?)\b',
    ).hasMatch(normalized)) {
      final hasCustomOrRepeat = RegExp(
        r'\b(sku|skus|item|items|\d+w\d+|\bcode\b|bizerba|weighed|repeat|previous|last|same|with\s+\d+)\b',
        caseSensitive: false,
      ).hasMatch(input);
      if (!hasCustomOrRepeat) {
        final profile = findProfileInInput(input, profiles);
        final countMatch = RegExp(
          r'\b(?:punch|run|place|test|execute|order|orders)?\s*(\d+)\s*(?:orders?|iterations?|times?|x|back\s+to\s+back)?\b',
          caseSensitive: false,
        ).firstMatch(normalized);
        final ordersCount = (int.tryParse(countMatch?.group(1) ?? '') ?? 1)
            .clamp(1, 50);

        if (profile == null) {
          return AiAssistantResponse(
            state: AiPlanState.needsInput,
            message:
                'Choose an approved target profile, for example `${profiles.isEmpty ? 'kpn-stage' : profiles.first.id}`.',
            missingFields: const <String>['profile'],
            pendingRequest: AiPendingRequest(
              workflow: AiWorkflow.orderCashPayment,
              missingFields: const <String>['profile'],
              ordersCount: ordersCount,
            ),
          );
        }

        return _buildResponseForWorkflowAndProfile(
          AiWorkflow.orderCashPayment,
          profile,
          ordersCount: ordersCount,
        );
      }
    }

    return null;
  }

  int _repeatCountIn(String input) {
    final match = RegExp(
      r'\b(?:repeat|back\s+to\s+back|run|test)?\s*(\d+)\s*(?:times?|x|iterations?|reps?|orders?)\b',
      caseSensitive: false,
    ).firstMatch(input);
    return ((int.tryParse(match?.group(1) ?? '') ?? 1).clamp(1, 50));
  }

  AiAssistantResponse _buildResponseForWorkflowAndProfile(
    AiWorkflow workflow,
    QaProfile profile, {
    int ordersCount = 1,
  }) {
    final plan = AiTestPlan(
      workflow: workflow,
      profileId: profile.id,
      repeatCount: workflow == AiWorkflow.loginFullSequence ? ordersCount : 1,
      ordersCount: ordersCount,
      executionSteps: workflow == AiWorkflow.loginFullSequence
          ? const <String>[
              'Splash Screen APIs',
              'Check current login session',
              'Log out if an existing session is detected',
              'Run enabled Login test cases from Settings in saved order',
              'Select terminal and verify home screen',
              'Log out and restore a clean session',
            ]
          : const <String>[],
      inputSource: AiInputSource.settings,
    );

    if (workflow == AiWorkflow.loginFullSequence) {
      return AiAssistantResponse(
        state: AiPlanState.readyForConfirmation,
        plan: plan,
        message:
            'Login flow selected for ${profile.label}. Review the plan to proceed with preflight checks.',
        richContent: AiRichPlanSummary(
          profileLabel: profile.label,
          workflowLabel: 'Login & Terminal Setup',
          dataSourceLabel: 'Settings → Inputs & Credentials → Login',
          scenarios: const <AiScenarioRow>[
            AiScenarioRow(name: 'Login Validation'),
            AiScenarioRow(name: 'Auth Failure Handling'),
            AiScenarioRow(name: 'Valid Login Flow'),
          ],
        ),
      );
    }

    return AiAssistantResponse(
      state: AiPlanState.readyForConfirmation,
      plan: plan,
      message:
          'Order flow selected for ${profile.label}. Review the plan to run the saved Order Inputs configuration.',
      richContent: AiRichPlanSummary(
        profileLabel: profile.label,
        workflowLabel:
            'Order & Cash Payment ($ordersCount ${ordersCount == 1 ? 'Order' : 'Orders'})',
        dataSourceLabel: 'Settings → Inputs & Credentials → Order Inputs',
        scenarios: const <AiScenarioRow>[
          AiScenarioRow(name: 'Login Check'),
          AiScenarioRow(name: 'Customer and Cart Operations'),
          AiScenarioRow(name: 'Cash Payment and Order Success'),
        ],
      ),
    );
  }

  /// Finds a profile matching 2-word spans, 1-word spans, or full input normalization.
  QaProfile? findProfileInInput(String input, List<QaProfile> profiles) {
    if (input.trim().isEmpty || profiles.isEmpty) return null;

    final tokens = input
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll('/', ''))
        .where((t) => t.isNotEmpty)
        .toList();

    // 1. Check 2-word spans (longer match takes priority)
    for (var i = 0; i < tokens.length - 1; i++) {
      final span = '${tokens[i]} ${tokens[i + 1]}';
      final normalizedSpan = _normalize(span);
      for (final profile in profiles) {
        if (_matchesProfile(normalizedSpan, profile)) {
          return profile;
        }
      }
    }

    // 2. Check 1-word spans
    for (final token in tokens) {
      final normalizedToken = _normalize(token);
      for (final profile in profiles) {
        if (_matchesProfile(normalizedToken, profile)) {
          return profile;
        }
      }
    }

    // 3. Check full normalized input
    final fullNormalized = _normalize(input);
    for (final profile in profiles) {
      if (_matchesProfile(fullNormalized, profile)) {
        return profile;
      }
    }

    return null;
  }

  bool _matchesProfile(String normalizedInput, QaProfile profile) {
    if (normalizedInput.isEmpty) return false;
    final candidates = <String>[
      profile.id,
      profile.label,
      '${profile.entity} ${profile.environment}',
      '${profile.entity}${profile.environment}',
      ...profile.aliases,
    ];

    if (candidates.any((c) => _normalize(c) == normalizedInput)) {
      return true;
    }

    // Entity + environment stem matching (e.g. "kpn staging" matching "kpn-stage")
    final normEntity = _normalize(profile.entity);
    final normEnv = _normalize(profile.environment);
    final envStem = normEnv.length >= 4 ? normEnv.substring(0, 4) : normEnv;

    if (normEntity.isNotEmpty &&
        envStem.isNotEmpty &&
        normalizedInput.contains(normEntity) &&
        normalizedInput.contains(envStem)) {
      return true;
    }

    return false;
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
