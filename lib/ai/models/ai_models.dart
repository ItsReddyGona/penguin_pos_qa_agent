import 'dart:convert';

import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/ai/models/qa_gen_ui.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/login_test_case.dart';

/// Shared contracts between the assistant UI, planner, and model provider.
///
/// These models contain only safe planning data. Credentials and direct driver
/// commands never travel through this layer.
enum AiProviderKind { openAiCompatible }

/// Persisted connection settings for an OpenAI-compatible planning model.
class AiModelConfig {
  static const defaultBaseUrl = 'http://127.0.0.1:11434/v1';
  static const defaultLabel = 'Local OpenAI-compatible';

  /// Gemma 4 e4b exposes a 128K context window. This is the largest output
  /// budget we request; the server may clamp it to its own model/runtime
  /// limits. The context window includes the prompt, history, and output.
  static const maxOutputTokenLimit = 128000;
  static const defaultMaxOutputTokens = maxOutputTokenLimit;

  const AiModelConfig({
    this.providerKind = AiProviderKind.openAiCompatible,
    this.label = defaultLabel,
    this.baseUrl = defaultBaseUrl,
    this.model = '',
    this.isCloud = false,
    this.temperature = 0.1,
    this.maxOutputTokens = defaultMaxOutputTokens,
    this.enableVerboseReasoning = false,
  });

  final AiProviderKind providerKind;
  final String label;
  final String baseUrl;
  final String model;
  final bool isCloud;
  final double temperature;
  final int maxOutputTokens;

  /// Debug-only: exposes model reasoning in the Assistant trace. It costs more
  /// tokens and can slow planning, so structured-plan mode keeps it off.
  final bool enableVerboseReasoning;

  /// A selected model and endpoint are both required before AI planning starts.
  bool get isConfigured => model.trim().isNotEmpty && baseUrl.trim().isNotEmpty;

  AiModelConfig copyWith({
    AiProviderKind? providerKind,
    String? label,
    String? baseUrl,
    String? model,
    bool? isCloud,
    double? temperature,
    int? maxOutputTokens,
    bool? enableVerboseReasoning,
  }) => AiModelConfig(
    providerKind: providerKind ?? this.providerKind,
    label: label ?? this.label,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    isCloud: isCloud ?? this.isCloud,
    temperature: temperature ?? this.temperature,
    maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
    enableVerboseReasoning:
        enableVerboseReasoning ?? this.enableVerboseReasoning,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'providerKind': providerKind.name,
    'label': label,
    'baseUrl': baseUrl,
    'model': model,
    'isCloud': isCloud,
    'temperature': temperature,
    'maxOutputTokens': maxOutputTokens,
    'enableVerboseReasoning': enableVerboseReasoning,
  };

  factory AiModelConfig.fromJson(Map<String, Object?> json) {
    return AiModelConfig(
      providerKind: AiProviderKind.values.firstWhere(
        (kind) => kind.name == json['providerKind'],
        orElse: () => AiProviderKind.openAiCompatible,
      ),
      label: (json['label'] as String?) ?? defaultLabel,
      baseUrl: (json['baseUrl'] as String?) ?? defaultBaseUrl,
      model: (json['model'] as String?) ?? '',
      isCloud: (json['isCloud'] as bool?) ?? false,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.1,
      maxOutputTokens: _safeMaxOutputTokens(json['maxOutputTokens']),
      enableVerboseReasoning:
          (json['enableVerboseReasoning'] as bool?) ?? false,
    );
  }

  static int _safeMaxOutputTokens(Object? value) {
    final parsed = (value as num?)?.toInt() ?? defaultMaxOutputTokens;
    // Migrate the two client defaults used before the setting was exposed.
    // A user-selected value is preserved; only these known legacy defaults
    // are upgraded to the current 128K budget.
    if (parsed == 1200 || parsed == 8192) return defaultMaxOutputTokens;
    return parsed.clamp(256, maxOutputTokenLimit);
  }

  String encode() => jsonEncode(toJson());
}

enum AiWorkflow { loginFullSequence, orderCashPayment }

enum AiPlanState { needsInput, readyForConfirmation, unsupported }

enum AiItemStrategy { sameForAll, perOrder }

/// Declares where an AI plan gets executable inputs. Settings-backed plans
/// are used by slash commands; conversational plans retain the user's
/// explicitly supplied order items. Login credentials are never carried here.
enum AiInputSource { settings, user }

/// The purpose of an assistant response. Only [plan] responses with a ready
/// plan are eligible for execution; every other kind is informational.
enum AiAssistantResponseKind { plan, knowledge, clarification, blocked }

