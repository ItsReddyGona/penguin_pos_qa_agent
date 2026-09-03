import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_ui_tokens.dart';

/// A sleek, Gemini/Antigravity-style Live Thinking widget for the AI Assistant.
///
/// Displays an active live elapsed timer, real-time reasoning/thought stream,
/// live formatted JSON generation preview, and sequential status checks while the model generates a plan.
class AssistantModelTrace extends StatefulWidget {
  const AssistantModelTrace({
    super.key,
    required this.events,
    required this.running,
    this.liveStream = '',
    this.liveReasoning = '',
  });

  final List<AiModelEvent> events;
  final bool running;
  final String liveStream;
  final String liveReasoning;

  @override
  State<AssistantModelTrace> createState() => _AssistantModelTraceState();
}

class _AssistantModelTraceState extends State<AssistantModelTrace>
    with SingleTickerProviderStateMixin {
  late final Stopwatch _stopwatch;
  Timer? _timer;
  bool _expanded = true;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    if (widget.running) {
      _stopwatch.start();
      _startTimer();
    }
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant AssistantModelTrace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.running && !oldWidget.running) {
      _stopwatch
        ..reset()
        ..start();
      _startTimer();
    } else if (!widget.running && oldWidget.running) {
      _stopwatch.stop();
      _timer?.cancel();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    _pulseController.dispose();
    super.dispose();
  }

  int get _elapsedSeconds => _stopwatch.elapsed.inSeconds;

  String _getDynamicSubStatus(int elapsed) {
    if (elapsed < 3) return 'Connecting to configured model…';
    if (elapsed < 7) return 'Analyzing test scenarios & parameters…';
    if (elapsed < 12) return 'Synthesizing structured execution plan…';
    return 'Validating plan schema against safety guardrails…';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty && !widget.running) {
      return const SizedBox.shrink();
    }

    final statuses = widget.events
        .where((event) => event.kind == AiModelEventKind.status)
        .toList(growable: false);
    final errors = widget.events
        .where((event) => event.kind == AiModelEventKind.error)
        .toList(growable: false);

    final latestStatus = statuses.isEmpty ? null : statuses.last;
    final elapsedText = '${_elapsedSeconds}s';

    // If running and model takes multiple seconds, synthesize dynamic progress
    final displayStatuses = <String>[
      for (final s in statuses) s.message,
      if (widget.running &&
          latestStatus != null &&
          latestStatus.message.contains('Connecting to') &&
          _elapsedSeconds >= 3)
        _getDynamicSubStatus(_elapsedSeconds),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Header Bar with Gemini/Antigravity-like Thinking Title and Live Timer
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(11),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: const Color(0xFFE0E7FF)),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 15,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        Text(
                          widget.running
                              ? 'Thinking'
                              : 'Thought for ${_elapsedSeconds > 0 ? elapsedText : 'a moment'}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        if (widget.running) ...<Widget>[
                          const SizedBox(width: 6),
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) => Opacity(
                              opacity: _pulseAnimation.value,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0E7FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  elapsedText,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF4338CA),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ] else ...<Widget>[
                          const SizedBox(width: 8),
                          Text(
                            '· ${statuses.length} checks',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),

          // Animated Smooth Expand/Collapse Checklist & Live Stream Body
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 14,
                          right: 14,
                          top: 10,
                          bottom: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            for (
                              var i = 0;
                              i < displayStatuses.length;
                              i++
                            ) ...<Widget>[
                              _ThinkingStepLine(
                                message: displayStatuses[i],
                                active:
                                    widget.running &&
                                    i == displayStatuses.length - 1,
                                complete:
                                    !widget.running ||
                                    i < displayStatuses.length - 1,
                              ),
                            ],
                            for (final error in errors) ...<Widget>[
                              _ThinkingStepLine(
                                message: error.message,
                                active: false,
                                complete: false,
                                error: true,
                              ),
                            ],

                            // Live Thought / Reasoning Stream Box
                            if (widget.running &&
                                widget.liveReasoning.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 8),
                              _LiveStreamViewer(
                                text: widget.liveReasoning,
                                isJson: false,
                              ),
                            ],

                            // Live Structured JSON Stream Preview Box
                            if (widget.running &&
                                widget.liveStream.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 8),
                              _LiveStreamViewer(
                                text: widget.liveStream,
                                isJson: true,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ThinkingStepLine extends StatelessWidget {
  const _ThinkingStepLine({
    required this.message,
    required this.active,
    required this.complete,
    this.error = false,
  });

  final String message;
  final bool active;
  final bool complete;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error
        ? AssistantUiTokens.error
        : active
        ? const Color(0xFF0F172A)
        : const Color(0xFF64748B);

    final isThought = message.startsWith('Thinking:');
    final cleanMessage = isThought
        ? message.substring('Thinking:'.length).trim()
        : message;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 16,
            width: 16,
            child: active
                ? const Padding(
                    padding: EdgeInsets.all(1.5),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF4F46E5),
                    ),
                  )
                : Icon(
                    error
                        ? Icons.error_outline_rounded
                        : complete
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 15,
                    color: error
                        ? AssistantUiTokens.error
                        : complete
                        ? const Color(0xFF10B981)
                        : const Color(0xFF94A3B8),
                  ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: isThought
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      cleanMessage,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF334155),
                      ),
                    ),
                  )
                : Text(
                    cleanMessage,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      color: color,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LiveStreamViewer extends StatefulWidget {
  const _LiveStreamViewer({required this.text, this.isJson = true});

  final String text;
  final bool isJson;

  @override
  State<_LiveStreamViewer> createState() => _LiveStreamViewerState();
}

class _LiveStreamViewerState extends State<_LiveStreamViewer> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant _LiveStreamViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients &&
            _scrollController.position.hasContentDimensions) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isJson) {
      return AssistantJsonCodeView(
        text: widget.text,
        title: 'Generating Test Plan JSON',
        live: true,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(
                Icons.psychology_outlined,
                size: 14,
                color: Color(0xFF4F46E5),
              ),
              SizedBox(width: 6),
              Text(
                'Live Thought Process',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4338CA),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, maxHeight: 380),
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '${widget.text} ▊',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable, readable JSON surface shared by live generation and completed
/// planning summaries. Complete documents are decoded and pretty-printed;
/// partial live documents use the incremental formatter until they become
/// valid JSON.
class AssistantJsonCodeView extends StatefulWidget {
  const AssistantJsonCodeView({
    super.key,
    required this.text,
    required this.title,
    this.live = false,
    this.maxHeight = 380,
  });

  final String text;
  final String title;
  final bool live;
  final double maxHeight;

  @override
  State<AssistantJsonCodeView> createState() => _AssistantJsonCodeViewState();
}

class _AssistantJsonCodeViewState extends State<AssistantJsonCodeView> {
  final ScrollController _scrollController = ScrollController();
  final _formatter = _IncrementalJsonFormatter();
  String _displayText = '';

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant AssistantJsonCodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text || widget.live != oldWidget.live) {
      _sync();
      if (widget.live) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients &&
              _scrollController.position.hasContentDimensions) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        });
      }
    }
  }

  void _sync() {
    _displayText = _prettyJson(widget.text);
    _formatter.sync(_displayText);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: widget.live
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF38BDF8),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE2E8F0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: 48,
              maxHeight: widget.maxHeight,
            ),
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: SelectableText.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.55,
                        color: Color(0xFFCBD5E1),
                      ),
                      children: <InlineSpan>[
                        ..._formatter.spans(),
                        if (widget.live)
                          const TextSpan(
                            text: ' ▊',
                            style: TextStyle(color: Color(0xFF38BDF8)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _prettyJson(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(trimmed));
    } on FormatException {
      // A live response is often incomplete. The incremental formatter below
      // can still display that prefix safely until the final bracket arrives.
      return trimmed;
    }
  }
}

