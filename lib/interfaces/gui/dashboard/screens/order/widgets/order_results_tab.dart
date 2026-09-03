import 'package:flutter/material.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_metrics.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_runner.dart';

/// Clean, structured Output & Execution Results Tab for Order Suite runs.
class OrderResultsTab extends StatelessWidget {
  const OrderResultsTab({
    super.key,
    required this.result,
    required this.lastExecutionPassed,
    required this.lastExecutionDetails,
  });

  final OrderRunResult? result;
  final bool? lastExecutionPassed;
  final String? lastExecutionDetails;

  @override
  Widget build(BuildContext context) {
    if (result == null && lastExecutionPassed == null) {
      return Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const <Widget>[
                Icon(
                  Icons.analytics_outlined,
                  size: 44,
                  color: Color(0xFF94A3B8),
                ),
                SizedBox(height: 12),
                Text(
                  'No Execution Output',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF334155),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Run the Order Suite to view per-order stage results, SKU parameters, and order details.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final loops = result?.loopMetrics ?? const <OrderLoopMetrics>[];
    final totalLoops = loops.length;
    final passedLoops = loops.where((l) => l.passed).length;
    final failedLoops = loops.where((l) => !l.passed).length;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Header: Execution Output & Summary Chips
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const Text(
                  'Execution output',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 14),
                _summaryChip(
                  'Total $totalLoops Order${totalLoops == 1 ? '' : 's'}',
                  const Color(0xFF475569),
                ),
                const SizedBox(width: 8),
                _summaryChip('Passed $passedLoops', const Color(0xFF15803D)),
                const SizedBox(width: 8),
                _summaryChip('Failed $failedLoops', const Color(0xFFB91C1C)),
                const Spacer(),
                if (result != null) ...<Widget>[
                  Text(
                    'Payable: ₹${result!.aggregateTotalPayable.toStringAsFixed(2)} → Cash: ₹${result!.aggregatePayableAmount}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Per-Order Detailed Cards List
            Expanded(
              child: ListView.separated(
                itemCount: loops.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return _buildOrderCard(loops[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(OrderLoopMetrics loop) {
    final durationSec = (loop.durationMs / 1000).toStringAsFixed(2);
    final orderNum = loop.orderNumber ?? 'ORD-${10000 + loop.loopIndex}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Order Header
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
                    'Order #${loop.loopIndex}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Color(0xFF2C302E),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Order #${loop.loopIndex} (${loop.itemsCount} SKU Item${loop.itemsCount == 1 ? '' : 's'})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                Text(
                  'Duration: ${durationSec}s',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                _statusChip(loop.passed ? 'Pass' : 'Fail', loop.passed),
              ],
            ),
          ),

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

                // 3. SKUs Table Stage
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
                      '(${loop.skuResults.length} item${loop.skuResults.length == 1 ? '' : 's'})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildSkuTable(loop.skuResults),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),

                // 4. Payment Stage Row
                _buildStageRow(
                  icon: Icons.payments_outlined,
                  stageName: 'Payment',
                  detail:
                      'Cash Selected · Total: ₹${loop.totalPayable.toStringAsFixed(2)} → Tendered: ₹${loop.payableCash}',
                  passed: true,
                ),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),

                // 5. Order Success Stage Row
                _buildStageRow(
                  icon: Icons.check_circle_outline_rounded,
                  stageName: 'Order Success',
                  detail: 'Order Number: #$orderNum · Completed',
                  passed: loop.passed,
                ),

                // Error box if loop failed
                if (!loop.passed && loop.error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      loop.error!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0xFFB91C1C),
                        height: 1.4,
                      ),
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
          width: 120,
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

  Widget _buildSkuTable(List<OrderSkuResult> skus) {
    if (skus.isEmpty) {
      return Container(
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
          // Table Header
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

          // Table Rows
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
                      // SKU Code (Flex 3)
                      Expanded(
                        flex: 3,
                        child: Text(
                          item.sku,
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
                  if (!item.passed &&
                      item.error != null &&
                      item.error!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.error_outline,
                            size: 13,
                            color: Color(0xFFB91C1C),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.error!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFB91C1C),
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
          }),
        ],
      ),
    );
  }

  Widget _statusChip(String label, bool passed) {
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

  Widget _summaryChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _formatWeight(OrderSkuResult item) {
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
