import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/ai/models/qa_gen_ui.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_gen_ui_message.dart';

/// Live execution progress tracker rendered using the declarative generative UI catalog.
class AssistantExecutionTracker extends StatelessWidget {
  const AssistantExecutionTracker({
    super.key,
    required this.steps,
    required this.suiteTitle,
    required this.profileLabel,
    required this.running,
  });

  final List<AiExecutionStep> steps;
  final String suiteTitle;
  final String profileLabel;
  final bool running;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    final latest = steps.last;

    // Deduplicate steps per scenario while preserving seeded order
    final scenarioMap = <String, AiExecutionStep>{};
    for (final step in steps) {
      scenarioMap[step.scenarioName] = step;
    }
    final scenarioList = scenarioMap.values.toList();

    final passedCount = scenarioList
        .where((s) => s.status == AiScenarioStatus.passed)
        .length;
    final failedCount = scenarioList
        .where((s) => s.status == AiScenarioStatus.failed)
        .length;
    final totalCount = latest.totalScenarios > 0
        ? latest.totalScenarios
        : scenarioList.length;
    final completedCount = passedCount + failedCount;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;
    final percent = (progress * 100).clamp(0, 100).toInt();

    final genUiSteps = scenarioList
        .map((step) {
          return QaGenUiStep(
            label: step.scenarioName,
            status: switch (step.status) {
              AiScenarioStatus.passed => QaGenUiStepStatus.passed,
              AiScenarioStatus.failed => QaGenUiStepStatus.failed,
              AiScenarioStatus.running => QaGenUiStepStatus.running,
              AiScenarioStatus.skipped => QaGenUiStepStatus.skipped,
              AiScenarioStatus.pending => QaGenUiStepStatus.pending,
            },
            durationMs: step.elapsedMs,
            detail:
                step.detail ??
                (step.status == AiScenarioStatus.running
                    ? 'Executing scenario…'
                    : null),
          );
        })
        .toList(growable: false);

    final component = QaGenUiComponent(
      type: QaGenUiComponentType.stepTimeline,
      title: running ? 'Running $suiteTitle' : '$suiteTitle Complete',
      profileLabel: profileLabel,
      workflowLabel: running
          ? '$completedCount of $totalCount scenarios ($percent%)'
          : (failedCount > 0
                ? '$passedCount of $totalCount passed ($failedCount failed)'
                : '$totalCount of $totalCount passed'),
      summary: !running
          ? '$passedCount of $totalCount test cases passed${failedCount > 0 ? ' ($failedCount failed)' : ''}'
          : null,
      passed: !running ? failedCount == 0 : null,
      steps: genUiSteps,
    );

    return AssistantGenUiMessage(
      document: QaGenUiDocument(components: <QaGenUiComponent>[component]),
    );
  }
}
