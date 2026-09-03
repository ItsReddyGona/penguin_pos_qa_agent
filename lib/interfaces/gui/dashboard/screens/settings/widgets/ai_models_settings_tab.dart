import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/settings_form_card.dart';

/// Tab view for configuring local Ollama or OpenAI-compatible cloud model endpoints.
class AiModelsSettingsTab extends StatelessWidget {
  const AiModelsSettingsTab({
    super.key,
    required this.isCloud,
    required this.enableVerboseReasoning,
    required this.noticeDisplayMode,
    required this.modelLabelController,
    required this.baseUrlController,
    required this.modelNameController,
    required this.maxOutputTokensController,
    required this.apiKeyController,
    required this.testingConnection,
    required this.testConnectionStatus,
    required this.onCloudToggle,
    required this.onVerboseReasoningToggle,
    required this.onNoticeDisplayModeChanged,
    required this.onTestConnection,
    required this.onSaveAiModel,
  });

  final bool isCloud;
  final bool enableVerboseReasoning;
  final QaTestNoticeDisplayMode noticeDisplayMode;
  final TextEditingController modelLabelController;
  final TextEditingController baseUrlController;
  final TextEditingController modelNameController;
  final TextEditingController maxOutputTokensController;
  final TextEditingController apiKeyController;
  final bool testingConnection;
  final String? testConnectionStatus;
  final ValueChanged<bool> onCloudToggle;
  final ValueChanged<bool> onVerboseReasoningToggle;
  final ValueChanged<QaTestNoticeDisplayMode> onNoticeDisplayModeChanged;
  final VoidCallback onTestConnection;
  final VoidCallback onSaveAiModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'AI Models & Connection Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C302E),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Connect a local Ollama endpoint or cloud OpenAI-compatible server for intelligent QA planning.',
          style: TextStyle(fontSize: 13.5, color: Color(0xFF787A76)),
        ),
        const SizedBox(height: 24),

        SettingsFormCard(
          children: <Widget>[
            Material(
              color: Colors.transparent,
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  isCloud ? 'Cloud Model Server' : 'Local Model Server',
                ),
                subtitle: Text(
                  isCloud
                      ? 'HTTPS endpoint with mandatory API Key authorization'
                      : 'Loopback endpoint (e.g. Ollama at http://127.0.0.1:11434/v1)',
                ),
                value: isCloud,
                onChanged: onCloudToggle,
              ),
            ),
            Material(
              color: Colors.transparent,
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show activity details'),
                subtitle: const Text(
                  'Displays real-time matching and planning status events in the assistant chat UI.',
                ),
                value: enableVerboseReasoning,
                onChanged: onVerboseReasoningToggle,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<QaTestNoticeDisplayMode>(
              initialValue: noticeDisplayMode,
              decoration: const InputDecoration(
                labelText: 'In-app test notices',
                helperText:
                    'Only when required shows essential milestones, expected warnings, and errors.',
                border: OutlineInputBorder(),
              ),
              items: QaTestNoticeDisplayMode.values
                  .map(
                    (mode) => DropdownMenuItem<QaTestNoticeDisplayMode>(
                      value: mode,
                      child: Text(mode.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) onNoticeDisplayModeChanged(value);
              },
            ),
            const SizedBox(height: 14),

            TextField(
              controller: modelLabelController,
              decoration: const InputDecoration(
                labelText: 'Connection Label',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: baseUrlController,
              decoration: InputDecoration(
                labelText: 'Base URL',
                hintText: isCloud
                    ? 'https://api.openai.com/v1'
                    : 'http://127.0.0.1:11434/v1',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: modelNameController,
              decoration: const InputDecoration(
                labelText: 'Model Name (e.g. qwen2.5, llama3.1, gpt-4o)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: maxOutputTokensController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max output tokens',
                helperText:
                    'Default 128000 for Gemma 4 e4b; the server may impose a lower limit.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: apiKeyController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'API Key (Optional for local models)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            if (testConnectionStatus != null) ...<Widget>[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F4F0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFC7C9C4)),
                ),
                child: Text(
                  testConnectionStatus!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF2C302E),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: testingConnection ? null : onTestConnection,
                  icon: testingConnection
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check_rounded, size: 18),
                  label: Text(
                    testingConnection ? 'Testing…' : 'Test Connection',
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF658A7A),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onSaveAiModel,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save Model Settings'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
