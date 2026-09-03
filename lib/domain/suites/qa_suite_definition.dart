import 'package:penguin_pos_qa_agent/application/execution/qa_execution_coordinator.dart';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/domain/plan/execution_plan.dart';

/// Contract defining a polymorphic POS test suite.
///
/// Enables new test suites (e.g. Inventory, Discounts, Table Service, Refunds)
/// to be registered without modifying UI screens or core execution coordinators.
abstract class QaSuiteDefinition {
  const QaSuiteDefinition();

  QaSuiteId get id;
  String get title;
  String get description;
  bool get isImplemented;

  /// Runs the test suite through the connected [driver] with the given [plan].
  Future<ExecutionPlanResult> execute({
    required Driver driver,
    required Uri vmServiceUri,
    required PreparedExecution execution,
    ExecutionCallbacks callbacks = const ExecutionCallbacks(),
  });
}
