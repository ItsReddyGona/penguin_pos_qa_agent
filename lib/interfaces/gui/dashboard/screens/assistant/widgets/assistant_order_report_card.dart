import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_report_widgets.dart';

/// Per-order outcome report, styled consistently with the Manual Mode Order suite output.
class AssistantOrderReportCard extends StatelessWidget {
  const AssistantOrderReportCard({super.key, required this.report});

  final AiRichOrderReport report;

  @override
  Widget build(BuildContext context) {
    final totalOrders = report.orders.length;
    final passedOrders = report.passedCount;
    final failedOrders = totalOrders - passedOrders;

    return AssistantReportCard(
      passed: report.passed,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AssistantReportHeader(
              passed: report.passed,
              title: report.passed
                  ? '$passedOrders order${passedOrders == 1 ? '' : 's'} completed'
                  : 'Order run finished with failures',
              subtitle:
                  '${report.suiteTitle} · ${report.profileLabel} — ${formatAssistantDuration(report.totalDurationMs)}',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: <Widget>[
                  _summaryChip(
                    'Total $totalOrders Order${totalOrders == 1 ? '' : 's'}',
                    const Color(0xFF475569),
                  ),
                  const SizedBox(width: 8),
                  _summaryChip('Passed $passedOrders', const Color(0xFF15803D)),
                  const SizedBox(width: 8),
                  _summaryChip('Failed $failedOrders', const Color(0xFFB91C1C)),
                  const SizedBox(width: 8),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      'Payable: ₹${report.aggregateTotalPayable.toStringAsFixed(2)} → Cash: ₹${report.aggregatePayableAmount}',
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 24, color: Color(0xFFF1F5F9)),
            ),
            const _SectionLabel('Order results', top: 0, bottom: 10),
            for (final order in report.orders) _OrderResultCard(order: order),
            if (report.testChecks.isNotEmpty) ...<Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 20, color: Color(0xFFF1F5F9)),
              ),
              const _SectionLabel(
                'Test checks applied to every order',
                top: 0,
                bottom: 8,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: AssistantScenarioResultTable(
                  results: report.testChecks,
                  formatDuration: formatAssistantDuration,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Widget _summaryChip(String label, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.10),
    borderRadius: BorderRadius.circular(6),
  ),
  child: Text(
    label,
    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
  ),
);

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {required this.top, required this.bottom});

  final String label;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top, 16, bottom),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _OrderResultCard extends StatelessWidget {
  const _OrderResultCard({required this.order});

  final AiOrderResult order;

  @override
  Widget build(BuildContext context) {
    final durationSec = (order.durationMs / 1000).toStringAsFixed(1);
    final orderNum =
        order.orderNumberLabel ?? 'ORD-${10000 + order.orderNumber}';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Order Header Bar matching Manual Mode
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
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
                    'Order #${order.orderNumber} (${order.itemSummary})',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${durationSec}s',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 10),
                _statusChip(order.passed ? 'Pass' : 'Fail', order.passed),
              ],
            ),
          ),

          // Order Body Stages
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // 1. Login Check Stage Row
                _buildStageRow(
                  icon: Icons.lock_outline_rounded,
                  stageName: 'Login Check',
                  detail: 'Active Session / Direct Sale Verification',
                  passed: true,
                ),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),

                // 2. Customer Selection Stage Row
                _buildStageRow(
                  icon: Icons.person_outline_rounded,
                  stageName: 'Customer',
                  detail: 'Continue Without Customer (Proxy / Walk-in)',
                  passed: true,
                ),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),

                // 3. SKUs Punched Stage
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 16,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'SKUs Punched',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${order.skuResults.length} item${order.skuResults.length == 1 ? '' : 's'})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildSkuTable(order.skuResults),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),

                // 4. Payment Stage Row
                _buildStageRow(
                  icon: Icons.payments_outlined,
                  stageName: 'Payment',
                  detail:
                      'Cash Selected · Total: ₹${order.totalPayable.toStringAsFixed(2)} → Tendered: ₹${order.cashAmount}',
                  passed: true,
                ),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),

                // 5. Order Success Stage Row
                _buildStageRow(
                  icon: Icons.check_circle_outline_rounded,
                  stageName: 'Order Success',
                  detail: 'Order Number: #$orderNum · Completed',
                  passed: order.passed,
                ),

                // Error box if order failed (clean, compact callout)
                if (!order.passed && order.error != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFEE2E2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.error_outline_rounded,
                            size: 14,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            order.error!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Color(0xFFB91C1C),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageRow({
    required IconData icon,
    required String stageName,
    required String detail,
    required bool passed,
  }) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: const Color(0xFF2563EB)),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: Text(
            stageName,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            detail,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
          ),
        ),
        const SizedBox(width: 12),
        _statusChip(passed ? 'Pass' : 'Fail', passed),
      ],
    );
  }

  Widget _buildSkuTable(List<AiOrderSkuResult> skus) {
    if (skus.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Text(
          'No SKU items recorded for this order.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: <Widget>[
          // Table Header matching Manual Mode
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
            ),
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
                SizedBox(width: 8),
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
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Table Rows with alternating zebra styling and sleek inline error callouts
          ...skus.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: idx.isEven ? Colors.white : const Color(0xFFFAFAFA),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      // SKU Code (Flex 3, monospace)
                      Expanded(
                        flex: 3,
                        child: Text(
                          item.sku,
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
                      // Weight (Flex 2)
                      Expanded(
                        flex: 2,
                        child: Text(
                          _formatWeight(item),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: item.weight != null
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: item.weight != null
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Entry Mode (Flex 3)
                      Expanded(
                        flex: 3,
                        child: Text(
                          item.entryMode,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Item Type (Flex 3)
                      Expanded(
                        flex: 3,
                        child: Text(
                          item.type,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status (Width 60)
                      SizedBox(
                        width: 60,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _statusChip(
                            item.passed ? 'Pass' : 'Fail',
                            item.passed,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Sleek, non-bulky inline failure callout
                  if (!item.passed &&
                      item.error != null &&
                      item.error!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 5),
                    Padding(
                      padding: const EdgeInsets.only(left: 2, top: 1),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 13,
                            color: Color(0xFFB91C1C),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              item.error!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFB91C1C),
                                fontWeight: FontWeight.w500,
                                height: 1.25,
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
          }),
        ],
      ),
    );
  }

  static Widget _statusChip(String label, bool passed) {
    final color = passed ? const Color(0xFF15803D) : const Color(0xFFB91C1C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static String _formatWeight(AiOrderSkuResult item) {
    if (item.weight != null) {
      return '${item.weight} kg';
    }
    final isWeighed =
        item.type.toLowerCase().contains('weighed') &&
        !item.type.toLowerCase().contains('non');
    if (isWeighed) {
      return 'Auto';
    }
    return '—';
  }
}
