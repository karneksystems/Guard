import 'package:flutter/material.dart';

import '../platform/platform_bridge.dart';
import '../state/covers.dart';
import '../state/guard_controller.dart';
import '../state/guard_state.dart';
import '../theme/tokens.dart';
import '../ui/calendar.dart';
import '../ui/parts.dart';
import '../ui/words.dart';

/// Setup, three screens. Boards: docs/redesign/grok-final/phone/setup-*.png.
///
/// 1. What do you trade? Gold and EUR are picked for you.
/// 2. Alerts and apps. Notifications, the apps to cover, alarms on time and
///    Tomorrow's news, each one switch.
/// 3. You're set. The first High window, and what happens next.
///
/// Mode, window width and firm rules start on the safe defaults and live in
/// Settings.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

/// A market the trader picks, and the instrument the engine watches for it.
class _Market {
  const _Market(this.name, this.sub, this.instrument);

  final String name;
  final String sub;
  final Map<String, dynamic> instrument;

  String get symbol => instrument['symbol'] as String;
}

const _markets = [
  _Market('Gold', 'High impact that moves gold', {'symbol': 'XAUUSD', 'basket': ['USD', 'EUR', 'GBP']}),
  _Market('EUR pairs', 'Euro news · CPI, ECB', {'symbol': 'EURUSD'}),
  _Market('US indices', 'US30, NAS100, US500', {'symbol': 'US500'}),
  _Market('GBP pairs', 'Sterling news · BoE', {'symbol': 'GBPUSD'}),
  _Market('JPY pairs', 'Yen news · BoJ', {'symbol': 'USDJPY'}),
];

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _page = PageController();
  int _step = 0;

  final List<String> _picked = ['XAUUSD', 'EURUSD'];
  List<GateableApp> _apps = const [];
  final Set<String> _gated = {'net.metaquotes.metatrader5'};
  bool _cover = true;
  bool _tomorrowNews = true;

  static const _steps = 3;

  List<Map<String, dynamic>> get _instruments => [
        for (final s in _picked) _markets.firstWhere((m) => m.symbol == s).instrument,
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final apps = await ControllerScope.of(context).bridge.listApps();
      if (mounted) setState(() => _apps = apps);
    });
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final c = ControllerScope.of(context);
    if (_step < _steps - 1) {
      // Step three previews the first window, so the engine needs the picks
      // now. Local only; the server hears once, at the end.
      if (_step == 1) c.state.applyInstruments(_instruments);
      setState(() => _step++);
      await _page.animateToPage(_step, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      return;
    }
    await c.updateSettings({
      'protection': 'soft-gate',
      'mode': 'conservative',
      'windowBeforeMin': 5,
      'windowAfterMin': 5,
    });
    await c.replaceInstruments(_instruments);
    await c.setGatedApps(_cover ? _gated.toList() : const []);
    if (!_tomorrowNews) await c.updateTracker(c.state.tracker.copyWith(tomorrowNews: false));
    await c.finishOnboarding();
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
    _page.animateToPage(_step, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final state = GuardScope.of(context);
    final c = ControllerScope.of(context);
    final shade = Shade.of(context);
    final notificationsOn = state.permissions[GuardPermission.notifications] == true;
    final alarmsAsked = c.bridge.supportedPermissions.contains(GuardPermission.exactAlarm);
    final alarmsOn = state.permissions[GuardPermission.exactAlarm] == true;
    final nextLabel = switch (_step) {
      0 => 'Continue',
      1 => notificationsOn ? 'Continue' : 'Skip for now',
      _ => 'Go to Home',
    };

    final pages = [
      _Step(
        title: 'What do you trade?',
        sub: Text.rich(TextSpan(children: [
          TextSpan(text: state.pro ? 'Pick what Guard should watch. We cover ' : 'Pick what Guard should watch. Free watches two. We cover '),
          const TextSpan(text: 'High', style: TextStyle(color: Tokens.red, fontWeight: FontWeight.w700)),
          const TextSpan(text: ' impact by default.'),
        ])),
        child: Column(children: [
          for (final m in _markets) ...[
            _MarketCard(
              market: m,
              on: _picked.contains(m.symbol),
              enabled: _picked.contains(m.symbol) || _picked.length < state.flags.instrumentsMax,
              onTap: () => setState(() => _picked.contains(m.symbol) ? _picked.remove(m.symbol) : _picked.add(m.symbol)),
            ),
            const SizedBox(height: 10),
          ],
        ]),
      ),
      _Step(
        title: 'Alerts and apps',
        sub: const Text('So Guard can warn you and cover MT5 when High news hits.'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(children: [
              _Toggle(
                key: notificationsOn ? const Key('onboarding-notifications-on') : null,
                switchKey: const Key('onboarding-allow-notifications'),
                title: 'Notifications',
                sub: '60 · 15 · 5 · 1 min ladder',
                value: notificationsOn,
                onChanged: notificationsOn ? null : (_) => c.requestPermission(GuardPermission.notifications),
              ),
              if (c.bridge.hasGate) ...[
                Divider(height: 1, color: shade.hairline),
                if (c.bridge.usesSystemPicker)
                  _Toggle(
                    title: 'Cover trading apps',
                    sub: _gated.contains('screen-time') ? 'Apps chosen' : 'Pick them in Screen Time',
                    switchKey: const Key('gate-pick'),
                    value: _gated.contains('screen-time'),
                    onChanged: (on) async {
                      if (!on) return setState(() => _gated.remove('screen-time'));
                      if (await c.bridge.pickApps()) {
                        setState(() => _gated
                          ..clear()
                          ..add('screen-time'));
                      }
                    },
                  )
                else
                  _Toggle(
                    key: const Key('onboarding-cover-row'),
                    title: 'Cover trading apps',
                    sub: _appsLine(),
                    switchKey: const Key('onboarding-cover'),
                    value: _cover,
                    onChanged: (v) => setState(() => _cover = v),
                    onTap: _cover ? _pickApps : null,
                  ),
              ],
              if (alarmsAsked) ...[
                Divider(height: 1, color: shade.hairline),
                _Toggle(
                  title: 'Alarms on time',
                  sub: 'Cover on the minute',
                  switchKey: const Key('onboarding-alarms'),
                  value: alarmsOn,
                  onChanged: alarmsOn ? null : (_) => c.requestPermission(GuardPermission.exactAlarm),
                ),
              ],
              Divider(height: 1, color: shade.hairline),
              _Toggle(
                title: "Tomorrow's news",
                sub: 'The High windows, the night before',
                switchKey: const Key('onboarding-tomorrow'),
                value: _tomorrowNews,
                onChanged: (v) => setState(() => _tomorrowNews = v),
              ),
            ]),
          ),
          if (alarmsAsked && !alarmsOn) ...[
            const SizedBox(height: 12),
            Panel(
              key: const Key('onboarding-alarms-warning'),
              accent: Tokens.amber,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Kicker('Alarms still off', color: Tokens.amber, size: 11),
                const SizedBox(height: 6),
                Text('Turn on Alarms on time or cover may land late.', style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 14, color: shade.text)),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          Text('We never touch your trades.', style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 13, color: shade.muted)),
        ]),
      ),
      _Done(markets: marketsLine(_picked), state: state, now: c.now.toUtc(), cover: c.bridge.hasGate && _cover),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Tokens.gutter, 16, Tokens.gutter, 0),
            child: Row(children: [
              for (var i = 0; i < _steps; i++)
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 7),
                  decoration: BoxDecoration(color: i <= _step ? Tokens.sky : shade.hairline, shape: BoxShape.circle),
                ),
            ]),
          ),
          Expanded(
            child: PageView(
              controller: _page,
              physics: const NeverScrollableScrollPhysics(),
              children: pages,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Tokens.gutter),
            child: Row(children: [
              if (_step > 0) ...[
                OutlinedButton(onPressed: _back, child: const Text('Back')),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton(
                  key: const Key('onboarding-next'),
                  onPressed: _picked.isEmpty ? null : _next,
                  child: Text(nextLabel),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  String _appsLine() {
    final names = [
      for (final a in _apps)
        if (_gated.contains(a.id)) a.label.replaceAll('MetaTrader ', 'MT'),
    ];
    return names.isEmpty ? 'Pick your trading apps' : names.join(', ');
  }

  Future<void> _pickApps() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(padding: const EdgeInsets.all(Tokens.gutter), child: Text('Apps to cover', style: Theme.of(ctx).textTheme.titleMedium)),
            for (final app in _apps)
              CheckboxListTile(
                key: Key('gate-${app.id}'),
                value: _gated.contains(app.id),
                onChanged: (v) {
                  setSheet(() => v == true ? _gated.add(app.id) : _gated.remove(app.id));
                  setState(() {});
                },
                title: Text(app.label),
              ),
            Padding(
              padding: const EdgeInsets.all(Tokens.gutter),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(key: const Key('gate-done'), onPressed: () => Navigator.of(ctx).pop(), child: const Text('Done')),
              ),
            ),
          ]),
        );
      }),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.title, required this.sub, required this.child});

  final String title;
  final Widget sub;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shade = Shade.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 20, Tokens.gutter, Tokens.gutter),
      children: [
        Text(title, style: TextStyle(fontFamily: Tokens.displayFamily, fontSize: 30, fontWeight: FontWeight.w600, color: shade.text, letterSpacing: -0.5)),
        const SizedBox(height: 8),
        DefaultTextStyle(style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 13, height: 1.4, color: shade.muted), child: sub),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _MarketCard extends StatelessWidget {
  const _MarketCard({required this.market, required this.on, required this.enabled, required this.onTap});

  final _Market market;
  final bool on;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shade = Shade.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Panel(
        key: Key('inst-${market.symbol}'),
        accent: on ? Tokens.sky : null,
        onTap: enabled ? onTap : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: on ? Tokens.sky : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: on ? Tokens.sky : shade.hairline, width: 1.5),
            ),
            child: on ? const Icon(Icons.check, size: 15, color: Tokens.brandDeep) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(market.name, style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 16, fontWeight: FontWeight.w600, color: shade.text)),
              const SizedBox(height: 2),
              Text(market.sub, style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 12, color: shade.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({super.key, required this.title, required this.sub, required this.value, required this.onChanged, this.switchKey, this.onTap});

  final String title;
  final String sub;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Key? switchKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shade = Shade.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 15, fontWeight: FontWeight.w600, color: shade.text)),
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 12, color: shade.muted)),
            ]),
          ),
          // A granted permission shows on and stays on; the OS owns turning it off.
          Switch(key: switchKey, value: value, onChanged: onChanged ?? (value ? (_) {} : null)),
        ]),
      ),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.markets, required this.state, required this.now, required this.cover});

  final String markets;
  final GuardState state;
  final DateTime now;
  final bool cover;

  @override
  Widget build(BuildContext context) {
    final shade = Shade.of(context);
    final covers = coversFor(state);
    final first = calendarFor(state, covers).where((e) => e.impact == 'high' && e.cover != null && e.cover!.closes.isAfter(now)).firstOrNull;
    final lead = cover ? 'Cover is on for $markets.' : 'Warnings are on for $markets.';
    final String sub;
    if (first == null) {
      sub = '$lead No High windows coming up yet.';
    } else if (sameLocalDay(first.at, now)) {
      sub = '$lead First High window today:';
    } else {
      sub = '$lead Next High window, ${dayWord(first.at, now) == 'Tomorrow' ? 'tomorrow' : dateShort(first.at)}:';
    }
    return _Step(
      title: "You're set",
      sub: Text(sub),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (first != null) ...[
          EventGroup(entries: [first], now: now, showEta: false),
          const SizedBox(height: 12),
        ],
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Kicker('What happens next', size: 11),
            const SizedBox(height: 8),
            Text(
              cover
                  ? "We'll warn you at 60, 15, 5 and 1 minute, then cover the app when news opens."
                  : "We'll warn you at 60, 15, 5 and 1 minute before the news.",
              key: const Key('onboarding-next-steps'),
              style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 15, height: 1.4, color: shade.text),
            ),
            const SizedBox(height: 10),
            Text('We never touch your trades.', style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 13, color: shade.muted)),
          ]),
        ),
      ]),
    );
  }
}
