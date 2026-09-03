import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The active slash-command fragment immediately before the text cursor.
///
/// A slash command may appear anywhere in a sentence, but it must start at a
/// token boundary. For example, `run /login in stage` is valid whereas
/// `run/login` is not treated as a command.
@immutable
class SlashCommandQuery {
  const SlashCommandQuery({
    required this.start,
    required this.end,
    required this.text,
  });

  final int start;
  final int end;
  final String text;
}

/// Finds the slash-command fragment nearest the current cursor position.
///
/// The composer uses this instead of looking only at the beginning of the
/// message so users can write naturally, such as `please run /login`.
SlashCommandQuery? slashCommandQueryAtCursor(TextEditingValue value) {
  final text = value.text;
  final cursor = value.selection.extentOffset.clamp(0, text.length).toInt();
  if (cursor == 0) return null;

  final slash = text.substring(0, cursor).lastIndexOf('/');
  if (slash == -1 ||
      (slash > 0 && _isSlashCommandTokenCharacter(text[slash - 1]))) {
    return null;
  }

  final query = text.substring(slash, cursor);
  if (query.contains(RegExp(r'\s'))) return null;

  return SlashCommandQuery(start: slash, end: cursor, text: query);
}

/// Replaces the active slash fragment with [command] while preserving the
/// complete surrounding message and keeping the cursor after the insertion.
TextEditingValue? insertSlashCommandAtCursor(
  TextEditingValue value,
  String command,
) {
  final query = slashCommandQueryAtCursor(value);
  if (query == null) return null;

  final text = value.text.replaceRange(query.start, query.end, command);
  final cursor = query.start + command.length;
  return value.copyWith(
    text: text,
    selection: TextSelection.collapsed(offset: cursor),
    composing: TextRange.empty,
  );
}

/// Inserts a standalone slash trigger at the cursor for the attachment/menu
/// button. A separating space is added when necessary so the trigger remains
/// a valid command token.
TextEditingValue insertSlashTriggerAtCursor(TextEditingValue value) {
  final text = value.text;
  final selection = value.selection;
  final start = selection.start.clamp(0, text.length).toInt();
  final end = selection.end.clamp(0, text.length).toInt();
  final before = text.substring(0, start);
  final needsSpace =
      before.isNotEmpty &&
      _isSlashCommandTokenCharacter(before[before.length - 1]);
  final insertion = needsSpace ? ' /' : '/';
  final updatedText = text.replaceRange(start, end, insertion);
  final cursor = start + insertion.length;

  return value.copyWith(
    text: updatedText,
    selection: TextSelection.collapsed(offset: cursor),
    composing: TextRange.empty,
  );
}

bool _isSlashCommandTokenCharacter(String character) =>
    RegExp(r'[A-Za-z0-9_-]').hasMatch(character);

/// Rounded 18px Composer section with floating slash popup, attachment icon, text input, circular send button, and helper note.
class AssistantComposer extends StatelessWidget {
  const AssistantComposer({
    super.key,
    required this.inputController,
    required this.focusNode,
    required this.waiting,
    required this.running,
    required this.filteredSlashCommands,
    required this.slashSelectedIndex,
    required this.onSelectSlashCommand,
    required this.onSlashSelectedIndexChanged,
    required this.onOpenSlashMenu,
    required this.onSend,
    this.onStop,
  });

