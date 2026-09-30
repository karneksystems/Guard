import 'package:flutter/material.dart';

import '../features/tracker.dart';
import '../state/covers.dart';
import '../state/guard_controller.dart';
import '../state/guard_state.dart';
import '../theme/tokens.dart';
import '../ui/calendar.dart';
import '../ui/parts.dart';
import '../ui/words.dart';

/// Tomorrow's news: the screen behind the night before alert. Not a tab.
/// Board: docs/redesign/grok-final/phone/tomorrows-news.png.
class DigestScreen extends StatefulWidget {
  const DigestScreen({super.key, this.now});

  final DateTime? now;

  @override
  State<DigestScreen> createState() => _DigestScreenState();
}

class _DigestScreenState extends State<DigestScreen> {
  Set<String> _levels = {'high'};

  @override
  Widget build(BuildContext context) {
    final state = GuardScope.of(context);
    final c = ControllerScope.of(context);
    final shade = Shade.of(context);
    final now = (widget.now ?? c.now).toUtc();
    final day = now.toLocal().add(const Duration(days: 1));
    final covers = coversFor(state).where((x) => sameLocalDay(x.opens, day)).toList();
    final entries = calendarFor(state, covers).where((e) => sameLocalDay(e.at, day)).toList();
    final shown = entries.where((e) => _levels.contains(e.impact)).toList();
    final hint = ImpactFilter.hint(entries, _levels);
    final t = state.tracker;
    final room = t.roomLeft(Tracker.dateKey(now.toLocal()));
    final warnOnly = state.settings['protection'] == 'warn-only';

    Widget line(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Text(label, style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 15, color: shade.text)),
            const Spacer(),
            Text(value, style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 14, fontWeight: FontWeight.w600, color: shade.muted)),
          ]),
        );

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Tokens.gutter, 0, Tokens.gutter, Tokens.gutter),
        children: [
          PageHead("Tomorrow's news", sub: '${dateShort(day)} · local times'),
          const SizedBox(height: 16),
          ImpactFilter(entries: entries, selected: _levels, onChanged: (v) => setState(() => _levels = v)),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(hint, style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 12, color: shade.muted)),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 20, 0, 10),
            child: Kicker(
              covers.isEmpty ? 'No high impact windows' : '${covers.length} high impact ${covers.length == 1 ? 'window' : 'windows'}',
              key: const Key('digest-count'),
              size: 11,
            ),
          ),
          if (shown.isEmpty)
            Panel(child: Text('Nothing to show for tomorrow.', style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 15, color: shade.muted)))
          else
            EventGroup(entries: shown, now: now, showEta: false),
          const SizedBox(height: 10),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Kicker('Cover plan', size: 11),
              const SizedBox(height: 8),
              Text(
                warnOnly
                    ? "Warnings only. We'll warn you at 60, 15, 5 and 1 minute before the news."
                    : "Cover is on. We'll warn you at 60, 15, 5 and 1 minute, then cover the trading app when news opens.",
                style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 15, height: 1.4, color: shade.text),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(children: [
              line('Loss room left', room == null ? 'Not set' : '${money(t.currency, room)} of ${money(t.currency, t.dailyLossLimit!)}'),
              Divider(height: 1, color: shade.hairline),
              line('Trading days', t.minTradingDays == 0 ? 'Off' : '${t.tradedDays()} of ${t.minTradingDays} · ${t.daysToGo} to go'),
            ]),
          ),
          const Promise(),
        ],
      ),
    );
  }
}
