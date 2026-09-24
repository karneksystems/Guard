import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rule_engine/rule_engine.dart';

import '../features/tracker.dart';
import '../state/guard_controller.dart';
import '../state/guard_state.dart';
import '../theme/tokens.dart';
import 'digest_screen.dart';
import 'pack_screen.dart';
import 'permissions_screen.dart';
import 'tracker_screen.dart';

/// Home, per the brief: today's windows, next event countdown, protection mode,
/// daily-loss tracker, minimum-days countdown. Scannable in two seconds.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.now});

  /// Injected by tests; the wall clock otherwise.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final state = GuardScope.of(context);
    final c = ControllerScope.of(context);
    final windows = state.windows;
    final t = state.tracker;
    final local = (now ?? c.now).toLocal();
    final today = Tracker.dateKey(local);
    final room = t.roomLeft(today);
    final tomorrow = Tracker.dateKey(local.add(const Duration(days: 1)));
    final tomorrowCount = windows.where((w) => Tracker.dateKey(DateTime.parse(w.opensAtUtc).toLocal()) == tomorrow).length;
    final weekend = t.weekendWarning && local.weekday == DateTime.friday && local.hour >= 12;
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
        const PermissionBanner(),
        if (!state.isSample && (state.calendarAge == null || state.calendarAge! > const Duration(minutes: 60))) ...[
          Card(
            key: const Key('home-feed-stale'),
            color: Tokens.statusWarn.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(state.calendarAge == null
                  ? 'The calendar feed has not loaded yet. Windows below may be incomplete.'
                  : 'The calendar feed is ${state.calendarAge!.inMinutes} minutes old. Times below may have moved.'),
            ),
          ),
          const SizedBox(height: Tokens.gutter),
        ],
        if (state.missingPermissions.isNotEmpty) const SizedBox(height: Tokens.gutter),
        if (state.rulesChanged != null && state.flags.rulesChangedFlag) ...[
          Card(
            key: const Key('home-rules-changed'),
            color: Tokens.statusWarn.withValues(alpha: 0.12),
            child: ListTile(
              title: Text('${state.packs.index[state.rulesChanged!.firmId]?.firmName ?? state.rulesChanged!.firmId}: rules changed'),
              subtitle: Text('Pack ${state.rulesChanged!.from} to ${state.rulesChanged!.to}. Tap to read what moved.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PackScreen(firmId: state.rulesChanged!.firmId))),
            ),
          ),
          const SizedBox(height: Tokens.gutter),
        ],
        _NextWindowCard(window: next, titleFor: state.titleFor, sourceFor: state.sourceFor, now: local.toUtc()),
        const SizedBox(height: Tokens.gutter),
        if (weekend) ...[
          Card(
            key: const Key('home-weekend'),
            color: Tokens.statusWarn.withValues(alpha: 0.12),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Text('Weekend hold: flat before the close unless your firm allows holding over the weekend.'),
            ),
          ),
          const SizedBox(height: Tokens.gutter),
        ],
        Text('Windows ahead', style: text.titleMedium),
        if (state.engineNotes.isNotEmpty)
          Text(state.engineNotes.join(' · '), key: const Key('home-notes'), style: text.bodySmall?.copyWith(color: Tokens.statusWarn)),
        const SizedBox(height: 8),
        if (windows.isEmpty)
          const Text('No restricted windows on your instruments.')
        else
          for (final w in windows) ...[
            _WindowRow(window: w, titleFor: state.titleFor),
            const Divider(height: 1),
          ],
        const SizedBox(height: Tokens.gutter),
        Row(children: [
          Expanded(
            child: _StatTile(
              key: const Key('home-loss'),
              label: 'Daily loss room',
              value: room == null ? 'Set' : '${t.currency}${_money(room)}',
              note: room == null ? 'tap to set your limit' : 'of ${t.currency}${_money(t.dailyLossLimit!)}, manual',
              onTap: () => _openTracker(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              key: const Key('home-days'),
              label: 'Min. trading days',
              value: t.minTradingDays == 0 ? 'Off' : '${t.tradedDays()} of ${t.minTradingDays}',
              note: t.minTradingDays == 0 ? 'tap to set' : '${t.daysToGo} to go',
              onTap: () => _openTracker(context),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        ListTile(
          key: const Key('home-tomorrow'),
          contentPadding: EdgeInsets.zero,
          title: Text(tomorrowCount == 0 ? 'Tomorrow: clear' : 'Tomorrow: $tomorrowCount restricted ${tomorrowCount == 1 ? 'window' : 'windows'}'),
          subtitle: Text('Digest at ${state.settings['digestLocalTime'] ?? '20:00'} tonight', style: text.bodySmall),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DigestScreen(now: now))),
        ),
        const SizedBox(height: Tokens.gutter),
        Text('We never touch your trades.', style: text.bodySmall),
      ],
    );
  }

  static void _openTracker(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TrackerScreen()));
}

