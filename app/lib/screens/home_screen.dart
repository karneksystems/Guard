import 'dart:async';

import 'package:flutter/material.dart';

import '../features/tracker.dart';
import '../state/covers.dart';
import '../state/guard_controller.dart';
import '../state/guard_state.dart';
import '../theme/tokens.dart';
import '../ui/parts.dart';
import '../ui/words.dart';
import 'digest_screen.dart';
import 'pack_screen.dart';
import 'permissions_screen.dart';
import 'tracker_screen.dart';

/// Home: one hero fact. The countdown to the next cover, the cover that's on,
/// or all clear. Everything else is one line or one number beneath it.
/// Boards: docs/redesign/grok-final/phone/home-*.png.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.now});

  /// Injected by tests; the controller's clock otherwise.
  final DateTime? now;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// What the hero says right now.
enum HeroPhase { live, soon, next, clear }

class _HomeScreenState extends State<HomeScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Seconds matter four minutes before CPI.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = GuardScope.of(context);
    final c = ControllerScope.of(context);
    final now = (widget.now ?? c.now).toUtc();
    final covers = coversFor(state, test: c.testWindow);
    final wide = MediaQuery.sizeOf(context).width >= Tokens.compactMax;

    final hero = _Hero.at(covers, now);
    final t = state.tracker;
    final today = Tracker.dateKey(now.toLocal());
    final room = t.roomLeft(today);
    final tomorrowCount = covers.where((x) => dayWord(x.opens, now) == 'Tomorrow').length;

    final notices = <Widget>[
      if (state.missingPermissions.isNotEmpty) const PermissionBanner(),
      if (!state.isSample && (state.calendarAge == null || state.calendarAge! > const Duration(minutes: 60)))
        _Notice(
          key: const Key('home-feed-stale'),
          text: state.calendarAge == null
              ? "The news calendar hasn't loaded yet. Times below may be missing."
              : 'The news calendar is ${state.calendarAge!.inMinutes} minutes old. Times may have moved.',
        ),
      if (state.rulesChanged != null && state.flags.rulesChangedFlag)
        _Notice(
          key: const Key('home-rules-changed'),
          text: "${state.packs.index[state.rulesChanged!.firmId]?.firmName ?? 'Your firm'} changed its news rules. Tap to see what moved.",
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PackScreen(firmId: state.rulesChanged!.firmId))),
        ),
      if (t.weekendWarning && now.toLocal().weekday == DateTime.friday && now.toLocal().hour >= 12)
        const _Notice(
          key: Key('home-weekend'),
          text: 'Weekend hold: be flat before the close unless your firm allows holding over the weekend.',
        ),
      for (final note in state.engineNotes.map(_plainNote).whereType<String>().toSet())
        _Notice(key: const Key('home-notes'), text: note),
    ];

    final metrics = Row(children: [
      Expanded(
        child: MetricTile(
          key: const Key('home-loss'),
          label: 'Loss room',
          value: room == null ? 'Set' : money(t.currency, room),
          onTap: () => _openTracker(context),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: MetricTile(
          key: const Key('home-days'),
          label: 'Days',
          value: t.minTradingDays == 0 ? 'Off' : '${t.tradedDays()} of ${t.minTradingDays}',
          onTap: () => _openTracker(context),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: MetricTile(
          key: const Key('home-tomorrow'),
          label: 'Tomorrow',
          value: '$tomorrowCount',
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DigestScreen(now: widget.now))),
        ),
      ),
    ]);

    final column = [
      _Header(state: state, phase: hero.phase),
      const SizedBox(height: 14),
      for (final n in notices) ...[n, const SizedBox(height: 10)],
      _HeroPanel(hero: hero, now: now),
      if (hero.peek != null) ...[
        const SizedBox(height: 10),
        _Peek(label: hero.peekLabel, cover: hero.peek!, now: now),
      ],
      const SizedBox(height: 10),
      metrics,
      const Promise(),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 12, Tokens.gutter, Tokens.gutter),
      children: [
        if (wide)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: column),
            ),
          )
        else
          ...column,
      ],
    );
  }

  static void _openTracker(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TrackerScreen()));

  /// Engine notes in the trader's words. Unknown notes stay out of sight.
  static String? _plainNote(String note) {
    if (note.contains('needs Pro')) return "Your firm's rules need Pro. Guard is using its standard cover.";
    if (note.contains('not downloaded')) return "Your firm's rules haven't downloaded yet. Guard is using its standard cover.";
    if (note.contains('account type')) return "Pick your account type in Settings to use your firm's rules.";
    if (note.contains('unverified')) return "Your firm's rules aren't checked yet, so Guard uses the wider window.";
    if (note.contains('does not restrict')) return "Your firm doesn't restrict news on this account.";
    return null;
  }
}

