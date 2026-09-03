import 'dart:io';

import 'package:penguin_pos_qa_agent/qa_agent.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first != 'login') {
    stderr.writeln(
      'Usage: qa-agent login [--vm-service-uri URI] [--app-root PATH] [--device PLATFORM] [--entity ENTITY] [--env ENV] [--mode full|single] [--login-id ID] [--password PASSWORD]',
    );
    exitCode = 64;
    return;
  }

  final handler = LoginCliHandler();
  await handler.execute(args.skip(1).toList());
}
