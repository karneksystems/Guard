import 'package:flutter/material.dart';

import '../state/guard_state.dart';
import '../theme/tokens.dart';

/// Gate journal: stayed out, viewed, traded anyway. Seven days on Free.
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final state = GuardScope.of(context);
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 7));
    final entries = state.pro ? state.journal : state.journal.where((e) => e.atUtc.isAfter(cutoff)).toList();

    return ListView(
      padding: const EdgeInsets.all(Tokens.gutter),
      children: [
        Text('Journal', style: text.headlineMedium),
        const SizedBox(height: Tokens.gutter),
        if (entries.isEmpty)
          const Text('No gates yet. Entries appear here after your first restricted window.')
        else
          for (final e in entries)
            ListTile(
              key: Key('journal-${e.windowId}-${e.atUtc.millisecondsSinceEpoch}'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                switch (e.outcome) {
                  'stayed-out' => Icons.shield,
                  'viewed' => Icons.visibility_outlined,
                  _ => Icons.warning_amber_outlined,
                },
                color: e.outcome == 'traded-anyway' ? Tokens.statusWarn : Tokens.metal,
              ),
              title: Text(switch (e.outcome) {
                'stayed-out' => 'Stayed out',
                'viewed' => 'Viewed only',
                _ => 'Traded anyway',
              }),
              subtitle: Text('${e.atUtc.toIso8601String().substring(0, 10)} · ${e.atUtc.toIso8601String().substring(11, 16)} UTC'),
              shape: const Border(bottom: BorderSide(color: Tokens.champagneHairline)),
            ),
        if (!state.pro && state.journal.length > entries.length) ...[
          const SizedBox(height: Tokens.gutter),
          Text('Older entries are kept with Pro.', style: text.bodySmall),
        ],
      ],
    );
  }
}