class _Hero {
  _Hero(this.phase, this.cover, this.remaining, this.progress, this.peek, this.peekLabel, this.endedToday);

  final HeroPhase phase;
  final Cover? cover;
  final Duration remaining;
  final double progress;
  final Cover? peek;
  final String peekLabel;
  final bool endedToday;

  static const soonLead = Duration(minutes: 5);

  factory _Hero.at(List<Cover> covers, DateTime now) {
    final live = covers.where((c) => c.liveAt(now)).toList();
    final ahead = covers.where((c) => c.opens.isAfter(now)).toList();
    final endedToday = covers.any((c) => c.endedAt(now) && sameLocalDay(c.opens, now));

    Cover? peekAfter(Cover? hero) {
      for (final c in ahead) {
        if (!identical(c, hero)) return c;
      }
      return null;
    }

    String peekLabelFor(Cover? p) => p != null && sameLocalDay(p.opens, now) ? 'Also today' : 'Next cover';

    if (live.isNotEmpty) {
      final c = live.reduce((a, b) => b.closes.isAfter(a.closes) ? b : a);
      final left = c.closes.difference(now);
      final whole = c.closes.difference(c.opens).inSeconds;
      final p = peekAfter(c);
      return _Hero(HeroPhase.live, c, left, whole <= 0 ? 0 : left.inSeconds / whole, p, peekLabelFor(p), endedToday);
    }
    final next = ahead.isEmpty ? null : ahead.first;
    if (next != null && sameLocalDay(next.opens, now)) {
      final left = next.opens.difference(now);
      final soon = left <= soonLead;
      final scale = soon ? soonLead : const Duration(hours: 1);
      final p = peekAfter(next);
      return _Hero(soon ? HeroPhase.soon : HeroPhase.next, next, left,
          (left.inSeconds / scale.inSeconds).clamp(0.0, 1.0), p, peekLabelFor(p), endedToday);
    }
    return _Hero(HeroPhase.clear, null, Duration.zero, 1, next, 'Next cover', endedToday);
  }

  Color get color => switch (phase) {
        HeroPhase.live => Tokens.red,
        HeroPhase.soon => Tokens.amber,
        HeroPhase.next || HeroPhase.clear => Tokens.sky,
      };

