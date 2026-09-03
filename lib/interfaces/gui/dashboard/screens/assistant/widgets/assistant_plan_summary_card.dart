import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_ui_tokens.dart';

/// Read-only overview of a generated test plan and its scenarios.
class AssistantPlanSummaryCard extends StatelessWidget {
  const AssistantPlanSummaryCard({
    super.key,
    required this.summary,
    this.onRunValidatedPlan,
    this.onOpenInManualMode,
  });

  final AiRichPlanSummary summary;
  final VoidCallback? onRunValidatedPlan;
  final VoidCallback? onOpenInManualMode;

  @override
  Widget build(BuildContext context) {
    return _PlanCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const _PlanHeader(),
          const Divider(height: 1, color: AssistantUiTokens.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _PlanMetadata(summary: summary),
          ),
          if (summary.orderItems.isNotEmpty) ...<Widget>[
            const Divider(height: 1, color: AssistantUiTokens.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: _OrderItemsTable(items: summary.orderItems),
            ),
          ],
          if (summary.scenarios.isNotEmpty) ...<Widget>[
            const Divider(height: 1, color: AssistantUiTokens.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: _PlanScenarioTable(scenarios: summary.scenarios),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderItemsTable extends StatelessWidget {
  const _OrderItemsTable({required this.items});

  final List<AiOrderItemRow> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text(
            'ORDER ITEMS CONFIGURATION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AssistantUiTokens.mutedText,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Table(
          columnWidths: const <int, TableColumnWidth>{
            0: FixedColumnWidth(28),
            1: FlexColumnWidth(1.2),
            2: FlexColumnWidth(1.0),
            3: FlexColumnWidth(1.2),
            4: FlexColumnWidth(1.1),
          },
          children: <TableRow>[
            const TableRow(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AssistantUiTokens.divider),
                ),
              ),
              children: <Widget>[
                _PlanTableHeader('#'),
                _PlanTableHeader('SKU Code'),
                _PlanTableHeader('Type'),
                _PlanTableHeader('Entry Mode'),
                _PlanTableHeader('Allocation'),
              ],
            ),
            for (var index = 0; index < items.length; index++)
              TableRow(
                decoration: index < items.length - 1
                    ? const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFF0EEEA)),
                        ),
                      )
                    : null,
                children: <Widget>[
                  _PlanTableCell('${index + 1}'),
                  _PlanTableCell(items[index].skuCode, isMonospace: true),
                  _PlanTableCell(items[index].typeLabel),
                  _PlanTableCell(items[index].entryModeLabel),
                  _PlanTableCell(items[index].allocationLabel),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _PlanCardShell extends StatelessWidget {
  const _PlanCardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AssistantUiTokens.surface,
        borderRadius: AssistantUiTokens.cardRadius,
        border: Border.all(color: AssistantUiTokens.subtleBorder),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PlanHeader extends StatelessWidget {
  const _PlanHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: const BoxDecoration(
        color: AssistantUiTokens.subtleSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.playlist_add_check_rounded,
              size: 16,
              color: AssistantUiTokens.success,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Test Plan Ready',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AssistantUiTokens.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanMetadata extends StatelessWidget {
  const _PlanMetadata({required this.summary});

  final AiRichPlanSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _PlanMetadataRow(label: 'Profile', value: summary.profileLabel),
        const SizedBox(height: 6),
        _PlanMetadataRow(label: 'Workflow', value: summary.workflowLabel),
        const SizedBox(height: 6),
        if (summary.dataSourceLabel != null) ...<Widget>[
          _PlanMetadataRow(
            label: 'Data Source',
            value: summary.dataSourceLabel!,
          ),
          const SizedBox(height: 6),
        ],
        _PlanMetadataRow(
          label: 'Scenarios',
          value: '${summary.scenarios.length}',
        ),
      ],
    );
  }
}

class _PlanMetadataRow extends StatelessWidget {
  const _PlanMetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AssistantUiTokens.mutedText,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AssistantUiTokens.text,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanScenarioTable extends StatelessWidget {
  const _PlanScenarioTable({required this.scenarios});

  final List<AiScenarioRow> scenarios;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const <int, TableColumnWidth>{
        0: FixedColumnWidth(32),
        1: FlexColumnWidth(),
        2: FixedColumnWidth(72),
      },
      children: <TableRow>[
        const TableRow(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AssistantUiTokens.divider),
            ),
          ),
          children: <Widget>[
            _PlanTableHeader('#'),
            _PlanTableHeader('Scenario'),
            _PlanTableHeader('Status'),
          ],
        ),
        for (var index = 0; index < scenarios.length; index++)
          TableRow(
            decoration: index < scenarios.length - 1
                ? const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFF0EEEA)),
                    ),
                  )
                : null,
            children: <Widget>[
              _PlanTableCell('${index + 1}'),
              _PlanTableCell(scenarios[index].name),
              _PlanStatusBadge(status: scenarios[index].status),
            ],
          ),
      ],
    );
  }
}

class _PlanTableHeader extends StatelessWidget {
  const _PlanTableHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AssistantUiTokens.mutedText,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _PlanTableCell extends StatelessWidget {
  const _PlanTableCell(this.value, {this.isMonospace = false});

  final String value;
  final bool isMonospace;

  @override
  Widget build(BuildContext context) {
    if (isMonospace) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Text(
        value,
        style: const TextStyle(fontSize: 11.5, color: AssistantUiTokens.text),
      ),
    );
  }
}

class _PlanStatusBadge extends StatelessWidget {
  const _PlanStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isPending = status.toLowerCase() == 'pending';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isPending ? const Color(0xFFFFF8E1) : const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          status,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isPending
                ? const Color(0xFFE65100)
                : AssistantUiTokens.success,
          ),
        ),
      ),
    );
  }
}