enum _JsonTokenKind { punctuation, key, string, number, literal }

class _JsonToken {
  const _JsonToken(this.text, this.kind);

  final String text;
  final _JsonTokenKind kind;
}

/// Incrementally formats only the suffix added by the latest stream chunk.
/// Rendering still walks the finished spans, but tokenization no longer
/// rescans the complete accumulated response for every character received.
class _IncrementalJsonFormatter {
  final List<_JsonToken> _tokens = <_JsonToken>[];
  final StringBuffer _stringBuffer = StringBuffer();
  final StringBuffer _bareBuffer = StringBuffer();

  String _raw = '';
  String? _pendingString;
  var _indent = 0;
  var _inString = false;
  var _escape = false;

  void sync(String raw) {
    if (!raw.startsWith(_raw)) {
      _reset();
    }
    final suffix = raw.substring(_raw.length);
    for (var i = 0; i < suffix.length; i++) {
      _consume(suffix[i]);
    }
    _raw = raw;
  }

  void _reset() {
    _tokens.clear();
    _stringBuffer.clear();
    _bareBuffer.clear();
    _raw = '';
    _pendingString = null;
    _indent = 0;
    _inString = false;
    _escape = false;
  }

  void _consume(String char) {
    if (_inString) {
      _stringBuffer.write(char);
      if (_escape) {
        _escape = false;
      } else if (char == '\\') {
        _escape = true;
      } else if (char == '"') {
        _inString = false;
        _pendingString = _stringBuffer.toString();
        _stringBuffer.clear();
      }
      return;
    }

    if (_pendingString != null) {
      if (_isWhitespace(char)) return;
      if (char == ':') {
        _emit(_pendingString!, _JsonTokenKind.key);
        _pendingString = null;
        _emit(': ', _JsonTokenKind.punctuation);
        return;
      }
      _emit(_pendingString!, _JsonTokenKind.string);
      _pendingString = null;
      _consume(char);
      return;
    }

    if (char == '"') {
      _flushBare();
      _inString = true;
      _stringBuffer.write(char);
      return;
    }

    if (char == '{' || char == '[') {
      _flushBare();
      _emit(char, _JsonTokenKind.punctuation);
      _indent += 2;
      _emit('\n${' ' * _indent}', _JsonTokenKind.punctuation);
      return;
    }
    if (char == '}' || char == ']') {
      _flushBare();
      _indent = (_indent - 2).clamp(0, 50);
      _emit('\n${' ' * _indent}$char', _JsonTokenKind.punctuation);
      return;
    }
    if (char == ',') {
      _flushBare();
      _emit(',\n${' ' * _indent}', _JsonTokenKind.punctuation);
      return;
    }
    if (char == ':') {
      _flushBare();
      _emit(': ', _JsonTokenKind.punctuation);
      return;
    }
    if (_isWhitespace(char)) {
      _flushBare();
      return;
    }
    _bareBuffer.write(char);
  }

