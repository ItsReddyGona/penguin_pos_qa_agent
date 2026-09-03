/// The non-executable intent carried by a user message before plan parsing.
///
/// This deliberately stays small and deterministic. It makes the precedence
/// between catalogue questions and run requests explicit without asking a
/// model to decide whether it is safe to prepare a plan.
enum KnowledgeIntent {
  none,
  explicitExecution,
  profiles,
  help,
  runnableSuites,
  testCases,
  explainFlow,
}

/// Typed result of classifying a message for the local QA knowledge catalogue.
class KnowledgeQuery {
  const KnowledgeQuery({
    required this.intent,
    required this.referencesKnownFeature,
    required this.referencesPreviousAnswer,
  });

  final KnowledgeIntent intent;
  final bool referencesKnownFeature;
  final bool referencesPreviousAnswer;

  bool get isKnowledgeQuestion => switch (intent) {
    KnowledgeIntent.profiles ||
    KnowledgeIntent.help ||
    KnowledgeIntent.runnableSuites ||
    KnowledgeIntent.testCases ||
    KnowledgeIntent.explainFlow => true,
    KnowledgeIntent.none || KnowledgeIntent.explicitExecution => false,
  };
}

/// Classifies only stable, read-only questions. Execution parsing remains in
/// [AiOrchestrator], but is identified here first so a request such as
/// "run login" can never be mistaken for a knowledge answer.
class KnowledgeIntentRouter {
  const KnowledgeIntentRouter();

  KnowledgeQuery classify(String input) {
    final normalized = input.trim().toLowerCase();
    final referencesKnownFeature = RegExp(
      r'/(login|orders?|tests?)\b|\b(login|terminal|order|checkout|cash|payment|sku|weighed)\b',
    ).hasMatch(normalized);
    final referencesPreviousAnswer = RegExp(
      r'\b(above|previous|prior|that|this|same|it)\b',
    ).hasMatch(normalized);

    if (normalized.isEmpty) {
      return KnowledgeQuery(
        intent: KnowledgeIntent.none,
        referencesKnownFeature: referencesKnownFeature,
        referencesPreviousAnswer: referencesPreviousAnswer,
      );
    }
    if (_isExplicitExecutionRequest(normalized)) {
      return KnowledgeQuery(
        intent: KnowledgeIntent.explicitExecution,
        referencesKnownFeature: referencesKnownFeature,
        referencesPreviousAnswer: referencesPreviousAnswer,
      );
    }

    final asksForProfiles = RegExp(
      r'\b(profile|profiles|environment|environments|target|targets)\b',
    ).hasMatch(normalized);
    final asksForHelp = RegExp(
      r'(^|\b)(help|supported|capabilities|what can i (run|test))\b',
    ).hasMatch(normalized);
    final asksForCases = RegExp(
      r'\b(test cases?|scenarios?|tests? (exist|available|are there))\b',
    ).hasMatch(normalized);
    final asksForRunnable = RegExp(
      r'\b(runnable|available to run|can i run|i can run|can run|what can i (run|test))\b',
    ).hasMatch(normalized);
    final asksForExplanation = RegExp(
      r'\b(explain|describe|what is|what does|how does|flow|journey)\b',
    ).hasMatch(normalized);

    final intent = switch ((
      asksForProfiles,
      asksForHelp,
      asksForCases,
      asksForRunnable,
      asksForExplanation,
      referencesKnownFeature,
    )) {
      (true, _, _, _, _, false) => KnowledgeIntent.profiles,
      (_, _, _, true, _, _) => KnowledgeIntent.runnableSuites,
      (_, _, true, _, _, _) => KnowledgeIntent.testCases,
      (_, true, _, _, _, false) => KnowledgeIntent.help,
      (_, true, _, _, _, true) ||
      (_, _, _, _, true, _) => KnowledgeIntent.explainFlow,
      _ => KnowledgeIntent.none,
    };
    return KnowledgeQuery(
      intent: intent,
      referencesKnownFeature: referencesKnownFeature,
      referencesPreviousAnswer: referencesPreviousAnswer,
    );
  }

  bool _isExplicitExecutionRequest(String input) {
    if (input.trim().startsWith('/')) return true;
    // Read-only forms such as "what can I run" remain catalogue queries.
    if (RegExp(r'\b(what|which) can i (run|test)\b').hasMatch(input)) {
      return false;
    }
    return RegExp(
      r'(^|\b)(go ahead(?: and)?|please|can you|run|execute|start|launch|test|verify|check|punch|place)\s+(?:the\s+)?(?:tests?\s+)?(?:\d+\s+)?(?:/)?(login|orders?|checkout|cash|payment)',
    ).hasMatch(input);
  }
}