/// Rebuilds every thirty seconds so the countdown moves. The wall clock is
/// the controller's, so tests can pin it.
class _NextWindowCard extends StatefulWidget {
  const _NextWindowCard({required this.window, required this.titleFor, required this.sourceFor, required this.now});

  final Window? window;
  final String Function(String eventId) titleFor;
  final String Function(String eventId) sourceFor;
  final DateTime now;

  @override
  State<_NextWindowCard> createState() => _NextWindowCardState();
}

class _NextWindowCardState extends State<_NextWindowCard> {
  Timer? _tick;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (t) {
      if (mounted) setState(() => _elapsed = Duration(seconds: 30 * t.tick));
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// "in 2 h 14 min", "opens in 4 min", "open, 6 min left", or "closed".
  static String countdown(Window w, DateTime now) {
    final opens = DateTime.parse(w.opensAtUtc).toUtc();
    final closes = DateTime.parse(w.closesAtUtc).toUtc();
    if (now.isBefore(opens)) {
      final d = opens.difference(now);
      if (d.inMinutes < 1) return 'opens in under a minute';
      if (d.inHours < 1) return 'opens in ${d.inMinutes} min';
      if (d.inHours < 24) return 'in ${d.inHours} h ${d.inMinutes % 60} min';
      return 'in ${d.inDays} d ${d.inHours % 24} h';
    }
    if (now.isBefore(closes)) return 'open, ${(closes.difference(now).inSeconds / 60).ceil()} min left';
    return 'closed';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final w = widget.window;
    final titleFor = widget.titleFor;
    final sourceFor = widget.sourceFor;
    final now = widget.now.add(_elapsed);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.gutter),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(w == null ? 'ALL CLEAR' : 'NEXT WINDOW', style: text.bodySmall?.copyWith(letterSpacing: 1.2, color: Tokens.metal)),
          const SizedBox(height: 6),
          Text(w == null ? 'Nothing scheduled' : w.instrument, style: text.displayMedium),
          if (w != null) ...[
            Text(countdown(w, now), key: const Key('home-countdown'), style: text.titleMedium?.copyWith(color: Tokens.metal)),
            const SizedBox(height: 4),
            Text(w.reasons.map(titleFor).join(' · '), style: text.bodyLarge),
            const SizedBox(height: 4),
            Text('${_hhmm(w.opensAtUtc)} to ${_hhmm(w.closesAtUtc)} UTC', style: text.bodySmall),
            const SizedBox(height: 2),
            Text(w.reasons.map(sourceFor).toSet().join(' · '), style: text.bodySmall?.copyWith(color: Tokens.metal)),
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
  const _StatTile({super.key, required this.label, required this.value, required this.note, this.onTap});

  final String label;
  final String value;
  final String note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: text.bodySmall?.copyWith(letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value, style: text.titleLarge),
          Text(note, style: text.bodySmall),
        ]),
      ),
      ),
    );
  }
}

String _money(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

String _hhmm(String isoUtc) => isoUtc.substring(11, 16);

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
