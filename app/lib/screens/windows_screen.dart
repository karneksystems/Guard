import 'package:flutter/material.dart';

import '../state/guard_state.dart';
import '../theme/tokens.dart';

/// Every window on the horizon with its reasons and the source strip.
class WindowsScreen extends StatelessWidget {
  const WindowsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final state = GuardScope.of(context);
    final windows = state.windows;
    return ListView(
      padding: const EdgeInsets.all(Tokens.gutter),
      children: [
        Text('Windows', style: text.headlineMedium),
        const SizedBox(height: Tokens.gutter),
        for (final w in windows)
          Card(
            child: ListTile(
              title: Text('${w.instrument} · ${w.opensAtUtc.substring(0, 10)}'),
              subtitle: Text('${w.opensAtUtc.substring(11, 16)} to ${w.closesAtUtc.substring(11, 16)} UTC\n${w.reasons.map(state.titleFor).join(', ')}'),
              isThreeLine: true,
              trailing: Text(w.verified ? 'calendar' : 'unverified', style: text.bodySmall),
            ),
          ),
        const SizedBox(height: Tokens.gutter),
        Text('Source: ${state.isSample ? 'sample calendar' : 'calendar feed'} · times can change · not financial advice', style: text.bodySmall),
      ],
    );
  }
}
