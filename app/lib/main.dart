import 'package:flutter/material.dart';

import 'shell/adaptive_shell.dart';
import 'theme/tokens.dart';

void main() {
  runApp(const GuardApp());
}

class GuardApp extends StatelessWidget {
  const GuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guard',
      debugShowCheckedModeBanner: false,
      theme: GuardTheme.light(),
      darkTheme: GuardTheme.dark(),
      themeMode: ThemeMode.system,
      home: const AdaptiveShell(),
    );
  }
}
