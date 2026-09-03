import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_ui_tokens.dart';

/// Read-only explanation backed by the QA catalogue, rendered directly in the
/// chat instead of being mistaken for an execution plan.
class AssistantKnowledgeAnswerCard extends StatefulWidget {
  const AssistantKnowledgeAnswerCard({super.key, required this.answer});

  final AiKnowledgeAnswer answer;

  @override
  State<AssistantKnowledgeAnswerCard> createState() =>
      _AssistantKnowledgeAnswerCardState();
}

class _AssistantKnowledgeAnswerCardState
    extends State<AssistantKnowledgeAnswerCard> {
  Timer? _revealTimer;
  var _visibleUnits = 0;

  int get _totalUnits => widget.answer.sections.fold<int>(
    0,
    (count, section) => count + 1 + section.items.length,
  );

  @override
  void initState() {
    super.initState();
    if (_totalUnits == 0) return;
    _revealTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted || _visibleUnits >= _totalUnits) {
        timer.cancel();
        return;
      }
      setState(() => _visibleUnits += 1);
    });
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var unitOffset = 0;
    final answer = widget.answer;
    final sectionWidgets = <Widget>[];
    for (final section in answer.sections) {
      sectionWidgets.add(const SizedBox(height: 10));
      sectionWidgets.add(
        _KnowledgeSection(
          section: section,
          visible: _visibleUnits > unitOffset,
          visibleItems: (_visibleUnits - unitOffset - 1)
              .clamp(0, section.items.length)
              .toInt(),
        ),
      );
      unitOffset += 1 + section.items.length;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AssistantUiTokens.subtleSurface,
        borderRadius: AssistantUiTokens.compactRadius,
        border: Border.all(color: AssistantUiTokens.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.menu_book_outlined,
                size: 17,
                color: AssistantUiTokens.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  answer.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AssistantUiTokens.text,
                  ),
                ),
              ),
              const Text(
                'Read only',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AssistantUiTokens.mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            answer.summary,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: AssistantUiTokens.secondaryText,
            ),
          ),
          ...sectionWidgets,
          if (_visibleUnits >= _totalUnits)
            for (final diagram in answer.diagrams) ...<Widget>[
              const SizedBox(height: 12),
              _KnowledgeFlowDiagram(diagram: diagram),
            ],
          if (_visibleUnits >= _totalUnits &&
              answer.sources.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Based on: ${answer.sources.join(' · ')}',
              style: const TextStyle(
                fontSize: 10.5,
                color: AssistantUiTokens.mutedText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KnowledgeSection extends StatelessWidget {
  const _KnowledgeSection({
    required this.section,
    required this.visible,
    required this.visibleItems,
  });

  final AiKnowledgeSection section;
  final bool visible;
  final int visibleItems;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          section.title,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AssistantUiTokens.text,
          ),
        ),
        if (section.body != null) ...<Widget>[
          const SizedBox(height: 3),
          Text(
            section.body!,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: AssistantUiTokens.secondaryText,
            ),
          ),
        ],
        for (final item in section.items.take(visibleItems))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '• ',
                  style: TextStyle(color: AssistantUiTokens.accent),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: AssistantUiTokens.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Native, connected flow-chart renderer for declarative QA diagrams.
///
/// It renders the application's typed graph model directly. No Mermaid,
/// WebView, HTML, or arbitrary model-generated script is executed here.
class _KnowledgeFlowDiagram extends StatelessWidget {
  const _KnowledgeFlowDiagram({required this.diagram});

