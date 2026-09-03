import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/ai/models/qa_knowledge_catalogue.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/test_suite_model.dart';

void main() {
  final catalogue = QaKnowledgeCatalogue.defaultCatalogue;

  group('QaKnowledgeCatalogue', () {
    test('projects the canonical selectable suites', () {
      expect(catalogue.suites, hasLength(TestSuiteItem.availableSuites.length));
      expect(
        catalogue.suites.map((suite) => suite.id),
        TestSuiteItem.availableSuites.map((suite) => suite.id),
      );
      expect(catalogue.supportedFeatureLabels, <String>[
        'Login & Terminal',
        'Order & Cash Payment',
      ]);
    });

    test('includes purpose, preconditions, outcomes, and requirements', () {
      final login = catalogue.findSuiteById('login_terminal')!;
      final validLogin = login.scenarios.singleWhere(
        (scenario) => scenario.id == 'valid_login',
      );

      expect(login.isRunnable, isTrue);
      expect(login.purpose, isNotEmpty);
      expect(validLogin.preconditions, isNotEmpty);
      expect(validLogin.expectedOutcomes, isNotEmpty);
      expect(
        validLogin.requirementLabels,
        contains('saved QA login credentials'),
      );
    });

    test('matches inline command and natural language feature terms', () {
      expect(
        catalogue.findSuitesForQuery('Explain /login').single.id,
        'login_terminal',
      );
      expect(
        catalogue.findSuitesForQuery('How does cash round-off work?').single.id,
        'order_checkout',
      );
      expect(
        catalogue.findSuitesForWorkflowName('orderCashPayment').single.id,
        'order_checkout',
      );
    });

    test('returns all suites when no feature term is supplied', () {
      expect(
        catalogue.findSuitesForQuery('').map((suite) => suite.id),
        catalogue.suites.map((suite) => suite.id),
      );
    });

    test('distinguishes no explicit match from a broad catalogue query', () {
      expect(
        catalogue.findExplicitSuitesForQuery('show the above flow chart'),
        isEmpty,
      );
      expect(
        catalogue.findSuitesForQuery('show the above flow chart'),
        isNotEmpty,
      );
    });
  });
}
