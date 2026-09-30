import 'package:flutter/material.dart';
import 'package:rule_engine/rule_engine.dart';

import '../platform/platform_bridge.dart';
import '../state/covers.dart';
import '../state/guard_controller.dart';
import '../state/guard_state.dart';
import '../theme/tokens.dart';
import '../ui/parts.dart';
import '../ui/words.dart';

/// Log: every cover and what the trader did. Staying out is the win, so the
/// count leads. Seven days on Free. Board: docs/redesign/grok-final/phone/log.png.
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = GuardScope.of(context);
    final c = ControllerScope.of(context);
    final shade = Shade.of(context);
    final now = c.now.toUtc();
    final cutoff = now.subtract(const Duration(days: 7));
    final entries = state.pro ? state.journal : state.journal.where((e) => e.atUtc.isAfter(cutoff)).toList();
    final local = now.toLocal();
    final month = state.journal
        .where((e) => e.outcome == 'stayed-out' && e.atUtc.toLocal().year == local.year && e.atUtc.toLocal().month == local.month)
        .length;
    final windows = {for (final w in state.windows) w.windowId: w};

    final byDay = <String, List<GateOutcome>>{};
    for (final e in entries) {
      byDay.putIfAbsent(dayWord(e.atUtc, now), () => []).add(e);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 12, Tokens.gutter, Tokens.gutter),
      children: [
        const PageHead('Log', sub: "You stayed out. That's the win."),
        const SizedBox(height: 16),
        _Count(
          count: month,
          sub: state.flags.journalStreak
              ? switch (state.streak(local)) {
                  0 => 'Your streak starts with the next cover',
                  1 => '1 day clean · keep the streak',
                  final n => '$n days clean · keep the streak',
                }
              : 'Pro keeps your full log and streak',
          streakKey: state.flags.journalStreak,
        ),
        if (entries.isEmpty) ...[
          const SizedBox(height: 16),
          Panel(
            child: Text('No covers yet. When news hits, your stay outs show up here.',
                style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 15, color: shade.muted)),
          ),
        ],
        for (final day in byDay.entries) ...[
          SectionLabel(day.key),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (var i = 0; i < day.value.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 14, endIndent: 14, color: shade.hairline),
                _Row(entry: day.value[i], window: windows[day.value[i].windowId], state: state, controller: c),
              ],
            ]),
          ),
        ],
        if (!state.pro && state.journal.length > entries.length) ...[
          const SizedBox(height: 12),
          Text('Older entries are kept with Pro.', style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 12, color: shade.muted)),
        ],
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.count, required this.sub, required this.streakKey});

  final int count;
  final String sub;
  final bool streakKey;

  @override
  Widget build(BuildContext context) {
    final shade = Shade.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: Tokens.sky.withValues(alpha: 0.35)),
        gradient: LinearGradient(colors: [Tokens.brand.withValues(alpha: 0.35), Tokens.brandDeep.withValues(alpha: shade.dark ? 0.5 : 0.12)]),
      ),
      child: Row(children: [
        Text('$count',
            key: const Key('log-count'),
            style: const TextStyle(fontFamily: Tokens.displayFamily, fontSize: 36, fontWeight: FontWeight.w600, color: Tokens.sky, height: 1)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('stayed out this month', style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 16, fontWeight: FontWeight.w700, color: shade.text)),
            const SizedBox(height: 3),
            Text(sub,
                key: streakKey ? const Key('journal-streak') : null,
                style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 13, color: shade.muted)),
          ]),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.window, required this.state, required this.controller});

  final GateOutcome entry;
  final Window? window;
  final GuardState state;
  final GuardController controller;

  @override
  Widget build(BuildContext context) {
    final shade = Shade.of(context);
    final w = window;
    // "EUR CPI · Gold", once the window is known; old entries just say Cover.
    final what = w == null ? 'Cover' : coverWhat(state, w).split(' · ').reversed.join(' · ');
    final impact = w == null
        ? 'high'
        : (w.reasons.map(state.eventById).whereType<Map<String, dynamic>>().map((e) => e['impact'] as String? ?? 'high').contains('high') ? 'high' : 'medium');
    final (label, color) = switch (entry.outcome) {
      'stayed-out' => ('Stayed out', Tokens.sky),
      'viewed' => ('Looked', shade.muted),
      _ => ('Traded anyway', Tokens.red),
    };
    final how = switch (entry.outcome) {
      'stayed-out' => 'Cover',
      'viewed' => 'Looked',
      _ => 'Traded in window',
    };
    return Padding(
      key: Key('journal-${entry.windowId}-${entry.atUtc.millisecondsSinceEpoch}'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              ImpactBars(impact, height: 11),
              const SizedBox(width: 8),
              Flexible(
                child: Text(what, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 15, fontWeight: FontWeight.w600, color: shade.text)),
              ),
            ]),
            const SizedBox(height: 3),
            Text('${clock(entry.atUtc)} · $how', style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 12, color: shade.muted)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(label, style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          // Self report: a look that turned into a trade. Honesty is the product.
          if (entry.outcome == 'viewed')
            TextButton(
              key: Key('journal-traded-${entry.windowId}'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              onPressed: () => controller.amendOutcome(entry.windowId, 'traded-anyway'),
              child: const Text('I traded', style: TextStyle(fontSize: 12)),
            ),
        ]),
      ]),
    );
  }
}
