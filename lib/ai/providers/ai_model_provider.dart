import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';

abstract interface class AiModelProvider {
  Future<List<String>> listModels();

  Future<String> completeJson({
    required String systemPrompt,
    required List<AiChatMessage> messages,
    CancellationToken? cancelToken,
    AiModelEventCallback? onEvent,
  });
}
