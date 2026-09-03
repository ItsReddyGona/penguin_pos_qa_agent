import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/api_trace_event.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_composer.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_log_drawer.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_message_list.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_top_bar.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_welcome_canvas.dart';

/// Full-screen AI Assistant Workspace for PenguinPOS QA Agent.
class AiAssistantWorkspace extends StatefulWidget {
  const AiAssistantWorkspace({
    super.key,
    required this.modelConfigured,
    required this.running,
    required this.messages,
    required this.onAddMessage,
    this.onTruncateMessages,
    required this.activityMessages,
    required this.apiTraces,
    required this.executionSteps,
    required this.executionSuiteTitle,
    required this.executionProfileLabel,
    required this.onSend,
    required this.onRunPlan,
    this.onOpenPlanInManualMode,
    this.onStop,
    this.sshTargetEnabled,
    this.onSshTargetChanged,
    required this.onOpenSettings,
    required this.onExitAiMode,
    this.onPlanningStateChanged,
  });

  final bool modelConfigured;
  final bool running;
  final List<AiChatMessage> messages;
  final ValueChanged<AiChatMessage> onAddMessage;
  final ValueChanged<int>? onTruncateMessages;
  final ValueChanged<bool>? onPlanningStateChanged;
  final List<QaActivityMessage> activityMessages;
  final List<ApiTraceEvent> apiTraces;

  /// Live execution progress steps pushed from the dashboard during test runs.
  final List<AiExecutionStep> executionSteps;
  final String executionSuiteTitle;
  final String executionProfileLabel;

  final Future<AiAssistantResponse> Function(
    String input,
    List<AiChatMessage> history,
    AiModelEventCallback onEvent,
  )
  onSend;
  final ValueChanged<AiTestPlan> onRunPlan;
  final ValueChanged<AiTestPlan>? onOpenPlanInManualMode;
  final VoidCallback? onStop;
  final bool? sshTargetEnabled;
  final ValueChanged<bool>? onSshTargetChanged;
  final VoidCallback onOpenSettings;
  final VoidCallback onExitAiMode;

  @override
  State<AiAssistantWorkspace> createState() => _AiAssistantWorkspaceState();
}

