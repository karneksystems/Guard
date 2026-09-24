import 'package:flutter/material.dart';

import '../features/tracker.dart';
import '../state/guard_state.dart';
import '../theme/tokens.dart';

/// Tomorrow's windows, the screen behind the night-before digest notification.
class DigestScreen extends StatelessWidget {
  const DigestScreen({super.key, this.now});

  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final state = GuardScope.of(context);
    final text = Theme.of(context).textTheme;
    final local = (now ?? DateTime.now()).toLocal();
    final tomorrow = Tracker.dateKey(local.add(const Duration(days: 1)));
    final windows = state.windows.where((w) => Tracker.dateKey(DateTime.parse(w.opensAtUtc).toLocal()) == tomorrow).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Tomorrow')),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.gutter),
        children: [
          Text(tomorrow, style: text.bodySmall),
          const SizedBox(height: 4),
          Text(
            windows.isEmpty ? 'No restricted windows' : '${windows.length} restricted ${windows.length == 1 ? 'window' : 'windows'}',
            style: text.headlineMedium,
            key: const Key('digest-count'),
          ),
          const SizedBox(height: Tokens.gutter),
          for (final w in windows)
            Card(
              child: ListTile(
                title: Text('${w.instrument} · ${_localHhmm(w.opensAtUtc)} to ${_localHhmm(w.closesAtUtc)}'),
                subtitle: Text('${w.reasons.map(state.titleFor).join(', ')}\n${w.reasons.map(state.sourceFor).toSet().join(' · ')}'),
                isThreeLine: true,
              ),
            ),
          const SizedBox(height: Tokens.gutter),
          Text('Times are local. Tentative events can move; the ladder follows the calendar.', style: text.bodySmall),
        ],
      ),
    );
  }

  static String _localHhmm(String isoUtc) {
    final t = DateTime.parse(isoUtc).toLocal();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}
