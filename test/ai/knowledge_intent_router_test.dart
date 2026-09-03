import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/ai/orchestration/knowledge_intent_router.dart';

void main() {
  const router = KnowledgeIntentRouter();

  group('KnowledgeIntentRouter precedence', () {
    test('keeps explicit execution out of the knowledge route', () {
      expect(
        router.classify('Run login in KPN Stage').intent,
        KnowledgeIntent.explicitExecution,
      );
      expect(
        router.classify('/login').intent,
        KnowledgeIntent.explicitExecution,
      );
      expect(
        router.classify('test /login flow for kpn dev').intent,
        KnowledgeIntent.explicitExecution,
      );
    });

    test('keeps runnable coverage questions read-only', () {
      expect(
        router.classify('What can I run in KPN Stage?').intent,
        KnowledgeIntent.runnableSuites,
      );
    });

    test('prefers profile listing without a suite reference', () {
      expect(
        router.classify('Show configured environments').intent,
        KnowledgeIntent.profiles,
      );
    });

    test('routes a feature-specific help request to flow explanation', () {
      expect(
        router.classify('Help with login').intent,
        KnowledgeIntent.explainFlow,
      );
    });

    test('retains prior-answer references for scoped follow-ups', () {
      final query = router.classify('Explain the above with a flow chart');
      expect(query.intent, KnowledgeIntent.explainFlow);
      expect(query.referencesPreviousAnswer, isTrue);
    });
  });
}
