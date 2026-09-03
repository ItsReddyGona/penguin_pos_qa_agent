import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_composer.dart';

void main() {
  TextEditingValue valueAt(String text, int cursor) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: cursor),
  );

  test('finds a slash command at the cursor inside normal text', () {
    const text = 'Please run /log in kpn-stage';
    final query = slashCommandQueryAtCursor(valueAt(text, 15));

    expect(query?.text, '/log');
    expect(query?.start, 11);
    expect(query?.end, 15);
  });

  test('does not treat a slash inside another token as a command', () {
    expect(slashCommandQueryAtCursor(valueAt('Please run/login', 16)), isNull);
  });

  test('inserts the selected command without losing surrounding text', () {
    const text = 'Please run /log in kpn-stage';
    final updated = insertSlashCommandAtCursor(valueAt(text, 15), '/login');

    expect(updated?.text, 'Please run /login in kpn-stage');
    expect(updated?.selection.baseOffset, 17);
  });

  test('menu trigger creates a slash command token mid-sentence', () {
    final updated = insertSlashTriggerAtCursor(valueAt('Please run', 10));

    expect(updated.text, 'Please run /');
    expect(slashCommandQueryAtCursor(updated)?.text, '/');
  });

  testWidgets('selecting a slash suggestion delegates without submitting', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Please run /lo');
    final focusNode = FocusNode();
    var sends = 0;
    String? selectedCommand;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: AssistantComposer(
              inputController: controller,
              focusNode: focusNode,
              waiting: false,
              running: false,
              filteredSlashCommands: const <String>['/login'],
              slashSelectedIndex: 0,
              onSelectSlashCommand: (command) => selectedCommand = command,
              onSlashSelectedIndexChanged: (_) {},
              onOpenSlashMenu: () {},
              onSend: () => sends += 1,
            ),
          ),
        ),
      ),
    );

    final suggestion = find.ancestor(
      of: find.text('/login'),
      matching: find.byType(InkWell),
    );
    expect(suggestion, findsOneWidget);
    tester.widget<InkWell>(suggestion).onTap?.call();
    await tester.pump();

    expect(selectedCommand, '/login');
    expect(sends, 0);

    controller.dispose();
    focusNode.dispose();
  });
}
