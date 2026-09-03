import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';

/// Contract for atomic, reusable UI test automation blocks.
abstract class AutomationBlock {
  /// Unique key for diagnostics & tracking
  String get id;

  /// Human-readable step title emitted during execution
  String get name;

  /// Optional notice content displayed on target app overlay during execution.
  StepNotice? get notice => null;

  /// Executes the block's atomic automation actions against [context.driver].
  Future<void> execute(ExecutionContext context);
}
