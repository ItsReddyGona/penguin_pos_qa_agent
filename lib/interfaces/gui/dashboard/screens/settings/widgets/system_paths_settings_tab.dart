import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/settings_form_card.dart';

/// Tab view displaying auto-detected system paths and execution engine protocol.
class SystemPathsSettingsTab extends StatefulWidget {
  const SystemPathsSettingsTab({
    super.key,
    required this.flutterPath,
    required this.appRoot,
    this.onSave,
  });

  final String flutterPath;
  final String appRoot;
  final Future<void> Function(String flutterPath, String appRoot)? onSave;

  @override
  State<SystemPathsSettingsTab> createState() => _SystemPathsSettingsTabState();
}

class _SystemPathsSettingsTabState extends State<SystemPathsSettingsTab> {
  late final TextEditingController _flutterPathController;
  late final TextEditingController _appRootController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _flutterPathController = TextEditingController(text: widget.flutterPath);
    _appRootController = TextEditingController(text: widget.appRoot);
  }

  @override
  void dispose() {
    _flutterPathController.dispose();
    _appRootController.dispose();
    super.dispose();
  }

  Future<void> _pickFlutter() async {
    final result = await FilePicker.pickFiles();
    final path = result?.files.single.path;
    if (path == null) return;
    _flutterPathController.text = path;
    setState(() {});
  }

  Future<void> _pickRoot() async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null) return;
    _appRootController.text = path;
    setState(() {});
  }

  Future<void> _save() async {
    final onSave = widget.onSave;
    if (onSave == null || _saving) return;

    setState(() => _saving = true);
    try {
      await onSave(
        _flutterPathController.text.trim(),
        _appRootController.text.trim(),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Execution Engine & System Paths',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C302E),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Auto-detected system paths used by the test execution driver to launch PenguinPOS.',
          style: TextStyle(fontSize: 13.5, color: Color(0xFF787A76)),
        ),
        const SizedBox(height: 24),

        SettingsFormCard(
          children: <Widget>[
            _PathPickerField(
              label: 'Flutter Executable Path',
              controller: _flutterPathController,
              buttonLabel: 'Select file',
              onPick: _pickFlutter,
            ),
            const SizedBox(height: 20),

            _PathPickerField(
              label: 'PenguinPOS Application Root Directory',
              controller: _appRootController,
              buttonLabel: 'Select folder',
              onPick: _pickRoot,
            ),
            const SizedBox(height: 20),

            const Text(
              'Execution Driver Protocol',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'FlutterDriver / WebSocket VM Service Protocol (v2.0)',
              style: TextStyle(fontSize: 13, color: Color(0xFF494C4A)),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const ValueKey<String>('save-system-paths'),
                onPressed: widget.onSave == null || _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        height: 17,
                        width: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 17),
                label: Text(_saving ? 'Saving...' : 'Save System Paths'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PathPickerField extends StatelessWidget {
  const _PathPickerField({
    required this.label,
    required this.controller,
    required this.buttonLabel,
    required this.onPick,
  });

  final String label;
  final TextEditingController controller;
  final String buttonLabel;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 6),
      Row(
        children: <Widget>[
          Expanded(
            child: TextFormField(
              controller: controller,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                hintText: 'Select or enter a path',
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.folder_open_outlined, size: 17),
            label: Text(buttonLabel),
          ),
        ],
      ),
    ],
  );
}
