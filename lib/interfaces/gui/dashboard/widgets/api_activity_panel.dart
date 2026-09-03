import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/api_trace_event.dart';

/// Bento-styled API Activity Panel displaying live Dio HTTP request telemetry.
class ApiActivityPanel extends StatefulWidget {
  final List<ApiTraceEvent> traces;
  final VoidCallback? onClearTraces;

  const ApiActivityPanel({super.key, required this.traces, this.onClearTraces});

  @override
  State<ApiActivityPanel> createState() => _ApiActivityPanelState();
}

class _ApiActivityPanelState extends State<ApiActivityPanel> {
  int? _expandedTraceId;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: widget.traces.isEmpty
                ? _buildEmptyState()
                : _buildTraceList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.api_rounded, size: 18, color: Color(0xFF0284C7)),
          const SizedBox(width: 8),
          const Text(
            'API Activity Telemetry',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Text(
              '${widget.traces.length} events',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0284C7),
              ),
            ),
          ),
          const Spacer(),
          if (widget.traces.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.download_rounded, size: 16),
              tooltip: 'Export Redacted JSON',
              onPressed: _exportJson,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              tooltip: 'Clear Traces',
              onPressed: widget.onClearTraces,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.wifi_tethering_off_rounded,
            size: 32,
            color: Color(0xFF94A3B8),
          ),
          SizedBox(height: 8),
          Text(
            'No API Activity Captured',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'HTTP requests made by PenguinPOS during test execution will appear here live.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTraceList(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: widget.traces.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final trace = widget.traces[widget.traces.length - 1 - index];
        final isExpanded = _expandedTraceId == trace.traceId;
        return _buildTraceTile(trace, isExpanded);
      },
    );
  }

  Widget _buildTraceTile(ApiTraceEvent trace, bool isExpanded) {
    final isSuccess = trace.result == ApiTraceResult.success;
    final isHttpError = trace.result == ApiTraceResult.httpError;
    final statusColor = isSuccess
        ? const Color(0xFF16A34A)
        : isHttpError
        ? const Color(0xFFDC2626)
        : const Color(0xFFD97706);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isExpanded ? statusColor : const Color(0xFFE2E8F0),
          width: isExpanded ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() {
            _expandedTraceId = isExpanded ? null : trace.traceId;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      trace.method,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trace.route,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      trace.statusCode != null
                          ? '${trace.statusCode} ${trace.result.name}'
                          : trace.result.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${trace.durationMs} ms',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Step: ${trace.stepId}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  if (trace.timeoutBudgetMs > 0) ...[
                    const SizedBox(width: 12),
                    Text(
                      'Budget: ${trace.timeoutBudgetMs}ms',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                SelectableText(
                  'Payload Preview:\n${trace.sanitizedPreview}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _exportJson() {
    final jsonStr = jsonEncode(widget.traces.map((t) => t.toJson()).toList());
    Clipboard.setData(ClipboardData(text: jsonStr));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Redacted API telemetry exported to clipboard.'),
      ),
    );
  }
}
