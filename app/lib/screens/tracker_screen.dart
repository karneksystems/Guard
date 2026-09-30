import 'package:flutter/material.dart';

import '../features/tracker.dart';
import '../state/guard_controller.dart';
import '../state/guard_state.dart';
import '../theme/tokens.dart';
import '../ui/parts.dart';
import '../ui/words.dart';

/// Daily limits: loss room and trading days, typed in by the trader. We never
/// read an account. Board: docs/redesign/grok-final/phone/tracker.png.
class TrackerScreen extends StatelessWidget {
  const TrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = GuardScope.of(context);
    final c = ControllerScope.of(context);
    final shade = Shade.of(context);
    final t = state.tracker;
    final today = c.today;
    final room = t.roomLeft(today);
    final todayPnl = t.pnlOn(today);
    final todays = t.entries.where((e) => e.date == today).toList();
    final small = TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 13, color: shade.muted);
    final big = TextStyle(fontFamily: Tokens.displayFamily, fontSize: 38, fontWeight: FontWeight.w600, color: shade.text, height: 1.1);

    Widget setting(Key key, String label, String value, VoidCallback onTap) => InkWell(
          key: key,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(children: [
              Expanded(child: Text(label, style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 15, color: shade.text))),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 14, fontWeight: FontWeight.w600, color: shade.muted)),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 18, color: shade.muted),
            ]),
          ),
        );

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Tokens.gutter, 0, Tokens.gutter, Tokens.gutter),
        children: [
          const PageHead('Daily limits', sub: 'Loss room and trading days'),
          const SizedBox(height: 16),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Kicker('Loss room'),
              const SizedBox(height: 8),
              Text(room == null ? 'Not set' : money(t.currency, room), style: big),
              const SizedBox(height: 6),
              Text(
                room == null
                    ? "Set your firm's daily loss limit, then log each trade's result."
                    : 'Room left today: ${money(t.currency, room)} of ${money(t.currency, t.dailyLossLimit!)}. Today ${todayPnl >= 0 ? '+' : '-'}${money(t.currency, todayPnl.abs())}.',
                key: const Key('tracker-room'),
                style: small,
              ),
              if (room != null && t.dailyLossLimit! > 0) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (room / t.dailyLossLimit!).clamp(0.0, 1.0),
                    minHeight: 5,
                    color: room / t.dailyLossLimit! < 0.25 ? Tokens.amber : Tokens.sky,
                    backgroundColor: shade.hairline,
                  ),
                ),
              ],
              for (final e in todays.reversed) ...[
                const SizedBox(height: 6),
                Text('${e.amount >= 0 ? '+' : '-'}${money(t.currency, e.amount.abs())}${e.note == null ? '' : ' · ${e.note}'}', style: small),
              ],
            ]),
          ),
          const SizedBox(height: 10),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Kicker('Trading days'),
              const SizedBox(height: 8),
              if (t.minTradingDays == 0)
                Text('Off', style: big)
              else
                Text.rich(TextSpan(children: [
                  TextSpan(text: '${t.tradedDays()}', style: big),
                  TextSpan(text: '  of ${t.minTradingDays}', style: big.copyWith(fontSize: 18, color: shade.muted)),
                ])),
              const SizedBox(height: 6),
              Text(
                t.minTradingDays == 0
                    ? 'Set the number your firm needs. A day with a logged trade counts.'
                    : '${t.tradedDays()} of ${t.minTradingDays} traded · ${t.daysToGo} to go${t.startDate == null ? '' : ' · since ${t.startDate}'}',
                key: const Key('tracker-days'),
                style: small,
              ),
            ]),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('tracker-log'),
            onPressed: () => _askNumber(context, "Today's P&L for this trade (minus for a loss)", null, (v) => c.logPnl(v)),
            child: const Text("Log today's P&L"),
          ),
          SectionLabel('Your firm'),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Column(children: [
              setting(const Key('tracker-set-limit'), 'Daily loss limit', t.dailyLossLimit == null ? 'Set' : money(t.currency, t.dailyLossLimit!),
                  () => _askNumber(context, 'Daily loss limit', t.dailyLossLimit, (v) => c.updateTracker(t.copyWith(dailyLossLimit: v.abs())))),
              Divider(height: 1, color: shade.hairline),
              setting(const Key('tracker-set-days'), 'Minimum trading days', t.minTradingDays == 0 ? 'Off' : '${t.minTradingDays}',
                  () => _askNumber(context, 'Minimum trading days', t.minTradingDays.toDouble(), (v) => c.updateTracker(t.copyWith(minTradingDays: v.round().clamp(0, 60))))),
              Divider(height: 1, color: shade.hairline),
              setting(const Key('tracker-set-start'), 'Started', t.startDate ?? 'Set', () async {
                final start = t.startDate == null ? DateTime.now() : DateTime.parse(t.startDate!);
                final picked = await showDatePicker(
                  context: context,
                  initialDate: start,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) await c.updateTracker(t.copyWith(startDate: Tracker.dateKey(picked)));
              }),
            ]),
          ),
          SectionLabel('Reminders'),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Column(children: [
              SwitchListTile(
                key: const Key('tracker-weekend'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Weekend hold'),
                subtitle: const Text('Friday, before the New York close'),
                value: t.weekendWarning,
                onChanged: (v) => c.updateTracker(t.copyWith(weekendWarning: v)),
              ),
              Divider(height: 1, color: shade.hairline),
              setting(const Key('tracker-inactivity'), 'No trade reminder', t.inactivityDays == 0 ? 'Off' : '${t.inactivityDays} days',
                  () => _askNumber(context, 'Days your firm allows without a trade (0 for off)', t.inactivityDays.toDouble(), (v) => c.updateTracker(t.copyWith(inactivityDays: v.round().clamp(0, 365))))),
            ]),
          ),
          const Promise(text: 'Your numbers stay on this device. We never read your account.'),
        ],
      ),
    );
  }

  Future<void> _askNumber(BuildContext context, String title, double? current, Future<void> Function(double) onDone) async {
    final ctl = TextEditingController(text: current == null ? '' : (current == current.roundToDouble() ? current.toStringAsFixed(0) : current.toStringAsFixed(2)));
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          key: const Key('tracker-number'),
          controller: ctl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          onSubmitted: (s) => Navigator.of(ctx).pop(double.tryParse(s.replaceAll(',', ''))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            key: const Key('tracker-number-ok'),
            onPressed: () => Navigator.of(ctx).pop(double.tryParse(ctl.text.replaceAll(',', ''))),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (v != null) await onDone(v);
  }
}
