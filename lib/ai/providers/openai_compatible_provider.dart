import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/ai/providers/ai_model_provider.dart';

/// Works with Ollama, LM Studio, and cloud services exposing /v1/chat/completions.
class OpenAiCompatibleProvider implements AiModelProvider {
  OpenAiCompatibleProvider({
    required this.config,
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final AiModelConfig config;
  final String apiKey;
  final http.Client _client;
  final bool _ownsClient;

  Uri _endpoint(String suffix) {
    final base = config.baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/$suffix');
    final isLoopback =
        uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1';
    if (!config.isCloud && !isLoopback) {
      throw ArgumentError(
        'Local model endpoints must use localhost, 127.0.0.1, or ::1.',
      );
    }
    if (config.isCloud && uri.scheme != 'https') {
      throw ArgumentError('Cloud model endpoints must use HTTPS.');
    }
    return uri;
  }

  Map<String, String> get _headers => <String, String>{
    'content-type': 'application/json',
    if (apiKey.trim().isNotEmpty) 'authorization': 'Bearer ${apiKey.trim()}',
  };

  @override
  Future<List<String>> listModels() async {
    final response = await _client
        .get(_endpoint('models'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Model server returned HTTP ${response.statusCode}.');
    }
    final payload = jsonDecode(response.body);
    final models = payload is Map ? payload['data'] : null;
    if (models is! List) return const <String>[];
    return models
        .whereType<Map>()
        .map((model) => model['id'] as String?)
        .whereType<String>()
        .where((model) => model.isNotEmpty)
        .toList();
  }

  @override
  Future<String> completeJson({
    required String systemPrompt,
    required List<AiChatMessage> messages,
    CancellationToken? cancelToken,
    AiModelEventCallback? onEvent,
  }) async {
    if (cancelToken?.isCancelled ?? false) {
      throw const OperationCanceledException(
        'Planning request was cancelled before start.',
      );
    }

    if (!config.isConfigured) {
      throw StateError(
        'Configure an AI model before using natural-language chat.',
      );
    }

    StreamSubscription<String>? streamSubscription;

    void onCancel() {
      streamSubscription?.cancel();
      if (_ownsClient) {
        _client.close();
      }
    }

    cancelToken?.onCancel(onCancel);

    try {
      onEvent?.call(
        const AiModelEvent(
          kind: AiModelEventKind.status,
          message: 'Connecting to the configured model…',
        ),
      );
      final request = http.Request('POST', _endpoint('chat/completions'))
        ..headers.addAll(_headers)
        ..body = jsonEncode(<String, Object?>{
          'model': config.model,
          'temperature': config.temperature,
          // The configured value defaults to the model's 128K budget. The
          // server remains the final capability cap and may return
          // finish_reason=length when its context/runtime is smaller.
          'max_tokens': config.maxOutputTokens.clamp(
            256,
            AiModelConfig.maxOutputTokenLimit,
          ),
          'response_format': const <String, String>{'type': 'json_object'},
          'reasoning_effort': config.enableVerboseReasoning ? 'medium' : 'none',
          'stream': true,
          'messages': <Map<String, String>>[
            <String, String>{'role': 'system', 'content': systemPrompt},
            ...messages.map(
              (message) => <String, String>{
                'role': switch (message.role) {
                  AiChatRole.user => 'user',
                  AiChatRole.assistant => 'assistant',
                  AiChatRole.system => 'system',
                },
                'content': message.text,
              },
            ),
          ],
        });
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 45));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        if (cancelToken?.isCancelled ?? false) {
          throw const OperationCanceledException(
            'Planning request was cancelled.',
          );
        }
        onEvent?.call(
          AiModelEvent(
            kind: AiModelEventKind.error,
            message: 'Model server returned HTTP ${response.statusCode}.',
          ),
        );
        throw StateError(
          'Model server returned HTTP ${response.statusCode}: $body',
        );
      }

      onEvent?.call(
        const AiModelEvent(
          kind: AiModelEventKind.status,
          message:
              'Structured-plan mode is preparing a fast validated response…',
        ),
      );
      final stopwatch = Stopwatch()..start();
      const idleTimeout = Duration(seconds: 15);
      const totalDeadline = Duration(seconds: 45);

      final timedByteStream = response.stream.timeout(
        idleTimeout,
        onTimeout: (sink) {
          sink.addError(
            TimeoutException(
              'Model stream idle timeout: no data received for 15 seconds.',
            ),
          );
          sink.close();
        },
      );
      final result = StringBuffer();
      String? finishReason;
      var emittedProfile = false;
      var emittedOrders = false;
      var emittedItems = false;
      var emittedSteps = false;

      final linesStream = timedByteStream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      final completer = Completer<void>();

      streamSubscription = linesStream.listen(
        (line) {
          if (cancelToken?.isCancelled ?? false) return;
          if (stopwatch.elapsed > totalDeadline) {
            completer.completeError(
              TimeoutException(
                'Model stream total deadline exceeded (45 seconds).',
              ),
            );
            return;
          }
          if (!line.startsWith('data: ')) return;
          final data = line.substring('data: '.length).trim();
          if (data == '[DONE]' || data.isEmpty) return;
          final payload = jsonDecode(data);
          final choices = payload is Map ? payload['choices'] : null;
          if (choices is! List || choices.isEmpty || choices.first is! Map) {
            return;
          }
          final choice = choices.first as Map;
          finishReason ??= choice['finish_reason'] as String?;
          final delta = choice['delta'];
          if (delta is! Map) return;
          final reasoning = delta['reasoning'] ?? delta['reasoning_content'];
          if (reasoning is String && reasoning.isNotEmpty) {
            onEvent?.call(
              AiModelEvent(
                kind: AiModelEventKind.reasoning,
                message: reasoning,
              ),
            );
          }
          final content = delta['content'];
          if (content is String && content.isNotEmpty) {
            result.write(content);
            onEvent?.call(
              AiModelEvent(kind: AiModelEventKind.response, message: content),
            );

            final currentBuffer = result.toString();
            if (!emittedProfile &&
                (currentBuffer.contains('"profileId"') ||
                    currentBuffer.contains('"profile"'))) {
              emittedProfile = true;
              onEvent?.call(
                const AiModelEvent(
                  kind: AiModelEventKind.status,
                  message: 'Target profile identified…',
                  progress: 0.5,
                ),
              );
            }
            if (!emittedOrders &&
                (currentBuffer.contains('"ordersCount"') ||
                    currentBuffer.contains('"orders_count"') ||
                    currentBuffer.contains('"order_count"'))) {
              emittedOrders = true;
              onEvent?.call(
                const AiModelEvent(
                  kind: AiModelEventKind.status,
                  message: 'Synthesizing order sequence & allocation…',
                  progress: 0.65,
                ),
              );
            }
            if (!emittedItems &&
                (currentBuffer.contains('"items"') ||
                    currentBuffer.contains('"skuCode"'))) {
              emittedItems = true;
              onEvent?.call(
                const AiModelEvent(
                  kind: AiModelEventKind.status,
                  message: 'Resolving SKU items, weights & entry modes…',
                  progress: 0.75,
                ),
              );
            }
            if (!emittedSteps &&
                (currentBuffer.contains('"executionSteps"') ||
                    currentBuffer.contains('"loginCaseIds"'))) {
              emittedSteps = true;
              onEvent?.call(
                const AiModelEvent(
                  kind: AiModelEventKind.status,
                  message: 'Structuring sequential test cases…',
                  progress: 0.8,
                ),
              );
            }
          }
        },
        onError: (Object error, StackTrace st) {
          if (!completer.isCompleted) completer.completeError(error, st);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );

      await completer.future;

      if (cancelToken?.isCancelled ?? false) {
        throw const OperationCanceledException(
          'Planning request was cancelled.',
        );
      }

      if (finishReason == 'length') {
        const message =
            'The AI response exceeded the configured output token limit. '
            'Increase Max output tokens in Settings → AI Models & Endpoint, '
            'or reduce the size of the request. If it is already 128000, '
            'use a shorter prompt/history or a model with a larger context.';
        onEvent?.call(
          const AiModelEvent(kind: AiModelEventKind.error, message: message),
        );
        throw const FormatException(message);
      }

      if (result.isEmpty) {
        final message = finishReason == 'length'
            ? 'Model reached its output limit before returning the required JSON plan.'
            : 'Model response does not contain JSON content.';
        onEvent?.call(
          AiModelEvent(kind: AiModelEventKind.error, message: message),
        );
        throw FormatException(message);
      }
      onEvent?.call(
        const AiModelEvent(
          kind: AiModelEventKind.status,
          message: 'Final response received. Validating the plan JSON…',
        ),
      );
      return result.toString();
    } catch (e) {
      if (cancelToken?.isCancelled ?? false) {
        throw const OperationCanceledException(
          'Planning request was cancelled.',
        );
      }
      onEvent?.call(
        AiModelEvent(
          kind: AiModelEventKind.error,
          message: e is TimeoutException
              ? 'Model stream timed out. Please try again.'
              : 'Error reading stream from model: $e',
        ),
      );
      rethrow;
    } finally {
      cancelToken?.removeListener(onCancel);
    }
  }
}
