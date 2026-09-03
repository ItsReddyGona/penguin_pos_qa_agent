/// Safe, declarative chat content for the QA assistant.
///
/// This is deliberately a small catalog rather than arbitrary widget JSON.
/// Providers may choose presentation, but Flutter only renders component types
/// and fields declared here. Execution evidence is supplied by the runner and
/// telemetry collector, never invented by a model response.
enum QaGenUiComponentType {
  loginPlan,
  orderPlan,
  stepTimeline,
  apiSequence,
  timeoutNotice,
  resultSummary,
}

enum QaGenUiStepStatus { pending, running, passed, failed, skipped }

enum QaGenUiApiResult {
  success,
  httpError,
  connectTimeout,
  sendTimeout,
  receiveTimeout,
  connectionError,
  cancelled,
  unexpectedError,
}

/// A validated document composed only from QA catalog components.
class QaGenUiDocument {
  const QaGenUiDocument({required this.components});

  final List<QaGenUiComponent> components;

  /// Parses untrusted JSON into the approved component catalog. Invalid or
  /// unknown components are ignored, and an invalid document returns null.
  static QaGenUiDocument? tryParse(Object? value) {
    if (value is! Map) return null;
    final rawComponents = value['components'];
    if (rawComponents is! List || rawComponents.length > 24) return null;
    final components = rawComponents
        .whereType<Map>()
        .map((raw) => QaGenUiComponent.tryParse(raw.cast<Object?, Object?>()))
        .whereType<QaGenUiComponent>()
        .toList(growable: false);
    return components.isEmpty ? null : QaGenUiDocument(components: components);
  }
}

class QaGenUiComponent {
  const QaGenUiComponent({
    required this.type,
    required this.title,
    this.profileLabel,
    this.workflowLabel,
    this.steps = const <QaGenUiStep>[],
    this.apiEvents = const <QaGenUiApiEvent>[],
    this.summary,
    this.passed,
    this.timeoutResult,
    this.timeoutBudgetMs,
  });

  final QaGenUiComponentType type;
  final String title;
  final String? profileLabel;
  final String? workflowLabel;
  final List<QaGenUiStep> steps;
  final List<QaGenUiApiEvent> apiEvents;
  final String? summary;
  final bool? passed;
  final QaGenUiApiResult? timeoutResult;
  final int? timeoutBudgetMs;

  static QaGenUiComponent? tryParse(Map<Object?, Object?> raw) {
    final typeName = _safeText(raw['component'], maxLength: 48);
    final type = QaGenUiComponentType.values
        .where((value) => value.name == typeName)
        .firstOrNull;
    final title = _safeText(raw['title'], maxLength: 120);
    if (type == null || title == null) return null;

    final steps = _safeList(raw['steps'])
        .map(QaGenUiStep.tryParse)
        .whereType<QaGenUiStep>()
        .take(20)
        .toList(growable: false);
    final apiEvents = _safeList(raw['events'])
        .map(QaGenUiApiEvent.tryParse)
        .whereType<QaGenUiApiEvent>()
        .take(50)
        .toList(growable: false);
    final timeoutName = _safeText(raw['timeoutResult'], maxLength: 48);

    return QaGenUiComponent(
      type: type,
      title: title,
      profileLabel: _safeText(raw['profileLabel'], maxLength: 80),
      workflowLabel: _safeText(raw['workflowLabel'], maxLength: 100),
      steps: steps,
      apiEvents: apiEvents,
      summary: _safeText(raw['summary'], maxLength: 500),
      passed: raw['passed'] as bool?,
      timeoutResult: QaGenUiApiResult.values
          .where((value) => value.name == timeoutName)
          .firstOrNull,
      timeoutBudgetMs: _safeInt(raw['timeoutBudgetMs']),
    );
  }
}

class QaGenUiStep {
  const QaGenUiStep({
    required this.label,
    required this.status,
    this.durationMs,
    this.detail,
    this.children = const <QaGenUiStep>[],
  });

  final String label;
  final QaGenUiStepStatus status;
  final int? durationMs;
  final String? detail;
  final List<QaGenUiStep> children;

  static QaGenUiStep? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final value = raw.cast<Object?, Object?>();
    final label = _safeText(value['label'], maxLength: 160);
    final statusName = _safeText(value['status'], maxLength: 24);
    final status = QaGenUiStepStatus.values
        .where((item) => item.name == statusName)
        .firstOrNull;
    if (label == null || status == null) return null;
    return QaGenUiStep(
      label: label,
      status: status,
      durationMs: _safeInt(value['durationMs']),
      detail: _safeText(value['detail'], maxLength: 300),
      children: _safeList(value['children'])
          .map(QaGenUiStep.tryParse)
          .whereType<QaGenUiStep>()
          .take(50)
          .toList(growable: false),
    );
  }
}

class QaGenUiApiEvent {
  const QaGenUiApiEvent({
    required this.method,
    required this.endpoint,
    required this.durationMs,
    required this.transport,
    required this.mode,
    required this.result,
    this.statusCode,
    this.stepId,
    this.timeoutBudgetMs,
  });

  final String method;
  final String endpoint;
  final int durationMs;
  final String transport;
  final String mode;
  final QaGenUiApiResult result;
  final int? statusCode;
  final String? stepId;
  final int? timeoutBudgetMs;

  static QaGenUiApiEvent? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final value = raw.cast<Object?, Object?>();
    final method = _safeText(value['method'], maxLength: 10);
    final endpoint = _safeRoute(value['endpoint']);
    final durationMs = _safeInt(value['durationMs']);
    final transport = _safeText(
      value['transport'],
      maxLength: 5,
    )?.toLowerCase();
    final mode = _safeText(value['mode'], maxLength: 10)?.toLowerCase();
    final resultName = _safeText(value['result'], maxLength: 48);
    final result = QaGenUiApiResult.values
        .where((item) => item.name == resultName)
        .firstOrNull;
    if (method == null ||
        endpoint == null ||
        durationMs == null ||
        (transport != 'http' && transport != 'https') ||
        (mode != 'local' && mode != 'cloud') ||
        result == null) {
      return null;
    }
    return QaGenUiApiEvent(
      method: method.toUpperCase(),
      endpoint: endpoint,
      durationMs: durationMs,
      transport: transport!,
      mode: mode!,
      result: result,
      statusCode: _safeInt(value['statusCode']),
      stepId: _safeText(value['stepId'], maxLength: 80),
      timeoutBudgetMs: _safeInt(value['timeoutBudgetMs']),
    );
  }
}

List<Object?> _safeList(Object? value) =>
    value is List ? value.cast<Object?>() : const <Object?>[];

String? _safeText(Object? value, {required int maxLength}) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty || text.length > maxLength ? null : text;
}

String? _safeRoute(Object? value) {
  final route = _safeText(value, maxLength: 240);
  if (route == null ||
      !route.startsWith('/') ||
      route.contains('?') ||
      route.contains('://')) {
    return null;
  }
  return route;
}

int? _safeInt(Object? value) {
  if (value is! num ||
      value < 0 ||
      value > 3600000 ||
      value != value.roundToDouble()) {
    return null;
  }
  return value.toInt();
}
