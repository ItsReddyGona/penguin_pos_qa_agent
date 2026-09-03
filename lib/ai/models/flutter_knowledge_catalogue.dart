import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';

/// Read-only, source-backed Flutter testing knowledge available to the QA
/// assistant. This is deliberately separate from [QaKnowledgeCatalogue],
/// whose source of truth is the runnable QA suite catalogue.
class FlutterKnowledgeCatalogue {
  const FlutterKnowledgeCatalogue._();

  static const List<_FlutterKnowledgeTopic> _topics = <_FlutterKnowledgeTopic>[
    _FlutterKnowledgeTopic(
      title: 'Flutter test layers',
      summary:
          'Use BLoC/unit tests for state machines, widget tests for individual UI interactions, integration_test for product-owned end-to-end flows, and Flutter Driver only as the existing external black-box QA adapter.',
      terms: <String>[
        'flutter testing',
        'integration test',
        'integration_test',
        'flutter driver',
        'widget test',
        'test layer',
      ],
      sections: <AiKnowledgeSection>[
        AiKnowledgeSection(
          title: 'Recommended boundary',
          items: <String>[
            'BLoC/unit: assert events, emitted states, repository calls, and errors.',
            'Widget: assert custom keypad, validation, dialog, and rendered-state behaviour.',
            'integration_test: assert complete application flows, routes, and rendered outcomes.',
            'QA Agent Flutter Driver: assert only stable, user-visible keys and text from outside the app process.',
          ],
        ),
        AiKnowledgeSection(
          title: 'Migration direction',
          body:
              'Flutter recommends integration_test for new product-owned end-to-end coverage. Retain Flutter Driver only where the external QA Agent currently depends on it.',
        ),
      ],
      sources: <String>[
        'https://docs.flutter.dev/testing/integration-tests',
        'https://docs.flutter.dev/release/breaking-changes/flutter-driver-migration',
        'https://docs.flutter.dev/testing/overview',
      ],
    ),
    _FlutterKnowledgeTopic(
      title: 'Flutter Driver capabilities and limits',
      summary:
          'Flutter Driver is a separate-process, black-box UI driver. It can find and interact with rendered widgets, but it cannot read private State, BLoC instances, arbitrary routes, or arbitrary overlay entries.',
      terms: <String>[
        'flutter driver',
        'driver finder',
        'valuekey',
        'value key',
        'requestdata',
        'driver state',
      ],
      sections: <AiKnowledgeSection>[
        AiKnowledgeSection(
          title: 'What it can assert',
          items: <String>[
            'Stable string/int ValueKeys, text, semantics, types, and descendant finders.',
            'Rendered text, screenshots, render/widget diagnostics, and command timing.',
            'Direct text input into the focused editable field.',
          ],
        ),
        AiKnowledgeSection(
          title: 'What it cannot inspect',
          items: <String>[
            'Private widget State, BLoC streams/instances, or arbitrary Navigator and Overlay internals.',
            'Every application log line or every HTTP request without an explicit app-side diagnostic contract.',
          ],
        ),
        AiKnowledgeSection(
          title: 'Safe diagnostic bridge',
          body:
              'requestData is a string request/reply bridge only. If used, make it compile-time QA-gated, versioned, read-only, narrow, and redacted; it is not required for normal automatic text entry.',
        ),
      ],
      sources: <String>[
        'https://api.flutter.dev/flutter/flutter_driver/FlutterDriver-class.html',
        'https://api.flutter.dev/flutter/flutter_driver/CommonFinders/byValueKey.html',
        'https://api.flutter.dev/flutter/flutter_driver_extension/enableFlutterDriverExtension.html',
        'https://api.flutter.dev/flutter/flutter_driver/FlutterDriver/requestData.html',
      ],
    ),
    _FlutterKnowledgeTopic(
      title: 'Flutter errors, logs, and test evidence',
      summary:
          'Framework errors flow through FlutterError.onError; unhandled asynchronous or platform errors flow through PlatformDispatcher.instance.onError. Capture redacted error evidence, screenshots, and step traces on QA failures.',
      terms: <String>[
        'flutter error',
        'error logs',
        'app logs',
        'fluttererror',
        'platformdispatcher',
        'takeexception',
        'screenshot',
        'timeline',
      ],
      sections: <AiKnowledgeSection>[
        AiKnowledgeSection(
          title: 'Application error hooks',
          items: <String>[
            'FlutterError.onError: framework callback/build/layout/paint errors.',
            'PlatformDispatcher.instance.onError: unhandled async and platform errors outside Flutter callbacks.',
            'A custom FlutterError handler should call FlutterError.presentError so console output is retained.',
          ],
        ),
        AiKnowledgeSection(
          title: 'Test evidence',
          items: <String>[
            'Widget/integration tests can retrieve expected framework exceptions with tester.takeException().',
            'integration_test supports report data, screenshots, and timeline tracing.',
            'External Driver communication logging records driver protocol traffic, not all application logs.',
          ],
        ),
      ],
      sources: <String>[
        'https://docs.flutter.dev/testing/errors',
        'https://api.flutter.dev/flutter/flutter_test/WidgetTester/takeException.html',
        'https://api.flutter.dev/flutter/package-integration_test_integration_test/IntegrationTestWidgetsFlutterBinding/takeScreenshot.html',
      ],
    ),
    _FlutterKnowledgeTopic(
      title: 'Network and API observability',
      summary:
          'Use DevTools Network for live Dart HTTP/HTTPS/WebSocket inspection. For reliable automated tests, inject the repository or HTTP client and use controlled responses; redact credentials, headers, PII, and bodies in any diagnostic output.',
      terms: <String>[
        'network',
        'api call',
        'api data',
        'dio',
        'http client',
        'http override',
        'devtools network',
      ],
      sections: <AiKnowledgeSection>[
        AiKnowledgeSection(
          title: 'Live investigation',
          body:
              'Flutter DevTools Network view can inspect dart:io HTTP/HTTPS/WebSocket traffic, including Dio traffic. Browser network inspection belongs in browser developer tools.',
        ),
        AiKnowledgeSection(
          title: 'Automated test design',
          items: <String>[
            'Inject a repository/transport or HTTP client and test request mapping and state outcomes deterministically.',
            'Use a controlled QA backend or fake client for integration runs; do not infer correctness by scraping console logs.',
            'HttpOverrides affects dart:io HttpClient only; explicit dependency injection covers all transports.',
          ],
        ),
      ],
      sources: <String>[
        'https://docs.flutter.dev/tools/devtools/network',
        'https://docs.flutter.dev/cookbook/testing/unit/mocking',
        'https://api.dart.dev/dart-io/HttpOverrides-class.html',
      ],
    ),
    _FlutterKnowledgeTopic(
      title: 'BLoC state, routes, and dialogs',
      summary:
          'Test BLoC state transitions in-process with bloc_test. For routes use NavigatorObserver in product tests; for dialogs and external QA use stable visible keys, because Flutter Driver cannot read private BLoC, Navigator, or Overlay state.',
      terms: <String>[
        'bloc',
        'bloc state',
        'bloc observer',
        'route',
        'navigation',
        'dialog',
        'overlay',
        'navigator observer',
      ],
      sections: <AiKnowledgeSection>[
        AiKnowledgeSection(
          title: 'BLoC',
          items: <String>[
            'Use blocTest to dispatch events and assert the emitted state sequence, errors, and repository calls.',
            'Use BlocObserver for redacted debug/QA transition and error telemetry.',
            'External Driver tests should assert visible outcomes, never private BLoC state.',
          ],
        ),
        AiKnowledgeSection(
          title: 'Routes and dialogs',
          items: <String>[
            'Use NavigatorObserver didPush/didPop/didReplace/didChangeTop in in-process tests.',
            'Assert a destination screen key as well as the route event.',
            'Dialogs are overlay/modal-route UI: give dialog content and actions stable keys, then assert those keys in widget, integration, or external QA tests.',
          ],
        ),
      ],
      sources: <String>[
        'https://pub.dev/packages/bloc_test',
        'https://pub.dev/documentation/bloc/latest/index.html',
        'https://api.flutter.dev/flutter/widgets/NavigatorObserver-class.html',
        'https://api.flutter.dev/flutter/material/showDialog.html',
      ],
    ),
  ];