  String get kicker => switch (phase) {
        HeroPhase.live => 'Cover is on',
        HeroPhase.soon => 'Opens soon',
        HeroPhase.next => 'Next cover',
        HeroPhase.clear => 'All clear',
      };
}

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.phase});

  final GuardState state;
  final HeroPhase phase;

  @override
  Widget build(BuildContext context) {
    final shade = Shade.of(context);
    final protection = state.settings['protection'] as String? ?? 'soft-gate';
    final what = switch (protection) {
      'warn-only' => 'Warnings only',
      'hard-block' => 'Block is on',
      _ => 'Cover is on',
    };
    final markets = marketsLine(state.instruments.map((i) => i['symbol'] as String));
    final dot = switch (phase) {
      HeroPhase.live => Tokens.red,
      HeroPhase.soon => Tokens.amber,
      HeroPhase.next => Tokens.sky,
      HeroPhase.clear => Tokens.statusClear,
    };
    return Row(children: [
      Text('Guard', style: TextStyle(fontFamily: Tokens.displayFamily, fontSize: 20, fontWeight: FontWeight.w600, color: shade.text)),
      const SizedBox(width: 12),
      const Spacer(),
      Flexible(
        flex: 4,
        child: Container(
          key: const Key('home-status'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: shade.surface,
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
            border: Border.all(color: shade.hairline),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 7),
            Flexible(
              child: Text(markets.isEmpty ? what : '$what · $markets',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 12, fontWeight: FontWeight.w600, color: shade.muted)),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.hero, required this.now});

  final _Hero hero;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final shade = Shade.of(context);
    final cover = hero.cover;
    final big = hero.phase == HeroPhase.clear ? 'Clear' : countdown(hero.remaining);
    final under = switch (hero.phase) {
      HeroPhase.live => 'until you can trade again',
      HeroPhase.soon || HeroPhase.next => 'until cover starts',
      HeroPhase.clear => hero.endedToday ? 'nothing else today' : 'nothing today',
    };
    return Panel(
      key: const Key('home-hero'),
      accent: hero.phase == HeroPhase.live || hero.phase == HeroPhase.soon ? hero.color : null,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(children: [
        Kicker(hero.kicker, key: Key('home-phase-${hero.phase.name}'), color: hero.phase == HeroPhase.next ? shade.accent : hero.color, size: 12),
        const SizedBox(height: 18),
        PhaseRing(
          size: 168,
          stroke: Tokens.ringStrokeHome,
          color: hero.color,
          progress: hero.progress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              FittedBox(
                child: Text(big,
                    key: const Key('home-countdown'),
                    style: TextStyle(
                      fontFamily: Tokens.displayFamily,
                      fontSize: 40,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1,
                      color: hero.phase == HeroPhase.next ? shade.text : hero.color,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )),
              ),
              const SizedBox(height: 8),
              Kicker(under, size: 9),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        if (cover != null) ...[
          Text('${cover.markets} · ${cover.title}',
              key: const Key('home-what'),
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: Tokens.displayFamily, fontSize: Tokens.typeSymbol, fontWeight: FontWeight.w600, color: shade.text)),
          const SizedBox(height: 6),
          Text('${dayWord(cover.opens, now)} · ${span(cover.opens, cover.closes)}',
              style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 15, color: shade.muted)),
        ] else
          Text(hero.endedToday ? 'No more high impact news for you today.' : 'No high impact news for you today.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 15, color: shade.muted)),
      ]),
    );
  }
}

class _Peek extends StatelessWidget {
  const _Peek({required this.label, required this.cover, required this.now});

  final String label;
  final Cover cover;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final shade = Shade.of(context);
    final today = sameLocalDay(cover.opens, now);
    return Panel(
      key: const Key('home-peek'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      // The event name gives way first; the label only goes on very narrow
      // screens, where the bars and the time still say it.
      child: LayoutBuilder(builder: (context, box) {
        return Row(children: [
          if (box.maxWidth >= 330) ...[Kicker(label), const SizedBox(width: 12)],
          ImpactBars(cover.impact, height: 11),
          const SizedBox(width: 8),
          Expanded(
            child: Text(cover.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 13, fontWeight: FontWeight.w600, color: shade.text)),
          ),
          const SizedBox(width: 8),
          Text(today ? clock(cover.opens) : '${dayWord(cover.opens, now)} · ${clock(cover.opens)}',
              maxLines: 1,
              style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 13, color: shade.muted)),
        ]);
      }),
    );
  }
}

/// A plain amber note above the hero: stale feed, rule change, weekend.
class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Panel(
        accent: Tokens.amber,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: onTap,
        child: Row(children: [
          Expanded(child: Text(text, style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 13, color: Shade.of(context).text))),
          if (onTap != null) Icon(Icons.chevron_right, size: 18, color: Shade.of(context).muted),
        ]),
      );
}
