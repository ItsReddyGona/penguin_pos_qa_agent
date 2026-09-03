import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/login_test_case.dart';

/// A polished declarative Gen UI preview displayed after plan validation and before launch.
class AssistantLaunchPreviewCard extends StatelessWidget {
  const AssistantLaunchPreviewCard({super.key, required this.preview});

  final AiRichLaunchPreview preview;

  @override
  Widget build(BuildContext context) {
    final isOrderPreview = preview.orders.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: Icon(
                    isOrderPreview
                        ? Icons.receipt_long_rounded
                        : Icons.login_rounded,
                    size: 18,
                    color: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        isOrderPreview
                            ? 'Final order allocation'
                            : 'Login execution plan',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${preview.workflowLabel} · ${preview.profileLabel}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      if (isOrderPreview &&
                          (preview.dataSourceLabel != null ||
                              preview.allocationModeLabel != null)) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(
                          <String>[
                            if (preview.dataSourceLabel != null)
                              preview.dataSourceLabel!,
                            if (preview.allocationModeLabel != null)
                              preview.allocationModeLabel!,
                          ].join(' · '),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isOrderPreview) ...<Widget>[
                  _metaChip(
                    '${preview.orders.length} ${preview.orders.length == 1 ? 'order' : 'orders'}',
                    const Color(0xFF475569),
                    const Color(0xFFF1F5F9),
                  ),
                  const SizedBox(width: 8),
                  _metaChip(
                    '${preview.totalItems} ${preview.totalItems == 1 ? 'item' : 'items'}',
                    const Color(0xFF0284C7),
                    const Color(0xFFE0F2FE),
                  ),
                ] else if (preview.loginCases.isNotEmpty) ...<Widget>[
                  _metaChip(
                    '${preview.loginCases.length} Test Case${preview.loginCases.length == 1 ? '' : 's'}',
                    const Color(0xFF0284C7),
                    const Color(0xFFE0F2FE),
                  ),
                ] else ...<Widget>[
                  _metaChip(
                    'Login Sequence',
                    const Color(0xFF475569),
                    const Color(0xFFF1F5F9),
                  ),
                ],
              ],
            ),
          ),

          // Body Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (!isOrderPreview) ...<Widget>[
                  if (preview.loginCases.isNotEmpty)
                    _LoginCasesTable(cases: preview.loginCases)
                  else
                    _LoginStepsList(steps: preview.steps),
                ] else ...<Widget>[
                  for (
                    var index = 0;
                    index < preview.orders.length;
                    index++
                  ) ...<Widget>[
                    _OrderAllocationPanel(order: preview.orders[index]),
                    if (index < preview.orders.length - 1)
                      const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _metaChip(String label, Color textColor, Color bgColor) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      );
}

class _LoginCasesTable extends StatelessWidget {
  const _LoginCasesTable({required this.cases});

  final List<LoginTestCaseDefinition> cases;

  @override
  Widget build(BuildContext context) {
    if (cases.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: <Widget>[
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: const Row(
              children: <Widget>[
                SizedBox(
                  width: 80,
                  child: Text(
                    'Case ID',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: Text(
                    'Description / Expected Flow',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Target Result',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                SizedBox(
                  width: 60,
                  child: Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Rows
          for (var idx = 0; idx < cases.length; idx++) ...<Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              color: idx.isEven ? Colors.white : const Color(0xFFFAFAFA),
              child: Row(
                children: <Widget>[
                  // Case ID Monospace badge
                  SizedBox(
                    width: 72,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Tooltip(
                        message: cases[idx].id,
                        child: Container(
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
                            _formatDisplayCaseId(cases[idx].id, idx),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Description
                  Expanded(
                    flex: 5,
                    child: Text(
                      cases[idx].name,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Target Result
                  Expanded(
                    flex: 3,
                    child: Text(
                      _resultLabel(cases[idx].expectedResult),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Status chip
                  SizedBox(
                    width: 60,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Ready',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (idx < cases.length - 1)
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
          ],
        ],
      ),
    );
  }

  static String _resultLabel(LoginExpectedResult result) => result.label;

  static String _formatDisplayCaseId(String id, int index) {
    final clean = id.trim();
    if (clean.length <= 8 &&
        !clean.contains('-178') &&
        !clean.contains('login-case') &&
        !clean.contains('legacy-')) {
      return clean;
    }
    return 'TC-${(index + 1).toString().padLeft(2, '0')}';
  }
}

class _LoginStepsList extends StatelessWidget {
  const _LoginStepsList({required this.steps});

  final List<String> steps;

  static const List<String> _defaultSteps = <String>[
    'Check current login session',
    'Log out if an existing session is detected',
    'Run enabled Login test cases from Settings in saved order',
    'Select terminal and verify home screen',
    'Log out and restore a clean session',
  ];

  @override
  Widget build(BuildContext context) {
    final effectiveSteps = steps.isNotEmpty ? steps : _defaultSteps;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (var i = 0; i < effectiveSteps.length; i++) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      effectiveSteps[i],
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderAllocationPanel extends StatelessWidget {
  const _OrderAllocationPanel({required this.order});

  final AiOrderLaunchPreview order;

  @override
  Widget build(BuildContext context) {
    final itemCount = order.items.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Order Card Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5ECE8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Order ${order.orderNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Color(0xFF2C302E),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Order #${order.orderNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // SKU Items Table matching output SKU table exactly
          if (order.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No SKU items assigned for this order.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            )
          else ...<Widget>[
            // Column Headers: SKU Code, Weight, Entry Mode, Item Type
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              color: const Color(0xFFFBFBFB),
              child: const Row(
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: Text(
                      'SKU Code',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Weight',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Entry Mode',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Item Type',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Table Rows
            for (var idx = 0; idx < order.items.length; idx++) ...<Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                color: idx.isEven ? Colors.white : const Color(0xFFFAFAFA),
                child: Row(
                  children: <Widget>[
                    // SKU Code (flex 3, monospace, plain code matching output SKU table)
                    Expanded(
                      flex: 3,
                      child: Text(
                        order.items[idx].skuCode,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Weight (flex 2, auto/manual/specified)
                    Expanded(
                      flex: 2,
                      child: Text(
                        order.items[idx].effectiveWeightLabel,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              order.items[idx].effectiveWeightLabel != '—' &&
                                  order.items[idx].effectiveWeightLabel !=
                                      'Auto'
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color:
                              order.items[idx].effectiveWeightLabel == 'Auto' ||
                                  order.items[idx].effectiveWeightLabel ==
                                      'Manual'
                              ? const Color(0xFF64748B)
                              : (order.items[idx].effectiveWeightLabel == '—'
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF0F172A)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Entry Mode (flex 3)
                    Expanded(
                      flex: 3,
                      child: Text(
                        order.items[idx].entryModeLabel,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Item Type (flex 3)
                    Expanded(
                      flex: 3,
                      child: Text(
                        order.items[idx].typeLabel,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (idx < order.items.length - 1)
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ],
          ],
        ],
      ),
    );
  }
}