  /// Answers a clearly Flutter-testing-focused question, or returns null so
  /// normal suite knowledge and execution planning retain their precedence.
  static AiKnowledgeAnswer? answerFor(String input) {
    final normalized = _normalize(input);
    if (normalized.isEmpty || !_isFlutterKnowledgeQuestion(normalized)) {
      return null;
    }

    final matched = _topics
        .where((topic) => topic.matches(normalized))
        .toList(growable: false);
    if (matched.isEmpty) return null;

    final selected = matched.length == 1 ? matched : matched.take(3).toList();
    return AiKnowledgeAnswer(
      title: selected.length == 1
          ? selected.single.title
          : 'Flutter QA testing knowledge',
      summary: selected.map((topic) => topic.summary).join(' '),
      sections: selected
          .expand((topic) => topic.sections)
          .toList(growable: false),
      sources: selected.expand((topic) => topic.sources).toSet().toList(),
    );
  }

  static bool _isFlutterKnowledgeQuestion(String normalized) => RegExp(
    r'\b(flutter|driver|integration|widget test|bloc|navigator|route|dialog|overlay|network|api|dio|http|error|log|devtools)\b',
  ).hasMatch(normalized);
}

class _FlutterKnowledgeTopic {
  const _FlutterKnowledgeTopic({
    required this.title,
    required this.summary,
    required this.terms,
    required this.sections,
    required this.sources,
  });

  final String title;
  final String summary;
  final List<String> terms;
  final List<AiKnowledgeSection> sections;
  final List<String> sources;

  bool matches(String normalizedInput) => terms
      .map(_normalize)
      .any((term) => term.isNotEmpty && normalizedInput.contains(term));
}

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');
