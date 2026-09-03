import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/qa_gen_ui.dart';

/// Renders the approved, declarative QA chat catalog with a clean, modern
/// developer-tool aesthetic inspired by Linear, Prefect, and Vercel.
class AssistantGenUiMessage extends StatelessWidget {
  const AssistantGenUiMessage({super.key, required this.document});

  final QaGenUiDocument document;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final component in document.components) ...<Widget>[
          _GenUiComponentCard(component: component),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _GenUiComponentCard extends StatelessWidget {
  const _GenUiComponentCard({required this.component});

  final QaGenUiComponent component;

  @override
  Widget build(BuildContext context) {
    final isFailure =
        component.type == QaGenUiComponentType.timeoutNotice ||
        component.passed == false;
    final borderColor = isFailure
        ? const Color(0xFFFECDD3)
        : const Color(0xFFE2E8F0);
    final cardBg = isFailure
        ? const Color(0xFFFFF7F7)
        : const Color(0xFFFFFFFF);

    final isRunning =
        component.passed == null &&
        (component.steps.any((s) => s.status == QaGenUiStepStatus.running) ||
            (component.workflowLabel?.contains('%') ?? false) ||
            component.title.startsWith('Running'));

    return Container(
      key: ValueKey<String>('qa_gen_ui_${component.type.name}'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isRunning
                      ? const Color(0xFFEFF6FF)
                      : _headerBadgeBg(component),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isRunning
                        ? const Color(0xFFBFDBFE)
                        : _headerBadgeBorder(component),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: isRunning
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF2563EB),
                            ),
                          ),
                        )
                      : Icon(
                          _headerIcon(component),
                          size: 16,
                          color: _headerIconColor(component),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      component.title,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (component.profileLabel != null ||
                        component.workflowLabel != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        <String>[
                          if (component.profileLabel != null)
                            component.profileLabel!,
                          if (component.workflowLabel != null)
                            component.workflowLabel!,
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_extractProgressPercent(component) != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isRunning
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isRunning
                          ? const Color(0xFFBFDBFE)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    '${_extractProgressPercent(component)}%',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isRunning
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFF334155),
                    ),
                  ),
                ),
            ],
          ),
          if (component.summary != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              component.summary!,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
            ),
            if (component.type == QaGenUiComponentType.resultSummary ||
                component.type == QaGenUiComponentType.stepTimeline)
              _buildResultSummaryChips(component.summary!),
          ],
          if (component.steps.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            _TimelineChain(steps: component.steps),
          ],
          if (component.apiEvents.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            for (final event in component.apiEvents)
              _ApiSequenceRow(event: event),
          ],
          if (component.type == QaGenUiComponentType.timeoutNotice &&
              component.timeoutResult != null) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFFE4E6)),
              ),
              child: Text(
                '${_resultLabel(component.timeoutResult!)}${component.timeoutBudgetMs == null ? '' : ' (${_elapsed(component.timeoutBudgetMs!)} budget)'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFBE123C),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  int? _extractProgressPercent(QaGenUiComponent component) {
    if (component.workflowLabel != null) {
      final match = RegExp(r'(\d+)%').firstMatch(component.workflowLabel!);
      if (match != null) {
        return int.tryParse(match.group(1) ?? '');
      }
    }
    return null;
  }

  Widget _buildResultSummaryChips(String summary) {
    final caseMatch = RegExp(
      r'(\d+)\s+of\s+(\d+)\s+test\s+cases\s+passed(?:\s*\(([0-9]+)\s+failed\))?',
      caseSensitive: false,
    ).firstMatch(summary);
    final orderMatch = RegExp(
      r'(\d+)\s+of\s+(\d+)\s+orders?\s+completed',
      caseSensitive: false,
    ).firstMatch(summary);

    if (caseMatch != null) {
      final passedCount = int.tryParse(caseMatch.group(1) ?? '') ?? 0;
      final totalCount = int.tryParse(caseMatch.group(2) ?? '') ?? 0;
      final failedCount =
          int.tryParse(caseMatch.group(3) ?? '') ?? (totalCount - passedCount);

      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: <Widget>[
            _summaryChip('Total: $totalCount', const Color(0xFF475569)),
            _summaryChip('Passed: $passedCount', const Color(0xFF059669)),
            if (failedCount > 0)
              _summaryChip('Failed: $failedCount', const Color(0xFFE11D48)),
          ],
        ),
      );
    }

    if (orderMatch != null) {
      final passedCount = int.tryParse(orderMatch.group(1) ?? '') ?? 0;
      final totalCount = int.tryParse(orderMatch.group(2) ?? '') ?? 0;
      final failedCount = totalCount - passedCount;

      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: <Widget>[
            _summaryChip('Total: $totalCount', const Color(0xFF475569)),
            _summaryChip('Passed: $passedCount', const Color(0xFF059669)),
            if (failedCount > 0)
              _summaryChip('Failed: $failedCount', const Color(0xFFE11D48)),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _summaryChip(String label, Color color) {
    final isSuccess = color == const Color(0xFF059669);
    final isDanger = color == const Color(0xFFE11D48);

    final bg = isSuccess
        ? const Color(0xFFECFDF5)
        : isDanger
        ? const Color(0xFFFEF2F2)
        : const Color(0xFFF1F5F9);
    final border = isSuccess
        ? const Color(0xFFA7F3D0)
        : isDanger
        ? const Color(0xFFFECDD3)
        : const Color(0xFFE2E8F0);
    final text = isSuccess
        ? const Color(0xFF065F46)
        : isDanger
        ? const Color(0xFF991B1B)
        : const Color(0xFF334155);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
  }

  IconData _headerIcon(QaGenUiComponent item) => switch (item.type) {
    QaGenUiComponentType.loginPlan => Icons.login_rounded,
    QaGenUiComponentType.orderPlan => Icons.receipt_long_rounded,
    QaGenUiComponentType.stepTimeline =>
      item.passed == true
          ? Icons.check_circle_rounded
          : (item.passed == false
                ? Icons.error_outline_rounded
                : Icons.play_arrow_rounded),
    QaGenUiComponentType.apiSequence => Icons.swap_horiz_rounded,
    QaGenUiComponentType.timeoutNotice => Icons.timer_off_outlined,
    QaGenUiComponentType.resultSummary =>
      item.passed == false ? Icons.cancel_rounded : Icons.check_circle_rounded,
  };

  Color _headerIconColor(QaGenUiComponent item) {
    if (item.passed == true) return const Color(0xFF059669);
    if (item.passed == false ||
        item.type == QaGenUiComponentType.timeoutNotice) {
      return const Color(0xFFE11D48);
    }
    return const Color(0xFF2563EB);
  }

  Color _headerBadgeBg(QaGenUiComponent item) {
    if (item.passed == true) return const Color(0xFFECFDF5);
    if (item.passed == false ||
        item.type == QaGenUiComponentType.timeoutNotice) {
      return const Color(0xFFFEF2F2);
    }
    return const Color(0xFFEFF6FF);
  }

  Color _headerBadgeBorder(QaGenUiComponent item) {
    if (item.passed == true) return const Color(0xFFA7F3D0);
    if (item.passed == false ||
        item.type == QaGenUiComponentType.timeoutNotice) {
      return const Color(0xFFFECDD3);
    }
    return const Color(0xFFBFDBFE);
  }
}

class _TimelineChain extends StatelessWidget {
  const _TimelineChain({required this.steps});

  final List<QaGenUiStep> steps;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 18,
            child: CustomPaint(painter: _TimelineConnectorPainter()),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (var i = 0; i < steps.length; i++)
                  _TimelineRow(step: steps[i], isLast: i == steps.length - 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step, this.isLast = false});

  final QaGenUiStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final idMatch = RegExp(r'^(.*?)\s*\(([^)]+)\)$').firstMatch(step.label);
    final isTestCase =
        idMatch != null &&
        !step.label.startsWith('Splash') &&
        !step.label.startsWith('Check If') &&
        !step.label.startsWith('Logout');
    final title = isTestCase ? idMatch.group(1)!.trim() : step.label;
    final caseId = isTestCase ? idMatch.group(2)!.trim() : null;
    final isFailed = step.status == QaGenUiStepStatus.failed;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildStatusIcon(step.status),
              ),
              if (caseId != null) ...<Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    caseId,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isTestCase ? FontWeight.w500 : FontWeight.w400,
                    color: const Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(step.status),
              if (step.durationMs != null && step.durationMs! >= 0) ...<Widget>[
                const SizedBox(width: 8),
                Text(
                  _elapsed(step.durationMs!),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
          if (step.detail != null) ...<Widget>[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: isFailed
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFFE4E6)),
                      ),
                      child: Text(
                        step.detail!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFBE123C),
                          height: 1.3,
                        ),
                      ),
                    )
                  : Text(
                      step.detail!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
            ),
          ],
          if (step.children.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 18, top: 6),
              child: Column(
                children: [
                  for (final child in step.children) _TimelineRow(step: child),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineConnectorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.5;
    for (double y = 8; y < size.height - 8; y += 6) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + 3),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ApiSequenceRow extends StatelessWidget {
  const _ApiSequenceRow({required this.event});

  final QaGenUiApiEvent event;

  @override
  Widget build(BuildContext context) {
    final success = event.result == QaGenUiApiResult.success;
    final expectedInvalidLogin =
        event.stepId == 'validate_invalid_credentials' &&
        event.statusCode == 401 &&
        event.endpoint.contains('/login');
    final statusColor = success
        ? const Color(0xFF059669)
        : expectedInvalidLogin
        ? const Color(0xFFD97706)
        : const Color(0xFFE11D48);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                success
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                size: 15,
                color: statusColor,
              ),
              const SizedBox(width: 8),
              Text(
                event.method,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.endpoint,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              Text(
                _elapsed(event.durationMs),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 23, top: 2),
            child: Text(
              '${event.transport.toUpperCase()} · ${_capitalize(event.mode)} · ${expectedInvalidLogin ? 'Expected 401' : event.statusCode ?? _resultLabel(event.result)}',
              style: TextStyle(fontSize: 10.5, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildStatusIcon(QaGenUiStepStatus status) {
  if (status == QaGenUiStepStatus.running) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
      ),
    );
  }
  if (status == QaGenUiStepStatus.passed) {
    return Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF10B981),
      ),
      child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
    );
  }
  if (status == QaGenUiStepStatus.failed) {
    return Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF43F5E),
      ),
      child: const Icon(Icons.close_rounded, size: 11, color: Colors.white),
    );
  }
  if (status == QaGenUiStepStatus.skipped) {
    return Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFE2E8F0),
      ),
      child: const Icon(
        Icons.remove_rounded,
        size: 11,
        color: Color(0xFF64748B),
      ),
    );
  }
  return Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFFF8FAFC),
      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
    ),
  );
}

