import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Gate journal: stayed out, viewed, traded anyway. Seven days on Free.
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(Tokens.gutter),
      children: [
        Text('Journal', style: text.headlineMedium),
        const SizedBox(height: Tokens.gutter),
        const Text('No gates yet. Entries appear here after your first restricted window.'),
      ],
    );
  }
}