/// A compact, transport-safe section of a catalogue-backed answer.
///
/// The UI may render this as cards or a table later. Keeping it in the domain
/// response means common QA questions do not require a model or UI scraping.
class AiKnowledgeSection {
  const AiKnowledgeSection({
    required this.title,
    this.body,
    this.items = const <String>[],
  });

  final String title;
  final String? body;
  final List<String> items;
}

/// The reading direction of a safe, declarative flow chart.
enum AiKnowledgeDiagramDirection { topToBottom, leftToRight }

/// The semantic role of a diagram node. The renderer uses this to distinguish
/// decisions from ordinary process steps without accepting executable markup.
enum AiKnowledgeDiagramNodeKind { start, process, decision, end }

/// A safe, declarative flow chart. It intentionally does not accept arbitrary
/// Mermaid/HTML/JavaScript, so a model response cannot inject content into the
/// desktop UI.
class AiKnowledgeDiagram {
  const AiKnowledgeDiagram({
    required this.title,
    required this.nodes,
    this.edges = const <AiKnowledgeDiagramEdge>[],
    this.direction = AiKnowledgeDiagramDirection.topToBottom,
  });

  final String title;
  final List<AiKnowledgeDiagramNode> nodes;
  final List<AiKnowledgeDiagramEdge> edges;
  final AiKnowledgeDiagramDirection direction;
}

class AiKnowledgeDiagramNode {
  const AiKnowledgeDiagramNode({
    this.id = '',
    required this.label,
    this.detail,
    this.kind = AiKnowledgeDiagramNodeKind.process,
  });

  /// Stable node identity used exclusively by [AiKnowledgeDiagramEdge].
  final String id;
  final String label;
  final String? detail;
  final AiKnowledgeDiagramNodeKind kind;
}

/// A labelled connection between two declared diagram nodes.
class AiKnowledgeDiagramEdge {
  const AiKnowledgeDiagramEdge({
    required this.fromNodeId,
    required this.toNodeId,
    this.label,
  });

  final String fromNodeId;
  final String toNodeId;
  final String? label;
}

/// Structured, non-executable answer content for QA catalogue questions.
class AiKnowledgeAnswer {
  const AiKnowledgeAnswer({
    required this.title,
    required this.summary,
    this.sections = const <AiKnowledgeSection>[],
    this.sources = const <String>[],
    this.diagrams = const <AiKnowledgeDiagram>[],
    this.suiteIds = const <String>[],
  });

  final String title;
  final String summary;
  final List<AiKnowledgeSection> sections;
  final List<String> sources;
  final List<AiKnowledgeDiagram> diagrams;

  /// Canonical catalogue identities represented by this answer. This is safe
  /// chat context, allowing follow-ups such as "show the above as a diagram"
  /// to remain scoped to the user's previous selection.
  final List<String> suiteIds;
}

/// A validated, provider-independent plan that can be translated into a QA
/// suite. This stays declarative; execution happens only in the dashboard.
class AiTestPlan {
  const AiTestPlan({
    required this.workflow,
    required this.profileId,
    this.repeatCount = 1,
    this.ordersCount = 1,
    this.executionSteps = const <String>[],
    this.itemStrategy = AiItemStrategy.sameForAll,
    this.items = const <OrderItem>[],
    this.perIterationItems = const <int, List<OrderItem>>{},
    this.loginCaseIds = const <String>[],
    this.inputSource = AiInputSource.user,
    this.overrideSettingsOrderCount = false,
    this.loginCases = const <LoginTestCaseDefinition>[],
  });

  final AiWorkflow workflow;
  final String profileId;
  final int repeatCount;
  final int ordersCount;

  /// Ordered, user-visible steps produced by the planner. The UI must render
  /// this list rather than maintaining a second hardcoded workflow description.
  final List<String> executionSteps;
  final AiItemStrategy itemStrategy;
  final List<OrderItem> items;
  final Map<int, List<OrderItem>> perIterationItems;

  /// IDs of the profile-scoped login rows selected for this plan. Credentials
  /// are deliberately not copied into an AI plan; the dashboard resolves the
  /// matching definitions from the login-case repository immediately before
  /// execution.
  final List<String> loginCaseIds;
  final AiInputSource inputSource;

  /// Whether an AI Settings-backed order request explicitly supplied an
  /// order count. When false, the saved Order Inputs count remains
  /// authoritative so a bare order request behaves exactly like Manual mode.
  final bool overrideSettingsOrderCount;
  final List<LoginTestCaseDefinition> loginCases;

  bool get isOrder => workflow == AiWorkflow.orderCashPayment;

  /// Flattens shared and per-order items for input validation.
  Iterable<OrderItem> get allItems sync* {
    yield* items;
    for (final orderItems in perIterationItems.values) {
      yield* orderItems;
    }
  }