  bool _isWhitespace(String char) =>
      char == ' ' || char == '\n' || char == '\r' || char == '\t';

  void _flushBare() {
    if (_bareBuffer.isEmpty) return;
    final value = _bareBuffer.toString();
    _bareBuffer.clear();
    final kind =
        RegExp(r'^-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$').hasMatch(value)
        ? _JsonTokenKind.number
        : _JsonTokenKind.literal;
    _emit(value, kind);
  }

  void _emit(String text, _JsonTokenKind kind) {
    if (text.isEmpty) return;
    if (_tokens.isNotEmpty && _tokens.last.kind == kind) {
      final previous = _tokens.removeLast();
      _tokens.add(_JsonToken('${previous.text}$text', kind));
      return;
    }
    _tokens.add(_JsonToken(text, kind));
  }

  List<TextSpan> spans() {
    final visible = <_JsonToken>[..._tokens];
    if (_pendingString != null) {
      visible.add(_JsonToken(_pendingString!, _JsonTokenKind.string));
    }
    if (_inString && _stringBuffer.isNotEmpty) {
      visible.add(_JsonToken(_stringBuffer.toString(), _JsonTokenKind.string));
    }
    if (_bareBuffer.isNotEmpty) {
      final value = _bareBuffer.toString();
      visible.add(
        _JsonToken(
          value,
          RegExp(r'^-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$').hasMatch(value)
              ? _JsonTokenKind.number
              : _JsonTokenKind.literal,
        ),
      );
    }

    return visible
        .map(
          (token) => TextSpan(
            text: token.text,
            style: TextStyle(color: _colorFor(token.kind)),
          ),
        )
        .toList(growable: false);
  }

  Color _colorFor(_JsonTokenKind kind) => switch (kind) {
    _JsonTokenKind.punctuation => const Color(0xFF94A3B8),
    _JsonTokenKind.key => const Color(0xFF7DD3FC),
    _JsonTokenKind.string => const Color(0xFF86EFAC),
    _JsonTokenKind.number => const Color(0xFFFDE68A),
    _JsonTokenKind.literal => const Color(0xFFC4B5FD),
  };
}
