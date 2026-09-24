import 'package:flutter/material.dart';

import '../features/tracker.dart';
import '../state/guard_controller.dart';
import '../state/guard_state.dart';
import '../theme/tokens.dart';

/// Daily-loss room, minimum trading days, inactivity and the weekend warning.
/// Everything is typed in by the user. We never read an account.
class TrackerScreen extends StatelessWidget {
  const TrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = GuardScope.of(context);
    final c = ControllerScope.of(context);
    final text = Theme.of(context).textTheme;
    final t = state.tracker;
    final today = c.today;
    final room = t.roomLeft(today);
    final todayPnl = t.pnlOn(today);
    final todays = t.entries.where((e) => e.date == today).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Tracker')),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.gutter),
        children: [
          Text('Daily loss', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            room == null
                ? 'Set your firm\'s daily loss limit and log each trade\'s result.'
                : 'Room left today: ${t.currency}${_money(room)} of ${t.currency}${_money(t.dailyLossLimit!)}. Today ${todayPnl >= 0 ? '+' : '-'}${t.currency}${_money(todayPnl.abs())}.',
            key: const Key('tracker-room'),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('tracker-set-limit'),
                onPressed: () => _askNumber(context, 'Daily loss limit', t.dailyLossLimit, (v) => c.updateTracker(t.copyWith(dailyLossLimit: v.abs()))),
                child: Text(t.dailyLossLimit == null ? 'Set limit' : 'Limit ${t.currency}${_money(t.dailyLossLimit!)}'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('tracker-log'),
                onPressed: () => _askNumber(context, 'Trade result (minus for a loss)', null, (v) => c.logPnl(v)),
                child: const Text('Log a trade'),
              ),
            ),
          ]),
          if (todays.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final e in todays.reversed)
              Text('${e.amount >= 0 ? '+' : '-'}${t.currency}${_money(e.amount.abs())}${e.note == null ? '' : ' · ${e.note}'}', style: text.bodySmall),
          ],
          const SizedBox(height: Tokens.gutter),
          Text('Minimum trading days', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            t.minTradingDays == 0
                ? 'Off. Set the number your firm requires; a day with a logged trade counts.'
                : '${t.tradedDays()} of ${t.minTradingDays} traded · ${t.daysToGo} to go${t.startDate == null ? '' : ' · since ${t.startDate}'}',
            key: const Key('tracker-days'),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('tracker-set-days'),
                onPressed: () => _askNumber(context, 'Minimum trading days', t.minTradingDays.toDouble(), (v) => c.updateTracker(t.copyWith(minTradingDays: v.round().clamp(0, 60)))),
                child: const Text('Set days'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                key: const Key('tracker-set-start'),
                onPressed: () async {
                  final start = t.startDate == null ? DateTime.now() : DateTime.parse(t.startDate!);
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: start,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) await c.updateTracker(t.copyWith(startDate: Tracker.dateKey(picked)));
                },
                child: Text(t.startDate == null ? 'Start date' : 'Started ${t.startDate}'),
              ),
            ),
          ]),
          const SizedBox(height: Tokens.gutter),
          Text('Reminders', style: text.titleMedium),
          SwitchListTile(
            key: const Key('tracker-weekend'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Weekend hold warning'),
            subtitle: const Text('Friday, before the New York close.'),
            value: t.weekendWarning,
            onChanged: (v) => c.updateTracker(t.copyWith(weekendWarning: v)),
          ),
          ListTile(
            key: const Key('tracker-inactivity'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Inactivity reminder'),
            subtitle: Text(t.inactivityDays == 0 ? 'Off' : 'Three days before ${t.inactivityDays} days without a logged trade.'),
            trailing: Text(t.inactivityDays == 0 ? 'Off' : '${t.inactivityDays} days', style: text.bodySmall),
            onTap: () => _askNumber(context, 'Firm inactivity limit in days (0 for off)', t.inactivityDays.toDouble(), (v) => c.updateTracker(t.copyWith(inactivityDays: v.round().clamp(0, 365)))),
          ),
          const SizedBox(height: Tokens.gutter),
          Text('Your numbers stay on this device. We never read your account.', style: text.bodySmall),
        ],
      ),
    );
  }

  Future<void> _askNumber(BuildContext context, String title, double? current, Future<void> Function(double) onDone) async {
    final ctl = TextEditingController(text: current == null ? '' : _money(current));
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

String _money(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
