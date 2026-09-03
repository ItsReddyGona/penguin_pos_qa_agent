import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/test_suite_model.dart';

/// Read-only knowledge view over the QA suites that are actually available in
/// the application. It lets the assistant answer questions without inventing
/// test coverage or preparing an execution plan.
class QaKnowledgeCatalogue {
  QaKnowledgeCatalogue.fromSuites(Iterable<TestSuiteItem> suites)
    : suites = List<QaKnowledgeSuite>.unmodifiable(
        suites.map(QaKnowledgeSuite.fromTestSuite),
      );

  /// The catalogue backed by the sidebar's canonical suite definitions.
  static final QaKnowledgeCatalogue defaultCatalogue =
      QaKnowledgeCatalogue.fromSuites(TestSuiteItem.availableSuites);

  final List<QaKnowledgeSuite> suites;

  /// Feature names available to the assistant, in the same order as the UI.
  List<String> get supportedFeatureLabels =>
      List<String>.unmodifiable(suites.map((suite) => suite.featureLabel));

  /// A concise, source-backed answer for a generic help request.
  String get helpText {
    if (suites.isEmpty) return 'No QA test suites are currently available.';
    return 'Supported QA features: ${supportedFeatureLabels.join(', ')}. '
        'Use /login or /order to run the configured suite, or ask what a '
        'flow verifies, which test cases exist, or request a safe flow chart. '
        'Execution uses the saved Settings inputs for the selected profile.';
  }

  QaKnowledgeSuite? findSuiteById(String suiteId) {
    final normalizedId = _normalize(suiteId);
    for (final suite in suites) {
      if (_normalize(suite.id) == normalizedId) return suite;
    }
    return null;
  }

  /// Returns suites relevant to natural-language [query].
  ///
  /// A generic request that contains no known feature words returns all suites
  /// so callers can safely answer questions such as "what can I run?". The
  /// underlying suite data remains the source of every returned result.
  List<QaKnowledgeSuite> findSuitesForQuery(String query) {
    final matches = findExplicitSuitesForQuery(query);
    return matches.isEmpty ? suites : matches;
  }

  /// Returns only suites named by [query].
  ///
  /// This intentionally differs from [findSuitesForQuery]: callers handling a
  /// follow-up such as "show the above flow" need to know that no feature was
  /// named, rather than silently broadening the answer to every suite.
  List<QaKnowledgeSuite> findExplicitSuitesForQuery(String query) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) return const <QaKnowledgeSuite>[];

    final matches = <_ScoredSuite>[];
    for (final suite in suites) {
      final score = suite._matchScore(normalizedQuery);
      if (score > 0) matches.add(_ScoredSuite(suite, score));
    }
    if (matches.isEmpty) return const <QaKnowledgeSuite>[];

    matches.sort((left, right) => right.score.compareTo(left.score));
    return List<QaKnowledgeSuite>.unmodifiable(
      matches.map((match) => match.suite),
    );
  }

  /// Finds the known suite for an execution workflow name without importing
  /// planner types. This accepts both enum-name style and conversational names.
  List<QaKnowledgeSuite> findSuitesForWorkflowName(String workflowName) {
    final normalizedWorkflow = _normalize(workflowName);
    switch (normalizedWorkflow) {
      case 'loginfullsequence':
      case 'login':
      case 'loginterminal':
        return _suitesWithId('login_terminal');
      case 'ordercashpayment':
      case 'order':
      case 'checkout':
      case 'cashpayment':
        return _suitesWithId('order_checkout');
      default:
        return findSuitesForQuery(workflowName);
    }
  }

  List<QaKnowledgeSuite> _suitesWithId(String id) {
    final suite = findSuiteById(id);
    return suite == null
        ? const <QaKnowledgeSuite>[]
        : List<QaKnowledgeSuite>.unmodifiable(<QaKnowledgeSuite>[suite]);
  }
}