  AiTestPlan copyWith({
    String? profileId,
    int? ordersCount,
    AiItemStrategy? itemStrategy,
    List<OrderItem>? items,
    Map<int, List<OrderItem>>? perIterationItems,
    AiInputSource? inputSource,
    bool? overrideSettingsOrderCount,
    List<LoginTestCaseDefinition>? loginCases,
    List<String>? executionSteps,
  }) => AiTestPlan(
    workflow: workflow,
    profileId: profileId ?? this.profileId,
    repeatCount: repeatCount,
    ordersCount: ordersCount ?? this.ordersCount,
    executionSteps: executionSteps ?? this.executionSteps,
    itemStrategy: itemStrategy ?? this.itemStrategy,
    items: items ?? this.items,
    perIterationItems: perIterationItems ?? this.perIterationItems,
    loginCaseIds: loginCaseIds,
    inputSource: inputSource ?? this.inputSource,
    overrideSettingsOrderCount:
        overrideSettingsOrderCount ?? this.overrideSettingsOrderCount,
    loginCases: loginCases ?? this.loginCases,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'workflow': workflow.name,
    'profileId': profileId,
    'repeatCount': repeatCount,
    'ordersCount': ordersCount,
    'executionSteps': executionSteps,
    'itemStrategy': itemStrategy.name,
    'items': items.map((item) => item.toJson()).toList(),
    'perIterationItems': perIterationItems.map(
      (key, value) =>
          MapEntry(key.toString(), value.map((item) => item.toJson()).toList()),
    ),
    'loginCaseIds': loginCaseIds,
    'inputSource': inputSource.name,
    'overrideSettingsOrderCount': overrideSettingsOrderCount,
  };

  factory AiTestPlan.fromJson(Map<String, Object?> json) {
    final perIterationItems = _parsePerIterationItems(
      json['perIterationItems'] ?? json['per_iteration_items'],
    );
    final parsedItems = _parseItems(json['items']);
    final rawStrategy =
        (json['itemStrategy'] ?? json['item_strategy']) as String?;
    final requestedStrategy = AiItemStrategy.values.firstWhere(
      (strategy) =>
          strategy.name.toLowerCase() ==
          rawStrategy?.toLowerCase().replaceAll('_', ''),
      orElse: () => AiItemStrategy.sameForAll,
    );

    final rawWorkflow = (json['workflow'] ?? json['workflow_name']) as String?;
    final resolvedWorkflow = AiWorkflow.values.firstWhere(
      (workflow) =>
          workflow.name.toLowerCase() ==
          rawWorkflow?.toLowerCase().replaceAll('_', ''),
      orElse: () => AiWorkflow.loginFullSequence,
    );

    final profileId =
        ((json['profileId'] ?? json['profile_id'] ?? json['profile'])
                as String?)
            ?.trim() ??
        '';
    final repeatCount =
        (((json['repeatCount'] ?? json['repeat_count']) as num?)?.toInt() ?? 1)
            .clamp(1, 50);
    final ordersCount =
        (((json['ordersCount'] ?? json['orders_count'] ?? json['order_count'])
                        as num?)
                    ?.toInt() ??
                1)
            .clamp(1, 50);
    final rawInputSource =
        (json['inputSource'] ?? json['input_source']) as String?;
    final resolvedInputSource = AiInputSource.values.firstWhere(
      (source) =>
          source.name.toLowerCase() ==
          rawInputSource?.toLowerCase().replaceAll('_', ''),
      orElse: () => AiInputSource.user,
    );

    final rawExecutionSteps = json['executionSteps'] ?? json['execution_steps'];
    final rawLoginCaseIds = json['loginCaseIds'] ?? json['login_case_ids'];

    return AiTestPlan(
      workflow: resolvedWorkflow,
      profileId: profileId,
      repeatCount: repeatCount,
      ordersCount: ordersCount,
      executionSteps: (rawExecutionSteps is List)
          ? rawExecutionSteps
                .whereType<String>()
                .map((step) => step.trim())
                .where((step) => step.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
      itemStrategy: perIterationItems.isNotEmpty
          ? AiItemStrategy.perOrder
          : requestedStrategy,
      items: parsedItems,
      perIterationItems: perIterationItems,
      loginCaseIds: (rawLoginCaseIds is List)
          ? rawLoginCaseIds
                .whereType<String>()
                .map((id) => id.trim())
                .where((id) => id.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
      inputSource: resolvedInputSource,
      overrideSettingsOrderCount:
          (json['overrideSettingsOrderCount'] ??
              json['override_settings_order_count']) ==
          true,
    );
  }

  static List<OrderItem> _parseItems(Object? raw) {
    final values = raw is List
        ? raw
        : raw is Map
        ? <Object?>[raw]
        : const <Object?>[];
    return values
        .map(_parseItem)
        .whereType<OrderItem>()
        .toList(growable: false);
  }

  static OrderItem? _parseItem(Object? raw) {
    if (raw is Map) {
      return OrderItem.fromJson(raw.cast<String, Object?>());
    }
    // Accept the compact tuple shape occasionally produced by models:
    // [skuCode, type, weight, entryMode]. It is normalized immediately.
    if (raw is List && raw.isNotEmpty) {
      final weight = raw.length > 2 && raw[2] is num
          ? (raw[2] as num).toDouble()
          : double.tryParse(raw.length > 2 ? '${raw[2]}' : '');
      return OrderItem.fromJson(<String, Object?>{
        'skuCode': '${raw.first}',
        if (raw.length > 1) 'type': '${raw[1]}',
        'weight': ?weight,
        if (raw.length > 3) 'entryMode': '${raw[3]}',
      });
    }
    return null;
  }

  static Map<int, List<OrderItem>> _parsePerIterationItems(Object? raw) {
    final result = <int, List<OrderItem>>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final iteration = int.tryParse('${entry.key}');
        if (iteration == null) continue;
        result[iteration] = _parseItems(entry.value);
      }
      return result;
    }
    // Normalize the manual-mode shape: [{"order": 1, "items": [...]}].
    if (raw is List) {
      for (final value in raw.whereType<Map>()) {
        final iteration = int.tryParse(
          '${value['order'] ?? value['iteration'] ?? value['orderNumber'] ?? ''}',
        );
        if (iteration == null) continue;
        result[iteration] = _parseItems(value['items']);
      }
    }
    return result;
  }
}

