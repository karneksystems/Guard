import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Everything from onboarding, editable afterwards. Wired to the sync client in M2.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(Tokens.gutter),
      children: [
        Text('Settings', style: text.headlineMedium),
        const SizedBox(height: Tokens.gutter),
        const _Row('Protection', 'Soft gate'),
        const _Row('Rule mode', 'Conservative'),
        const _Row('Window', '5 min before · 5 min after'),
        const _Row('Instruments', 'XAUUSD, EURUSD'),
        const _Row('Gated apps', 'MetaTrader 5'),
        const _Row('Night-before digest', '20:00'),
        const SizedBox(height: Tokens.gutter),
        Text('Free plan · Pro unlocks firm packs, custom windows and hard block.', style: text.bodySmall),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(value, style: Theme.of(context).textTheme.bodySmall),
      shape: const Border(bottom: BorderSide(color: Tokens.champagneHairline)),
    );
  }
}
