import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/qa_dashboard_screen.dart';

class QaAgentGuiApp extends StatelessWidget {
  const QaAgentGuiApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'PenguinPOS QA Agent',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF658A7A),
        surface: const Color(0xFFFDFBF7),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFFDFBF7),
      fontFamily: 'Inter',
    ),
    home: const QaDashboardScreen(),
  );
}
