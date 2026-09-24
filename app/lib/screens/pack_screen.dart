import 'package:flutter/material.dart';

import '../state/guard_controller.dart';
import '../state/guard_state.dart';
import '../theme/tokens.dart';

/// The pack behind Firm match: version, verified state, source, the rule for
/// the chosen account type, and the changelog (Pro). Never a firm logo.
class PackScreen extends StatelessWidget {
  const PackScreen({super.key, required this.firmId});

  final String firmId;

  @override
  Widget build(BuildContext context) {
    final state = GuardScope.of(context);
    final c = ControllerScope.of(context);
    final text = Theme.of(context).textTheme;
    final entry = state.packs.index[firmId];
    final pack = state.packs.packs[firmId];
    final accountId = state.settings['accountTypeId'] as String?;
    final account = pack == null
        ? null
        : (pack['accountTypes'] as List).cast<Map<String, dynamic>>().where((a) => a['id'] == accountId).firstOrNull;
    final rule = account?['newsRule'] as Map<String, dynamic>?;
    final unverified = pack?['needsReverify'] == true || (entry?.needsReverify ?? pack == null);

    return Scaffold(
      appBar: AppBar(title: Text(entry?.firmName ?? pack?['firmName'] as String? ?? firmId)),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.gutter),
        children: [
          Row(children: [
            Text('Pack ${pack?['packVersion'] ?? entry?.packVersion ?? ''}', style: text.titleMedium),
            const SizedBox(width: 8),
            Chip(
              key: const Key('pack-badge'),
              label: Text(unverified ? 'Unverified' : 'Verified ${pack?['lastVerified'] ?? entry?.lastVerified ?? ''}'),
              backgroundColor: unverified ? Tokens.statusWarn.withValues(alpha: 0.15) : null,
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            unverified
                ? 'Drafted from secondary sources. Until a human has read the firm\'s page, the larger of the pack window and your default applies, and unknown means not allowed.'
                : 'Read on the firm\'s page by ${pack?['verifiedBy'] ?? 'the team'}.',
            style: text.bodySmall,
          ),
          const SizedBox(height: Tokens.gutter),
          if (pack == null)
            const Text('Pack not downloaded yet. It arrives on the next sync.')
          else ...[
            Text('Source', style: text.titleMedium),
            SelectableText(pack['sourceUrl'] as String, style: text.bodySmall),
            const SizedBox(height: Tokens.gutter),
            Text('Your account type', style: text.titleMedium),
            if (account == null)
              const Text('Not chosen. Pick one in Settings.')
            else if (rule?['applies'] != true)
              Text('${account['label']}: the firm does not restrict news trading on this account type.')
            else
              Text(
                '${account['label']}: ${rule!['windowBeforeMin']} min before to ${rule['windowAfterMin']} min after. '
                'Events: ${rule['eventSet'] == 'firm-list' ? 'the firm\'s own list' : 'calendar high impact'}. '
                'Affects: ${_affects(rule['affectedInstruments'] as String?)}. '
                'Restricted: ${(rule['restrictedActions'] as List? ?? const []).join(', ')}. '
                '${rule['slTpTriggerCounts'] == true ? 'An SL or TP hit counts.' : ''} '
                'Consequence: ${rule['consequence'] ?? 'unknown'}.',
                key: const Key('pack-rule'),
              ),
            if (rule?['notes'] != null) ...[
              const SizedBox(height: 4),
              Text(rule!['notes'] as String, style: text.bodySmall),
            ],
            const SizedBox(height: Tokens.gutter),
            Text('Investor password', style: text.titleMedium),
            Text(switch (pack['investorPasswordAllowed']) {
              'yes' => 'Allowed by the firm. Read-only access is a later version anyway.',
              'no' => 'Not allowed by the firm.',
              _ => 'Unknown, so treated as not allowed.',
            }),
            const SizedBox(height: Tokens.gutter),
            Text('Changelog', style: text.titleMedium),
            if (!state.flags.changelog)
              Text('Rule changes and the changelog are part of Pro.', style: text.bodySmall)
            else
              for (final e in (pack['changelog'] as List).cast<Map<String, dynamic>>().reversed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${e['packVersion']} · ${e['date']}'),
                  subtitle: Text(e['change'] as String),
                ),
          ],
          const SizedBox(height: Tokens.gutter),
          if (state.rulesChanged?.firmId == firmId)
            FilledButton(
              key: const Key('pack-ack'),
              onPressed: () {
                state.clearRulesChanged();
                Navigator.of(context).pop();
              },
              child: const Text('Got it'),
            ),
          const SizedBox(height: Tokens.gutter),
          Text('Your firm\'s current rules are your responsibility. Times can change. Not financial advice.', style: text.bodySmall),
          if (c.api == null) const SizedBox.shrink(),
        ],
      ),
    );
  }

  static String _affects(String? a) => switch (a) {
        'all' => 'every instrument',
        'list' => 'the firm\'s list of instruments',
        _ => 'instruments whose currency is in the event',
      };
}