/// Exception thrown when an AI planning request or operation is cancelled.
class OperationCanceledException implements Exception {
  const OperationCanceledException([this.message = 'Operation was cancelled.']);
  final String message;

  @override
  String toString() => 'OperationCanceledException: $message';
}

/// Token for active request cancellation across UI, orchestrator, and model provider.
class CancellationToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  final List<void Function()> _listeners = <void Function()>[];

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    for (final listener in List<void Function()>.from(_listeners)) {
      listener();
    }
    _listeners.clear();
  }

  void onCancel(void Function() listener) {
    if (_isCancelled) {
      listener();
      return;
    }
    _listeners.add(listener);
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }
}

/// Handle tracking active planning generations and cancellation tokens.
class PlanningRequestHandle {
  PlanningRequestHandle({
    required this.generationId,
    CancellationToken? cancelToken,
  }) : cancelToken = cancelToken ?? CancellationToken();

  final int generationId;
  final CancellationToken cancelToken;

  bool get isCancelled => cancelToken.isCancelled;
  void cancel() => cancelToken.cancel();
}

/// Structured pending context for multi-turn slot filling.
class AiPendingRequest {
  const AiPendingRequest({
    required this.workflow,
    required this.missingFields,
    this.ordersCount = 1,
    this.profileId,
    this.skuCodes = const <String>[],
    this.itemType,
    this.entryMode,
    this.itemStrategy,
    this.partialPlan,
  });

  final AiWorkflow workflow;
  final List<String> missingFields;
  final int ordersCount;
  final String? profileId;
  final List<String> skuCodes;
  final SkuItemType? itemType;
  final ItemEntryMode? entryMode;
  final AiItemStrategy? itemStrategy;
  final AiTestPlan? partialPlan;

  AiPendingRequest copyWith({
    List<String>? missingFields,
    int? ordersCount,
    String? profileId,
    List<String>? skuCodes,
    SkuItemType? itemType,
    ItemEntryMode? entryMode,
    AiItemStrategy? itemStrategy,
    AiTestPlan? partialPlan,
  }) => AiPendingRequest(
    workflow: workflow,
    missingFields: missingFields ?? this.missingFields,
    ordersCount: ordersCount ?? this.ordersCount,
    profileId: profileId ?? this.profileId,
    skuCodes: skuCodes ?? this.skuCodes,
    itemType: itemType ?? this.itemType,
    entryMode: entryMode ?? this.entryMode,
    itemStrategy: itemStrategy ?? this.itemStrategy,
    partialPlan: partialPlan ?? this.partialPlan,
  );
}

/// Result returned by either the shortcut parser or the model planner.
class AiAssistantResponse {
  const AiAssistantResponse({
    required this.message,
    required this.state,
    this.plan,
    this.missingFields = const <String>[],
    this.kind = AiAssistantResponseKind.plan,
    this.knowledge,
    this.richContent,
    this.pendingRequest,
  });

  final String message;
  final AiPlanState state;
  final AiTestPlan? plan;
  final List<String> missingFields;
  final AiAssistantResponseKind kind;
  final AiKnowledgeAnswer? knowledge;
  final AiRichContent? richContent;
  final AiPendingRequest? pendingRequest;