Widget _buildStatusBadge(QaGenUiStepStatus status) {
  final (bg, border, text, label) = switch (status) {
    QaGenUiStepStatus.passed => (
      const Color(0xFFDCFCE7),
      const Color(0xFF86EFAC),
      const Color(0xFF15803D),
      'Passed',
    ),
    QaGenUiStepStatus.failed => (
      const Color(0xFFFEE2E2),
      const Color(0xFFFCA5A5),
      const Color(0xFFB91C1C),
      'Failed',
    ),
    QaGenUiStepStatus.running => (
      const Color(0xFFDBEAFE),
      const Color(0xFF93C5FD),
      const Color(0xFF1D4ED8),
      'Running',
    ),
    QaGenUiStepStatus.pending => (
      const Color(0xFFF1F5F9),
      const Color(0xFFE2E8F0),
      const Color(0xFF64748B),
      'Pending',
    ),
    QaGenUiStepStatus.skipped => (
      const Color(0xFFF1F5F9),
      const Color(0xFFE2E8F0),
      const Color(0xFF64748B),
      'Skipped',
    ),
  };

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: border),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: text,
      ),
    ),
  );
}

String _elapsed(int ms) =>
    ms < 1000 ? '${ms}ms' : '${(ms / 1000).toStringAsFixed(1)}s';

String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

String _resultLabel(QaGenUiApiResult result) => switch (result) {
  QaGenUiApiResult.success => 'Success',
  QaGenUiApiResult.httpError => 'HTTP error',
  QaGenUiApiResult.connectTimeout => 'Connection timed out',
  QaGenUiApiResult.sendTimeout => 'Request upload timed out',
  QaGenUiApiResult.receiveTimeout => 'Server response timed out',
  QaGenUiApiResult.connectionError => 'Connection failure',
  QaGenUiApiResult.cancelled => 'Request cancelled',
  QaGenUiApiResult.unexpectedError => 'Unexpected error',
};