  final AiKnowledgeDiagram diagram;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AssistantUiTokens.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.account_tree_outlined,
                size: 15,
                color: AssistantUiTokens.accent,
              ),
              const SizedBox(width: 6),
              Text(
                diagram.title,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AssistantUiTokens.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final layout = _FlowGraphLayout.build(
                diagram: diagram,
                minimumWidth: constraints.maxWidth,
              );
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: layout.width,
                  height: layout.height,
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _FlowEdgePainter(
                            edges: layout.edges,
                            placements: layout.placements,
                          ),
                        ),
                      ),
                      for (final placement in layout.placements.values)
                        Positioned(
                          left: placement.left,
                          top: placement.top,
                          width: _FlowGraphLayout.nodeWidth,
                          height: _FlowGraphLayout.nodeHeight,
                          child: _FlowGraphNode(node: placement.node),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FlowGraphLayout {
  const _FlowGraphLayout({
    required this.width,
    required this.height,
    required this.placements,
    required this.edges,
  });

  static const nodeWidth = 156.0;
  static const nodeHeight = 78.0;
  static const horizontalGap = 30.0;
  static const verticalGap = 58.0;
  static const padding = 10.0;

  final double width;
  final double height;
  final Map<String, _FlowNodePlacement> placements;
  final List<AiKnowledgeDiagramEdge> edges;

  factory _FlowGraphLayout.build({
    required AiKnowledgeDiagram diagram,
    required double minimumWidth,
  }) {
    final nodes = <AiKnowledgeDiagramNode>[
      for (var index = 0; index < diagram.nodes.length; index += 1)
        if (diagram.nodes[index].id.trim().isEmpty)
          AiKnowledgeDiagramNode(
            id: 'node_$index',
            label: diagram.nodes[index].label,
            detail: diagram.nodes[index].detail,
            kind: diagram.nodes[index].kind,
          )
        else
          diagram.nodes[index],
    ];
    final nodeIds = nodes.map((node) => node.id).toSet();
    final edges = diagram.edges
        .where(
          (edge) =>
              nodeIds.contains(edge.fromNodeId) &&
              nodeIds.contains(edge.toNodeId),
        )
        .toList(growable: false);
    final levels = <String, int>{for (final node in nodes) node.id: 0};

    // Catalogue graphs are acyclic. Bounded relaxation also keeps a malformed
    // provider response from causing an unbounded UI layout calculation.
    for (var pass = 0; pass < nodes.length; pass += 1) {
      var changed = false;
      for (final edge in edges) {
        final next = (levels[edge.fromNodeId] ?? 0) + 1;
        if (next > (levels[edge.toNodeId] ?? 0)) {
          levels[edge.toNodeId] = next;
          changed = true;
        }
      }
      if (!changed) break;
    }

    final nodesByLevel = <int, List<AiKnowledgeDiagramNode>>{};
    for (final node in nodes) {
      nodesByLevel
          .putIfAbsent(levels[node.id] ?? 0, () => <AiKnowledgeDiagramNode>[])
          .add(node);
    }
    final maxColumns = nodesByLevel.values.fold<int>(
      1,
      (count, row) => math.max(count, row.length),
    );
    final naturalWidth =
        padding * 2 +
        maxColumns * nodeWidth +
        math.max(0, maxColumns - 1) * horizontalGap;
    final width = math.max(minimumWidth, naturalWidth);
    final maxLevel = levels.values.fold<int>(0, math.max);
    final height =
        padding * 2 + (maxLevel + 1) * nodeHeight + maxLevel * verticalGap;
    final placements = <String, _FlowNodePlacement>{};
    for (final entry in nodesByLevel.entries) {
      final row = entry.value;
      final rowWidth =
          row.length * nodeWidth + math.max(0, row.length - 1) * horizontalGap;
      final left = (width - rowWidth) / 2;
      for (var index = 0; index < row.length; index += 1) {
        final node = row[index];
        placements[node.id] = _FlowNodePlacement(
          node: node,
          left: left + index * (nodeWidth + horizontalGap),
          top: padding + entry.key * (nodeHeight + verticalGap),
        );
      }
    }
    return _FlowGraphLayout(
      width: width,
      height: height,
      placements: placements,
      edges: edges,
    );
  }
}

class _FlowNodePlacement {
  const _FlowNodePlacement({
    required this.node,
    required this.left,
    required this.top,
  });

  final AiKnowledgeDiagramNode node;
  final double left;
  final double top;
}

class _FlowEdgePainter extends CustomPainter {
  const _FlowEdgePainter({required this.edges, required this.placements});

  final List<AiKnowledgeDiagramEdge> edges;
  final Map<String, _FlowNodePlacement> placements;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AssistantUiTokens.accent.withValues(alpha: 0.72)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    for (final edge in edges) {
      final from = placements[edge.fromNodeId];
      final to = placements[edge.toNodeId];
      if (from == null || to == null) continue;
      final start = Offset(
        from.left + _FlowGraphLayout.nodeWidth / 2,
        from.top + _FlowGraphLayout.nodeHeight,
      );
      final end = Offset(to.left + _FlowGraphLayout.nodeWidth / 2, to.top);
      final middleY = start.dy + (end.dy - start.dy) / 2;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(start.dx, middleY)
        ..lineTo(end.dx, middleY)
        ..lineTo(end.dx, end.dy - 6);
      canvas.drawPath(path, linePaint);
      final arrow = Path()
        ..moveTo(end.dx - 4, end.dy - 8)
        ..lineTo(end.dx, end.dy - 3)
        ..lineTo(end.dx + 4, end.dy - 8);
      canvas.drawPath(arrow, linePaint);
      final label = edge.label?.trim();
      if (label == null || label.isEmpty) continue;
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AssistantUiTokens.accent,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset((start.dx + end.dx - textPainter.width) / 2, middleY - 13),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FlowEdgePainter oldDelegate) =>
      oldDelegate.edges != edges || oldDelegate.placements != placements;
}

class _FlowGraphNode extends StatelessWidget {
  const _FlowGraphNode({required this.node});

  final AiKnowledgeDiagramNode node;

  @override
  Widget build(BuildContext context) {
    final colors = switch (node.kind) {
      AiKnowledgeDiagramNodeKind.start => const (
        Color(0xFFE6F4EA),
        AssistantUiTokens.success,
      ),
      AiKnowledgeDiagramNodeKind.decision => const (
        Color(0xFFFFF4DC),
        Color(0xFFB97811),
      ),
      AiKnowledgeDiagramNodeKind.end => const (
        Color(0xFFEAF1FB),
        Color(0xFF3B6EA5),
      ),
      AiKnowledgeDiagramNodeKind.process => const (
        Colors.white,
        AssistantUiTokens.subtleBorder,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(
          node.kind == AiKnowledgeDiagramNodeKind.decision ? 18 : 9,
        ),
        border: Border.all(color: colors.$2, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (node.kind == AiKnowledgeDiagramNodeKind.decision)
            const Text(
              'DECISION',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: Color(0xFF9A6410),
              ),
            ),
          Text(
            node.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AssistantUiTokens.text,
            ),
          ),
          if (node.detail != null) ...<Widget>[
            const SizedBox(height: 3),
            Text(
              node.detail!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                height: 1.2,
                color: AssistantUiTokens.secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