class _AiAssistantWorkspaceState extends State<AiAssistantWorkspace> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _waiting = false;
  bool _logExpanded = false;
  final List<AiModelEvent> _modelEvents = <AiModelEvent>[];
  String _liveStreamText = '';
  String _liveReasoningText = '';
  int _slashSelectedIndex = 0;
  String? _lastSlashQuery;
  TextEditingValue? _dismissedSlashPopupValue;

  List<AiModelEvent> get _visiblePlanningEvents {
    if (_modelEvents.isEmpty) {
      return const <AiModelEvent>[
        AiModelEvent(
          kind: AiModelEventKind.status,
          message: 'Preparing test plan…',
        ),
      ];
    }
    final errors = _modelEvents.where((e) => e.kind == AiModelEventKind.error);
    if (errors.isNotEmpty) return errors.toList();

    final visible = <AiModelEvent>[];
    final seen = <String>{};
    for (final event in _modelEvents) {
      if (event.kind == AiModelEventKind.status) {
        final msg = event.message.trim();
        if (msg.isNotEmpty && seen.add(msg)) {
          visible.add(event);
        }
      }
    }
    return visible.isEmpty
        ? const <AiModelEvent>[
            AiModelEvent(
              kind: AiModelEventKind.status,
              message: 'Preparing test plan…',
            ),
          ]
        : visible;
  }

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_onComposerValueChanged);
  }

  static const List<String> _knownSlashCommands = <String>['/login', '/order'];

  @override
  void dispose() {
    _inputController.removeListener(_onComposerValueChanged);
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<String> get _filteredSlashCommands {
    final value = _inputController.value;
    if (_dismissedSlashPopupValue == value) return const <String>[];
    final query = slashCommandQueryAtCursor(value)?.text.toLowerCase();
    if (query == null) return const <String>[];
    return _knownSlashCommands
        .where((cmd) => cmd.toLowerCase().startsWith(query))
        .toList();
  }

  /// Keeps slash suggestions aligned with edits and cursor movement, including
  /// when the user moves back into a slash command in the middle of a message.
  void _onComposerValueChanged() {
    final value = _inputController.value;
    if (_dismissedSlashPopupValue != null &&
        _dismissedSlashPopupValue != value) {
      _dismissedSlashPopupValue = null;
    }

    final query = slashCommandQueryAtCursor(value);
    final nextQuery = query == null
        ? null
        : '${query.start}:${query.end}:${query.text.toLowerCase()}';
    if (nextQuery == _lastSlashQuery) return;

    _lastSlashQuery = nextQuery;
    if (mounted) {
      setState(() => _slashSelectedIndex = 0);
    }
  }

  /// Inserts a slash command into the user's current sentence. Selection from
  /// the popup is intentionally non-destructive and never submits the input.
  void _insertSlashCommand(String command) {
    final updated = insertSlashCommandAtCursor(_inputController.value, command);
    if (updated == null) return;

    _inputController.value = updated;
    _dismissedSlashPopupValue = updated;
    setState(() => _slashSelectedIndex = 0);
    _focusNode.requestFocus();
  }

  void _openSlashMenu() {
    final updated = insertSlashTriggerAtCursor(_inputController.value);
    _inputController.value = updated;
    _dismissedSlashPopupValue = null;
    _lastSlashQuery = null;
    setState(() => _slashSelectedIndex = 0);
    _focusNode.requestFocus();
  }

  /// Welcome-canvas buttons are explicit shortcuts, unlike composer slash
  /// selections, and retain their existing direct action behavior.
  void _runBentoAction(String command) {
    if (command == '/settings') {
      _inputController.clear();
      widget.onOpenSettings();
      return;
    }
    if (command == '/manual') {
      _inputController.clear();
      widget.onExitAiMode();
      return;
    }
    _inputController.text = command;
    _inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: command.length),
    );
    _send();
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _waiting || widget.running) return;
    final startedAt = DateTime.now();

    setState(() {
      _inputController.clear();
      _waiting = true;
      _slashSelectedIndex = 0;
      _modelEvents.clear();
      _liveStreamText = '';
      _liveReasoningText = '';
    });

    widget.onPlanningStateChanged?.call(true);
    widget.onAddMessage(AiChatMessage(role: AiChatRole.user, text: text));
    _scrollToBottom();

    try {
      final response = await widget.onSend(
        text,
        widget.messages,
        _onModelEvent,
      );
      if (!mounted) return;
      final plan = response.plan;
      final hasValidatedPlan = response.canExecute;
      final planningSteps = _modelEvents
          .where((event) => event.kind == AiModelEventKind.status)
          .map((event) => event.message)
          .toSet()
          .toList(growable: false);
      final activitySummary = planningSteps.isEmpty
          ? null
          : AiRichPlanningSummary(
              steps: planningSteps,
              elapsedMs: DateTime.now().difference(startedAt).inMilliseconds,
              rawContent: _liveStreamText.isNotEmpty ? _liveStreamText : null,
              reasoning: _liveReasoningText.isNotEmpty
                  ? _liveReasoningText
                  : null,
            );

      widget.onAddMessage(
        AiChatMessage(
          role: AiChatRole.assistant,
          text: hasValidatedPlan
              ? '${response.message}\n\nPlan validated for ${plan!.profileId}. Executing test plan automatically…'
              : response.message,
          // A validated plan gets a launch-specific preview even when the
          // model did not provide a presentation card. This is read-only and
          // does not change the existing automatic launch behavior.
          richContent: hasValidatedPlan && plan != null
              ? _launchPreviewFor(plan)
              : response.richContent ??
                    (response.knowledge == null
                        ? null
                        : AiRichKnowledgeAnswer(answer: response.knowledge!)),
          activitySummary: activitySummary,
          pendingRequest: response.pendingRequest,
          executablePlan: hasValidatedPlan ? plan : null,
        ),
      );

      if (hasValidatedPlan && plan != null) {
        widget.onRunPlan(plan);
      }
    } catch (e) {
      if (e is OperationCanceledException) {
        return;
      }
      if (!mounted) return;
      widget.onAddMessage(
        AiChatMessage(
          role: AiChatRole.assistant,
          text:
              'I could not prepare a safe test plan. Please try again with the target and required test details.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _waiting = false;
          // Retain the safe planning/decision trace while the validated plan
          // executes. A new request clears it at the start of the next turn.
        });
        _scrollToBottom();
      }
      widget.onPlanningStateChanged?.call(false);
    }
  }

  AiRichLaunchPreview _launchPreviewFor(AiTestPlan plan) {
    if (!plan.isOrder) {
      return AiRichLaunchPreview(
        profileLabel: plan.profileId,
        workflowLabel: 'Login & Terminal',
        orders: const <AiOrderLaunchPreview>[],
        steps: plan.executionSteps,
        loginCases: plan.loginCases,
      );
    }

    List<AiOrderItemRow> rowsFor(Iterable<OrderItem> items, int order) => items
        .map(
          (item) => AiOrderItemRow.fromOrderItem(
            item,
            allocationLabel: 'Order $order',
          ),
        )
        .toList(growable: false);

    return AiRichLaunchPreview(
      profileLabel: plan.profileId,
      workflowLabel: 'Order & Cash Payment',
      dataSourceLabel: plan.inputSource == AiInputSource.settings
          ? 'Settings → Order Inputs'
          : 'User prompt',
      allocationModeLabel: plan.itemStrategy == AiItemStrategy.perOrder
          ? 'Custom payload per iteration'
          : 'Common payload (same for all)',
      orders: <AiOrderLaunchPreview>[
        for (var order = 1; order <= plan.ordersCount; order++)
          AiOrderLaunchPreview(
            orderNumber: order,
            items: plan.itemStrategy == AiItemStrategy.perOrder
                ? rowsFor(
                    plan.perIterationItems[order] ?? const <OrderItem>[],
                    order,
                  )
                : rowsFor(plan.items, order),
          ),
      ],
    );
  }

  void _onModelEvent(AiModelEvent event) {
    if (!mounted) return;

    if (event.kind == AiModelEventKind.response) {
      _liveStreamText += event.message;
      setState(() {});
      _scrollToBottom(onlyIfNearBottom: true);
      return;
    }

    if (event.kind == AiModelEventKind.reasoning) {
      // Providers stream reasoning in arbitrary fragments (sometimes one word
      // or partial word per event). Keep those fragments in one continuous
      // buffer for the live reasoning viewer and completed raw inspector.
      // They are deliberately not promoted to lifecycle status events:
      // doing so creates one checklist row per token and corrupts the real
      // planning-check count.
      _liveReasoningText += event.message;
      setState(() {});
      _scrollToBottom(onlyIfNearBottom: true);
      return;
    } else {
      _modelEvents.add(event);
    }

    setState(() {});
    // Do not yank the operator to the bottom for every live status event.
    // Keep the current reading position unless they were already following
    // the latest conversation content.
    _scrollToBottom(onlyIfNearBottom: true);
  }

  void _handleCopyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleEditAndRetrigger(int index, String newText) {
    if (_waiting || widget.running) {
      return;
    }
    widget.onTruncateMessages?.call(index);
    _inputController.text = newText;
    _send();
  }

  void _handleRetrigger(int index) {
    if (_waiting ||
        widget.running ||
        index < 0 ||
        index >= widget.messages.length) {
      return;
    }
    int targetIndex = index;
    if (widget.messages[index].role != AiChatRole.user) {
      for (int i = index - 1; i >= 0; i--) {
        if (widget.messages[i].role == AiChatRole.user) {
          targetIndex = i;
          break;
        }
      }
    }
    if (targetIndex < 0 || targetIndex >= widget.messages.length) return;
    final promptText = widget.messages[targetIndex].text;
    widget.onTruncateMessages?.call(targetIndex);
    _inputController.text = promptText;
    _send();
  }

  void _scrollToBottom({bool onlyIfNearBottom = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (onlyIfNearBottom &&
            _scrollController.position.maxScrollExtent -
                    _scrollController.position.pixels >
                96) {
          return;
        }
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasMessages = widget.messages.isNotEmpty;

    return Column(
      children: <Widget>[
        // Top 58px Bar
        AssistantTopBar(
          modelConfigured: widget.modelConfigured,
          sshTargetEnabled: widget.sshTargetEnabled,
          onSshTargetChanged: widget.onSshTargetChanged,
          onOpenSettings: widget.onOpenSettings,
          onExitAiMode: widget.onExitAiMode,
        ),

        // Main Center Canvas & Conversation Column (Max-width 980px)
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: <Widget>[
                    Expanded(
                      child: hasMessages
                          ? AssistantMessageList(
                              messages: widget.messages,
                              scrollController: _scrollController,
                              planningEvents: _visiblePlanningEvents,
                              planningRunning: _waiting,
                              liveStream: _liveStreamText,
                              liveReasoning: _liveReasoningText,
                              executionSteps: widget.executionSteps,
                              executionSuiteTitle: widget.executionSuiteTitle,
                              executionProfileLabel:
                                  widget.executionProfileLabel,
                              executionRunning: widget.running,
                              onCopyText: _handleCopyText,
                              onEditAndRetrigger: _handleEditAndRetrigger,
                              onRetrigger: _handleRetrigger,
                              onRunPlan: widget.onRunPlan,
                              onOpenPlanInManualMode:
                                  widget.onOpenPlanInManualMode,
                            )
                          : AssistantWelcomeCanvas(
                              onSelectBentoAction: _runBentoAction,
                            ),
                    ),

                    // Floating Composer Section
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: AssistantComposer(
                        inputController: _inputController,
                        focusNode: _focusNode,
                        waiting: _waiting,
                        running: widget.running,
                        filteredSlashCommands: _filteredSlashCommands,
                        slashSelectedIndex: _slashSelectedIndex,
                        onSelectSlashCommand: _insertSlashCommand,
                        onSlashSelectedIndexChanged: (idx) {
                          setState(() => _slashSelectedIndex = idx);
                        },
                        onOpenSlashMenu: _openSlashMenu,
                        onSend: _send,
                        onStop: widget.onStop,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Minimal Collapsed / Expandable Execution Log Drawer at Bottom
        AssistantLogDrawer(
          activityMessages: widget.activityMessages,
          apiTraces: widget.apiTraces,
          expanded: _logExpanded,
          onToggleExpanded: () {
            setState(() => _logExpanded = !_logExpanded);
          },
        ),
      ],
    );
  }
}
