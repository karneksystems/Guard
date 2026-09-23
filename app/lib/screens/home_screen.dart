import 'package:flutter/material.dart';
import 'package:rule_engine/rule_engine.dart';

import '../state/guard_state.dart';
import '../theme/tokens.dart';

/// Home, per the brief: today's windows, next event countdown, protection mode,
/// daily-loss tracker, minimum-days countdown. Scannable in two seconds.
/// M1 shows the engine's real output over sample data; the live pieces land in M2.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = GuardScope.of(context);
    final windows = state.windows;
    final next = windows.isEmpty ? null : windows.first;
    final text = Theme.of(context).textTheme;
    final protection = (state.settings['protection'] as String? ?? 'soft-gate').replaceAll('-', ' ');
    final mode = state.settings['mode'] == 'firm-match' ? 'Firm match' : 'Conservative';
    final age = state.syncAge;
    final syncLine = state.isSample
        ? 'Sample data · no backend configured'
        : 'Last sync ${age!.inMinutes < 1 ? 'just now' : '${age.inMinutes} min ago'}';

    return ListView(
      padding: const EdgeInsets.all(Tokens.gutter),
      children: [
        Text('Guard', style: text.headlineMedium),
        const SizedBox(height: 4),
        Text('${_cap(protection)} · $mode · ${state.instruments.length} instruments · $syncLine', style: text.bodySmall),
        const SizedBox(height: Tokens.gutter),
        _NextWindowCard(window: next, titleFor: state.titleFor),
        const SizedBox(height: Tokens.gutter),
        Text('Windows ahead', style: text.titleMedium),
        const SizedBox(height: 8),
        if (windows.isEmpty)
          const Text('No restricted windows on your instruments.')
        else
          for (final w in windows) ...[
            _WindowRow(window: w, titleFor: state.titleFor),
            const Divider(height: 1),
          ],
        const SizedBox(height: Tokens.gutter),
        Row(children: const [
          Expanded(child: _StatTile(label: 'Daily loss room', value: '£312', note: 'of £500, manual')),
          SizedBox(width: 12),
          Expanded(child: _StatTile(label: 'Min. trading days', value: '3 of 5', note: '2 to go')),
        ]),
        const SizedBox(height: Tokens.gutter),
        Text('We never touch your trades.', style: text.bodySmall),
      ],
    );
  }
}

class _NextWindowCard extends StatelessWidget {
  const _NextWindowCard({required this.window, required this.titleFor});

  final Window? window;
  final String Function(String eventId) titleFor;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final w = window;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.gutter),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(w == null ? 'ALL CLEAR' : 'NEXT WINDOW', style: text.bodySmall?.copyWith(letterSpacing: 1.2, color: Tokens.metal)),
          const SizedBox(height: 6),
          Text(w == null ? 'Nothing scheduled' : w.instrument, style: text.displayMedium),
          if (w != null) ...[
            const SizedBox(height: 4),
            Text(w.reasons.map(titleFor).join(' · '), style: text.bodyLarge),
            const SizedBox(height: 4),
            Text('${_hhmm(w.opensAtUtc)} to ${_hhmm(w.closesAtUtc)} UTC', style: text.bodySmall),
          ],
        ]),
      ),
    );
  }
}

class _WindowRow extends StatelessWidget {
  const _WindowRow({required this.window, required this.titleFor});

  final Window window;
  final String Function(String eventId) titleFor;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Container(width: 3, height: 36, color: Tokens.statusRestricted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${window.instrument} · ${window.reasons.map(titleFor).join(', ')}', style: text.bodyMedium),
            Text('${window.opensAtUtc.substring(0, 10)} · ${_hhmm(window.opensAtUtc)} to ${_hhmm(window.closesAtUtc)} UTC', style: text.bodySmall),
          ]),
        ),
        Text(window.verified ? '' : 'unverified', style: text.bodySmall?.copyWith(color: Tokens.statusWarn)),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.note});

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: text.bodySmall?.copyWith(letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value, style: text.titleLarge),
          Text(note, style: text.bodySmall),
        ]),
      ),
    );
  }
}

String _hhmm(String isoUtc) => isoUtc.substring(11, 16);

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
