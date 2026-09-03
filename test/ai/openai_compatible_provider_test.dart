import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/ai/providers/openai_compatible_provider.dart';

void main() {
  test('uses configured token budget and verbose reasoning mode', () async {
    Map<String, Object?>? capturedBody;
    final client = MockClient((request) async {
      capturedBody = (jsonDecode(request.body) as Map).cast<String, Object?>();
      final responsePayload = jsonEncode(<String, Object?>{
        'choices': <Object?>[
          <String, Object?>{
            'delta': <String, Object?>{'content': '{"message":"Plan ready"}'},
            'finish_reason': 'stop',
          },
        ],
      });
      return http.Response(
        'data: $responsePayload\n\ndata: [DONE]\n\n',
        200,
        headers: const <String, String>{'content-type': 'text/event-stream'},
      );
    });
    final provider = OpenAiCompatibleProvider(
      config: const AiModelConfig(
        model: 'gemma4:e4',
        maxOutputTokens: AiModelConfig.maxOutputTokenLimit,
        enableVerboseReasoning: true,
      ),
      apiKey: '',
      client: client,
    );

    final result = await provider.completeJson(
      systemPrompt: 'Return JSON.',
      messages: <AiChatMessage>[
        AiChatMessage(role: AiChatRole.user, text: 'Plan an order'),
      ],
    );

    expect(result, '{"message":"Plan ready"}');
    expect(capturedBody?['max_tokens'], AiModelConfig.maxOutputTokenLimit);
    expect(capturedBody?['reasoning_effort'], 'medium');
  });
}