  final TextEditingController inputController;
  final FocusNode focusNode;
  final bool waiting;
  final bool running;
  final List<String> filteredSlashCommands;
  final int slashSelectedIndex;
  final ValueChanged<String> onSelectSlashCommand;
  final ValueChanged<int> onSlashSelectedIndexChanged;
  final VoidCallback onOpenSlashMenu;
  final VoidCallback onSend;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final showPopup =
        filteredSlashCommands.isNotEmpty && slashSelectedIndex >= 0;
    final safeSelectedIndex = showPopup
        ? slashSelectedIndex.clamp(0, filteredSlashCommands.length - 1).toInt()
        : 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            if (showPopup)
              Positioned(
                left: 0,
                right: 0,
                bottom: 64,
                child: _SlashPopup(
                  commands: filteredSlashCommands,
                  selectedIndex: safeSelectedIndex,
                  onSelectCommand: onSelectSlashCommand,
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFC7C9C4)),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x0C658A7A),
                    blurRadius: 14,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Attach scenario spec / open slash menu',
                      onPressed: waiting || running ? null : onOpenSlashMenu,
                      icon: const Icon(
                        Icons.attach_file_rounded,
                        size: 20,
                        color: Color(0xFF787A76),
                      ),
                    ),
                    Expanded(
                      child: Focus(
                        onKeyEvent: (node, event) {
                          if (event is! KeyDownEvent) {
                            return KeyEventResult.ignored;
                          }

                          if (showPopup) {
                            if (event.logicalKey ==
                                LogicalKeyboardKey.arrowDown) {
                              onSlashSelectedIndexChanged(
                                (slashSelectedIndex + 1) %
                                    filteredSlashCommands.length,
                              );
                              return KeyEventResult.handled;
                            } else if (event.logicalKey ==
                                LogicalKeyboardKey.arrowUp) {
                              onSlashSelectedIndexChanged(
                                (slashSelectedIndex -
                                        1 +
                                        filteredSlashCommands.length) %
                                    filteredSlashCommands.length,
                              );
                              return KeyEventResult.handled;
                            } else if (event.logicalKey ==
                                    LogicalKeyboardKey.tab ||
                                event.logicalKey == LogicalKeyboardKey.enter ||
                                event.logicalKey ==
                                    LogicalKeyboardKey.numpadEnter) {
                              onSelectSlashCommand(
                                filteredSlashCommands[safeSelectedIndex],
                              );
                              return KeyEventResult.handled;
                            } else if (event.logicalKey ==
                                LogicalKeyboardKey.escape) {
                              onSlashSelectedIndexChanged(-1);
                              return KeyEventResult.handled;
                            }
                          }

                          final isEnter =
                              event.logicalKey == LogicalKeyboardKey.enter ||
                              event.logicalKey ==
                                  LogicalKeyboardKey.numpadEnter;

                          if (isEnter) {
                            final isShiftPressed =
                                HardwareKeyboard.instance.isShiftPressed;
                            if (isShiftPressed) {
                              final currentText = inputController.text;
                              final selection = inputController.selection;
                              final start = selection.start >= 0
                                  ? selection.start
                                  : currentText.length;
                              final end = selection.end >= 0
                                  ? selection.end
                                  : currentText.length;
                              final newText = currentText.replaceRange(
                                start,
                                end,
                                '\n',
                              );
                              inputController.value = TextEditingValue(
                                text: newText,
                                selection: TextSelection.collapsed(
                                  offset: start + 1,
                                ),
                              );
                              return KeyEventResult.handled;
                            } else {
                              if (!waiting && !running) {
                                onSend();
                              }
                              return KeyEventResult.handled;
                            }
                          }

                          return KeyEventResult.ignored;
                        },
                        child: TextField(
                          controller: inputController,
                          focusNode: focusNode,
                          enabled: !waiting && !running,
                          onSubmitted: (_) => onSend(),
                          maxLines: 5,
                          minLines: 1,
                          style: const TextStyle(
                            fontSize: 14.5,
                            color: Color(0xFF2C302E),
                          ),
                          decoration: const InputDecoration(
                            hintText:
                                'Ask QA Assistant or type / for actions...',
                            hintStyle: TextStyle(
                              color: Color(0xFF787A76),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Builder(
                      builder: (context) {
                        final isBusy = waiting || running;
                        final hasStopAction = isBusy && onStop != null;
                        final buttonColor = hasStopAction
                            ? const Color(0xFF2C302E)
                            : (isBusy
                                  ? const Color(0xFFC7C9C4)
                                  : const Color(0xFF658A7A));

                        return Material(
                          color: buttonColor,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: hasStopAction
                                ? onStop
                                : (isBusy ? null : onSend),
                            child: Tooltip(
                              message: hasStopAction
                                  ? 'Stop execution'
                                  : 'Send message (Enter)',
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                child: Center(
                                  child: isBusy
                                      ? (hasStopAction
                                            ? const Icon(
                                                Icons.stop_rounded,
                                                size: 18,
                                                color: Colors.white,
                                              )
                                            : const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              ))
                                      : const Icon(
                                          Icons.arrow_upward_rounded,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Helper Note
        const SizedBox(height: 10),
        const Text(
          'Only approved non-production profiles can be executed.',
          style: TextStyle(fontSize: 12, color: Color(0xFF787A76)),
        ),
      ],
    );
  }
}

class _SlashPopup extends StatelessWidget {
  const _SlashPopup({
    required this.commands,
    required this.selectedIndex,
    required this.onSelectCommand,
  });

  final List<String> commands;
  final int selectedIndex;
  final ValueChanged<String> onSelectCommand;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFC7C9C4)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x12658A7A),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: commands.length,
          itemBuilder: (context, index) {
            final cmd = commands[index];
            final isSelected = index == selectedIndex;
            return Material(
              color: isSelected ? const Color(0xFFF6F4F0) : Colors.white,
              child: InkWell(
                onTap: () => onSelectCommand(cmd),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.terminal_rounded,
                        size: 16,
                        color: Color(0xFF658A7A),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        cmd,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C302E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
