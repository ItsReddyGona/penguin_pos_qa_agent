import 'package:penguin_pos_qa_agent/domain/plan/execution_plan.dart';
import 'package:penguin_pos_qa_agent/domain/suites/qa_suite_definition.dart';

/// Registry maintaining available test suite implementations in the QA Agent.
class QaSuiteRegistry {
  QaSuiteRegistry._();

  static final QaSuiteRegistry instance = QaSuiteRegistry._();

  final Map<QaSuiteId, QaSuiteDefinition> _registry = {};

  /// Registers a new suite definition into the system.
  void register(QaSuiteDefinition suite) {
    _registry[suite.id] = suite;
  }

  /// Retrieves a suite by its identifier.
  QaSuiteDefinition? get(QaSuiteId id) => _registry[id];

  /// Returns an unmodifiable list of all registered suites.
  List<QaSuiteDefinition> getAll() => List.unmodifiable(_registry.values);

  /// Clears and resets the registry (useful for unit testing).
  void reset() {
    _registry.clear();
  }
}