  /// Execution is intentionally opt-in. Informational answers, clarifications
  /// and blocks can never be promoted to driver input by a UI consumer.
  bool get canExecute =>
      kind == AiAssistantResponseKind.plan &&
      state == AiPlanState.readyForConfirmation &&
      plan != null;

  factory AiAssistantResponse.knowledge({
    required String message,
    required AiKnowledgeAnswer knowledge,
  }) => AiAssistantResponse(
    message: message,
    state: AiPlanState.needsInput,
    kind: AiAssistantResponseKind.knowledge,
    knowledge: knowledge,
  );

  factory AiAssistantResponse.fromJson(Map<String, Object?> json) {
    final planRaw = json['plan'];
    final plan = _parsePlan(planRaw);
    final requestedKind = AiAssistantResponseKind.values.firstWhere(
      (kind) => kind.name == json['kind'],
      // Keep existing provider contracts working: plans are plans, and a
      // response without one is a clarification.
      orElse: () => plan == null
          ? AiAssistantResponseKind.clarification
          : AiAssistantResponseKind.plan,
    );
    final knowledge = _parseKnowledge(json['knowledge']);
    final rawMessage = (json['message'] as String?)?.trim();
    final defaultMessage = knowledge != null
        ? 'Coverage and scenario overview for your request:'
        : 'I could not create a safe QA plan from that request.';
    return AiAssistantResponse(
      message: (rawMessage != null && rawMessage.isNotEmpty)
          ? rawMessage
          : defaultMessage,
      state: AiPlanState.values.firstWhere(
        (state) => state.name == json['state'],
        orElse: () => AiPlanState.needsInput,
      ),
      plan: requestedKind == AiAssistantResponseKind.plan ? plan : null,
      missingFields:
          (json['missingFields'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(),
      kind: requestedKind,
      knowledge: knowledge,
    );
  }

  static AiTestPlan? _parsePlan(Object? raw) {
    if (raw is Map) return AiTestPlan.fromJson(raw.cast<String, Object?>());
    // Some OpenAI-compatible local models wrap the sole plan in an array.
    if (raw is List) {
      for (final plan in raw.whereType<Map>()) {
        return AiTestPlan.fromJson(plan.cast<String, Object?>());
      }
    }
    return null;
  }

  static AiKnowledgeAnswer? _parseKnowledge(Object? raw) {
    if (raw is! Map) return null;
    final value = raw.cast<String, Object?>();
    final title = (value['title'] as String?)?.trim();
    final summary = (value['summary'] as String?)?.trim();
    if (title == null || title.isEmpty || summary == null || summary.isEmpty) {
      return null;
    }
    final sections = (value['sections'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((section) {
          final item = section.cast<String, Object?>();
          final sectionTitle = (item['title'] as String?)?.trim();
          if (sectionTitle == null || sectionTitle.isEmpty) return null;
          return AiKnowledgeSection(
            title: sectionTitle,
            body: (item['body'] as String?)?.trim(),
            items: (item['items'] as List<dynamic>? ?? const <dynamic>[])
                .whereType<String>()
                .toList(growable: false),
          );
        })
        .whereType<AiKnowledgeSection>()
        .toList(growable: false);
    return AiKnowledgeAnswer(
      title: title,
      summary: summary,
      sections: sections,
      sources: (value['sources'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
      diagrams: _parseKnowledgeDiagrams(value['diagrams']),
      suiteIds: (value['suiteIds'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
    );
  }

  static List<AiKnowledgeDiagram> _parseKnowledgeDiagrams(Object? raw) {
    if (raw is! List) return const <AiKnowledgeDiagram>[];
    return raw
        .whereType<Map>()
        .map((diagram) {
          final value = diagram.cast<String, Object?>();
          final title = (value['title'] as String?)?.trim();
          if (title == null || title.isEmpty) return null;
          final nodes = (value['nodes'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map>()
              .indexed
              .map((entry) {
                final index = entry.$1;
                final node = entry.$2;
                final nodeValue = node.cast<String, Object?>();
                final label = (nodeValue['label'] as String?)?.trim();
                if (label == null || label.isEmpty) return null;
                final kindName = (nodeValue['kind'] as String?)?.trim();
                return AiKnowledgeDiagramNode(
                  // Older providers may not send an ID. Preserve their
                  // sequential nodes with deterministic, local identities.
                  id: (nodeValue['id'] as String?)?.trim().isNotEmpty == true
                      ? (nodeValue['id'] as String).trim()
                      : 'node_$index',
                  label: label,
                  detail: (nodeValue['detail'] as String?)?.trim(),
                  kind: AiKnowledgeDiagramNodeKind.values.firstWhere(
                    (kind) => kind.name == kindName,
                    orElse: () => AiKnowledgeDiagramNodeKind.process,
                  ),
                );
              })
              .whereType<AiKnowledgeDiagramNode>()
              .toList(growable: false);
          final nodeIds = nodes.map((node) => node.id).toSet();
          final edges = (value['edges'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map>()
              .map((edge) {
                final edgeValue = edge.cast<String, Object?>();
                final from = (edgeValue['fromNodeId'] ?? edgeValue['from'])
                    ?.toString()
                    .trim();
                final to = (edgeValue['toNodeId'] ?? edgeValue['to'])
                    ?.toString()
                    .trim();
                if (from == null ||
                    to == null ||
                    !nodeIds.contains(from) ||
                    !nodeIds.contains(to)) {
                  return null;
                }
                return AiKnowledgeDiagramEdge(
                  fromNodeId: from,
                  toNodeId: to,
                  label: (edgeValue['label'] as String?)?.trim(),
                );
              })
              .whereType<AiKnowledgeDiagramEdge>()
              .toList(growable: false);
          return nodes.isEmpty
              ? null
              : AiKnowledgeDiagram(
                  title: title,
                  nodes: nodes,
                  edges: edges,
                  direction: AiKnowledgeDiagramDirection.values.firstWhere(
                    (direction) => direction.name == value['direction'],
                    orElse: () => AiKnowledgeDiagramDirection.topToBottom,
                  ),
                );
        })
        .whereType<AiKnowledgeDiagram>()
        .toList(growable: false);
  }
}

enum AiChatRole { user, assistant, system }

// ---------------------------------------------------------------------------
// Planning phases – emitted during AI orchestration so the UI can render a
// step-by-step stepper instead of a blank wait.
// ---------------------------------------------------------------------------

/// Discrete phases the planner goes through before producing a test plan.
enum AiPlanningPhase { parsing, matching, planning, validating, complete }

/// Visible, non-executable diagnostic events from the model-planning layer.
/// They are displayed only in the Assistant UI and never become driver input.
enum AiModelEventKind { status, reasoning, response, error, executionProgress }

class AiModelEvent {
  const AiModelEvent({
    required this.kind,
    required this.message,
    this.phase,
    this.progress,
    this.executionStep,
  });

  final AiModelEventKind kind;
  final String message;

  /// Non-null when [kind] is [AiModelEventKind.status] to indicate which
  /// planning phase is currently active.
  final AiPlanningPhase? phase;

  /// Optional 0.0–1.0 value for progress bar rendering.
  final double? progress;

  /// Non-null when [kind] is [AiModelEventKind.executionProgress].
  final AiExecutionStep? executionStep;
}

typedef AiModelEventCallback = void Function(AiModelEvent event);

// ---------------------------------------------------------------------------
// Execution progress – emitted during test-run so the chat shows live
// scenario completion instead of requiring the user to open the log drawer.
// ---------------------------------------------------------------------------

enum AiScenarioStatus { pending, running, passed, failed, skipped }

class AiExecutionStep {
  const AiExecutionStep({
    required this.scenarioName,
    required this.status,
    this.elapsedMs,
    this.detail,
    this.totalScenarios = 0,
    this.completedScenarios = 0,
  });

  final String scenarioName;
  final AiScenarioStatus status;
  final int? elapsedMs;
  final String? detail;
  final int totalScenarios;
  final int completedScenarios;

  double get progressFraction =>
      totalScenarios > 0 ? completedScenarios / totalScenarios : 0.0;
}

// ---------------------------------------------------------------------------
// Rich content – allows assistant messages to carry structured cards / tables
// rather than just plain text.
// ---------------------------------------------------------------------------

/// Base class for rich content attached to an [AiChatMessage].
sealed class AiRichContent {
  const AiRichContent();
}

/// Read-only, catalogue-backed answer content. Unlike a plan, this can never
/// initiate a PenguinPOS run.
class AiRichKnowledgeAnswer extends AiRichContent {
  const AiRichKnowledgeAnswer({required this.answer});

  final AiKnowledgeAnswer answer;
}

/// A styled summary card showing the planned test profile, workflow, and
/// scenario list – rendered as a card + table in the chat.
class AiRichPlanSummary extends AiRichContent {
  const AiRichPlanSummary({
    required this.profileLabel,
    required this.workflowLabel,
    required this.scenarios,
    this.dataSourceLabel,
    this.orderItems = const <AiOrderItemRow>[],
  });

  final String profileLabel;
  final String workflowLabel;
  final List<AiScenarioRow> scenarios;
  final String? dataSourceLabel;
  final List<AiOrderItemRow> orderItems;
}

/// Final, read-only allocation shown in chat immediately before a validated
/// plan is handed to the launcher. Unlike the planning table, this groups the
/// exact items by order so operators can visually compare allocations.
class AiRichLaunchPreview extends AiRichContent {
  const AiRichLaunchPreview({
    required this.profileLabel,
    required this.workflowLabel,
    required this.orders,
    this.dataSourceLabel,
    this.allocationModeLabel,
    this.steps = const <String>[],
    this.loginCases = const <LoginTestCaseDefinition>[],
  });

  final String profileLabel;
  final String workflowLabel;
  final List<AiOrderLaunchPreview> orders;
  final String? dataSourceLabel;
  final String? allocationModeLabel;
  final List<String> steps;
  final List<LoginTestCaseDefinition> loginCases;

  int get totalItems =>
      orders.fold<int>(0, (count, order) => count + order.items.length);
}

class AiOrderLaunchPreview {
  const AiOrderLaunchPreview({required this.orderNumber, required this.items});

  final int orderNumber;
  final List<AiOrderItemRow> items;
}

class AiOrderItemRow {
  const AiOrderItemRow({
    required this.skuCode,
    required this.typeLabel,
    required this.entryModeLabel,
    required this.allocationLabel,
    this.weight,
    this.weightLabel,
    this.weightInputModeLabel,
  });

  final String skuCode;
  final String typeLabel;
  final String entryModeLabel;
  final String allocationLabel;
  final double? weight;
  final String? weightLabel;
  final String? weightInputModeLabel;

  factory AiOrderItemRow.fromOrderItem(
    OrderItem item, {
    String allocationLabel = '',
  }) {
    final typeLabel = switch (item.type) {
      SkuItemType.bizerba => 'Bizerba SKU',
      SkuItemType.weighed => 'Weighed SKU',
      SkuItemType.nonWeighed => 'Non-Weighed SKU',
    };

    final entryModeLabel = item.effectiveEntryMode == ItemEntryMode.scan
        ? 'Scan (Barcode)'
        : (item.effectiveEntryMode == ItemEntryMode.manualQwerty
              ? 'Manual QWERTY'
              : 'Manual Numpad');

    String weightLabel = '—';
    if (item.type == SkuItemType.bizerba) {
      final bizerbaWeight = OrderItem.extractBizerbaWeight(item.skuCode);
      if (bizerbaWeight != null) {
        weightLabel = '$bizerbaWeight kg';
      } else {
        weightLabel = 'Auto';
      }
    } else if (item.type == SkuItemType.weighed) {
      if (item.weight != null) {
        weightLabel = '${item.weight} kg';
      } else if (item.weightInputMode == WeightInputMode.auto) {
        weightLabel = 'Auto';
      } else {
        weightLabel = 'Manual';
      }
    }

    return AiOrderItemRow(
      skuCode: item.skuCode,
      typeLabel: typeLabel,
      entryModeLabel: entryModeLabel,
      allocationLabel: allocationLabel,
      weight: item.weight,
      weightLabel: weightLabel,
      weightInputModeLabel: item.weightInputMode.label,
    );
  }

  String get effectiveWeightLabel {
    if (weightLabel != null && weightLabel!.isNotEmpty) {
      return weightLabel!;
    }
    if (weight != null) {
      return '$weight kg';
    }
    final normalized = typeLabel.toLowerCase();
    if (normalized.contains('bizerba')) {
      final bizerbaWeight = OrderItem.extractBizerbaWeight(skuCode);
      return bizerbaWeight != null ? '$bizerbaWeight kg' : 'Auto';
    }
    if (normalized.contains('weighed') && !normalized.contains('non')) {
      if (weightInputModeLabel?.toLowerCase().contains('manual') ?? false) {
        return 'Manual';
      }
      return 'Auto';
    }
    return '—';
  }
}

class AiScenarioRow {
  const AiScenarioRow({required this.name, this.status = 'Pending'});

  final String name;
  final String status;
}

/// A pass/fail test-execution report card with scenario-level results, timing,
/// and totals – rendered as a rich table in the chat.
class AiRichTestReport extends AiRichContent {
  const AiRichTestReport({
    required this.suiteTitle,
    required this.profileLabel,
    required this.passed,
    required this.totalDurationMs,
    required this.scenarioResults,
    this.cleanupPassed,
    this.cleanupDetail,
  });

  final String suiteTitle;
  final String profileLabel;
  final bool passed;
  final int totalDurationMs;
  final List<AiScenarioResult> scenarioResults;
  final bool? cleanupPassed;
  final String? cleanupDetail;

  int get passedCount => scenarioResults.where((s) => s.passed).length;
  int get failedCount => scenarioResults.where((s) => !s.passed).length;
}

/// Login report shared by the AI chat and Manual output surfaces.
class AiRichLoginReport extends AiRichContent {
  const AiRichLoginReport({
    required this.suiteTitle,
    required this.profileLabel,
    required this.suite,
    this.cleanupPassed,
    this.cleanupDetail,
  });

  final String suiteTitle;
  final String profileLabel;
  final LoginSuiteResult suite;
  final bool? cleanupPassed;
  final String? cleanupDetail;
}

/// Per-order outcomes for an order suite. These are kept separate from the
/// suite checks so a two-order request visibly produces two order results.
class AiRichOrderReport extends AiRichContent {
  const AiRichOrderReport({
    required this.suiteTitle,
    required this.profileLabel,
    required this.passed,
    required this.totalDurationMs,
    required this.orders,
    required this.testChecks,
    this.aggregateTotalPayable = 0,
    this.aggregatePayableAmount = 0,
  });

  final String suiteTitle;
  final String profileLabel;
  final bool passed;
  final int totalDurationMs;
  final List<AiOrderResult> orders;
  final List<AiScenarioResult> testChecks;
  final double aggregateTotalPayable;
  final int aggregatePayableAmount;

  int get passedCount => orders.where((order) => order.passed).length;
}

class AiOrderResult {
  const AiOrderResult({
    required this.orderNumber,
    required this.itemSummary,
    required this.passed,
    required this.durationMs,
    required this.cashAmount,
    this.totalPayable = 0,
    this.skuResults = const <AiOrderSkuResult>[],
    this.stageResults = const <AiOrderStageResult>[],
    this.orderNumberLabel,
    this.error,
  });

  final int orderNumber;
  final String itemSummary;
  final bool passed;
  final int durationMs;
  final int cashAmount;
  final double totalPayable;
  final List<AiOrderSkuResult> skuResults;
  final List<AiOrderStageResult> stageResults;
  final String? orderNumberLabel;
  final String? error;
}

class AiOrderSkuResult {
  const AiOrderSkuResult({
    required this.sku,
    required this.type,
    required this.entryMode,
    required this.passed,
    this.weight,
    this.error,
  });

  final String sku;
  final String type;
  final String entryMode;
  final bool passed;
  final double? weight;
  final String? error;
}

class AiOrderStageResult {
  const AiOrderStageResult({
    required this.name,
    required this.passed,
    this.details,
  });

  final String name;
  final bool passed;
  final String? details;
}

/// A compact, user-safe record of how the application prepared a request.
/// This intentionally contains only application status steps, never model
/// reasoning or hidden instructions.
class AiRichPlanningSummary extends AiRichContent {
  const AiRichPlanningSummary({
    required this.steps,
    this.failedStep,
    this.elapsedMs,
    this.rawContent,
    this.reasoning,
  });

  final List<String> steps;
  final int? failedStep;
  final int? elapsedMs;
  final String? rawContent;
  final String? reasoning;
}

/// Approved declarative UI content for live QA execution evidence in chat.
/// The document is parsed and validated by [QaGenUiDocument.tryParse] before
/// it reaches this model; it cannot contain arbitrary Flutter widgets.
class AiRichGenUi extends AiRichContent {
  const AiRichGenUi({required this.document});

  final QaGenUiDocument document;
}

class AiScenarioResult {
  const AiScenarioResult({
    required this.name,
    required this.passed,
    required this.durationMs,
    this.detail,
    this.children = const <AiScenarioResult>[],
  });

  final String name;
  final bool passed;
  final int durationMs;
  final String? detail;
  final List<AiScenarioResult> children;
}

// ---------------------------------------------------------------------------
// Chat message – now includes an optional [richContent] for structured
// rendering in the message list.
// ---------------------------------------------------------------------------

class AiChatMessage {
  AiChatMessage({
    required this.role,
    required this.text,
    this.richContent,
    this.activitySummary,
    this.pendingRequest,
    this.executablePlan,
    DateTime? at,
  }) : at = at ?? DateTime.now();

  final AiChatRole role;
  final String text;
  final DateTime at;

  /// When non-null, the message list renders a structured card/table instead
  /// of plain [SelectableText].
  final AiRichContent? richContent;

  /// Safe activity retained beneath the completed result. This is separate
  /// from [richContent] so a knowledge answer can keep both its result and an
  /// expandable "what I checked" transcript.
  final AiRichPlanningSummary? activitySummary;

  /// Structured pending context for multi-turn slot filling.
  final AiPendingRequest? pendingRequest;

  /// The reviewed plan attached to this message. It is deliberately kept
  /// separate from [richContent]: cards are presentation data, whereas this
  /// remains the declarative input passed to an explicitly chosen run/edit
  /// action.
  final AiTestPlan? executablePlan;
}