/// A suite safe to surface in assistant answers. It is a projection of
/// [TestSuiteItem], not a second catalogue, so suite titles, scenarios, tags,
/// and runnable status cannot drift from the selectable dashboard suite.
class QaKnowledgeSuite {
  QaKnowledgeSuite.fromTestSuite(TestSuiteItem source)
    : id = source.id,
      title = source.title,
      featureLabel = source.feature.isEmpty ? source.title : source.feature,
      description = source.description,
      purpose = source.purpose.isEmpty ? source.description : source.purpose,
      isRunnable = source.isImplemented,
      environmentPolicy = source.environmentPolicy,
      searchAliases = List<String>.unmodifiable(source.searchAliases),
      scenarios = List<QaKnowledgeScenario>.unmodifiable(
        source.scenarios.map(
          (scenario) => QaKnowledgeScenario.fromTestSuiteScenario(
            suiteId: source.id,
            suiteTitle: source.title,
            featureLabel: source.feature.isEmpty
                ? source.title
                : source.feature,
            isRunnable: source.isImplemented,
            environmentPolicy: source.environmentPolicy,
            source: scenario,
          ),
        ),
      );

  final String id;
  final String title;
  final String featureLabel;
  final String description;
  final String purpose;
  final bool isRunnable;
  final QaEnvironmentPolicy environmentPolicy;
  final List<String> searchAliases;
  final List<QaKnowledgeScenario> scenarios;

  List<String> get scenarioNames =>
      List<String>.unmodifiable(scenarios.map((scenario) => scenario.name));

  int _matchScore(String normalizedQuery) {
    final terms = <String>[
      id,
      title,
      featureLabel,
      ...searchAliases,
      for (final scenario in scenarios) ...scenario._featureSearchTerms,
    ].map(_normalize).where((term) => term.isNotEmpty).toList();

    var score = 0;
    for (final term in terms) {
      if (normalizedQuery.contains(term)) {
        score += term.contains(' ') ? 8 : 5;
      }
      for (final word in term.split(' ')) {
        if (word.length >= 3 &&
            !_genericQueryWords.contains(word) &&
            normalizedQuery.split(' ').contains(word)) {
          score += 1;
        }
      }
    }
    return score;
  }
}

/// Scenario-level knowledge, including prerequisites and expected outcomes
/// suitable for a read-only conversational answer.
class QaKnowledgeScenario {
  QaKnowledgeScenario.fromTestSuiteScenario({
    required this.suiteId,
    required this.suiteTitle,
    required this.featureLabel,
    required this.isRunnable,
    required this.environmentPolicy,
    required TestSuiteScenario source,
  }) : id = source.id,
       name = source.name,
       purpose = source.purpose.isEmpty ? source.name : source.purpose,
       tags = List<String>.unmodifiable(source.tags),
       steps = List<String>.unmodifiable(source.stepsDescription),
       preconditions = List<String>.unmodifiable(source.preconditions),
       expectedOutcomes = List<String>.unmodifiable(source.expectedOutcomes),
       requirements = List<QaTestRequirement>.unmodifiable(source.requirements),
       searchAliases = List<String>.unmodifiable(source.searchAliases);

  final String suiteId;
  final String suiteTitle;
  final String featureLabel;
  final bool isRunnable;
  final QaEnvironmentPolicy environmentPolicy;
  final String id;
  final String name;
  final String purpose;
  final List<String> tags;
  final List<String> steps;
  final List<String> preconditions;
  final List<String> expectedOutcomes;
  final List<QaTestRequirement> requirements;
  final List<String> searchAliases;

  List<String> get requirementLabels => List<String>.unmodifiable(
    requirements.map((requirement) => requirement.userLabel),
  );

  /// Terms that identify the tested feature, excluding generic description
  /// language such as "flow". This prevents a follow-up like "the above
  /// flow" from matching every suite before chat context can resolve it.
  List<String> get _featureSearchTerms => <String>[
    id,
    name,
    ...tags,
    ...searchAliases,
  ];
}

const _genericQueryWords = <String>{
  'flow',
  'test',
  'tests',
  'case',
  'cases',
  'scenario',
  'scenarios',
  'available',
  'explain',
  'chart',
  'diagram',
};

extension QaTestRequirementLabel on QaTestRequirement {
  String get userLabel => switch (this) {
    QaTestRequirement.approvedNonProductionProfile =>
      'an approved non-production QA profile',
    QaTestRequirement.savedLoginCredentials => 'saved QA login credentials',
    QaTestRequirement.authenticatedSession => 'an authenticated QA session',
    QaTestRequirement.configuredTestItems => 'valid test items for the profile',
  };
}

class _ScoredSuite {
  const _ScoredSuite(this.suite, this.score);

  final QaKnowledgeSuite suite;
  final int score;
}

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');
