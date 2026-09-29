import 'package:flutter/material.dart';

import '../platform/platform_bridge.dart';
import '../state/guard_controller.dart';
import '../state/guard_state.dart';
import '../theme/tokens.dart';

/// Three screens, plain words, obvious defaults. Everything a new trader
/// doesn't need to decide on day one (protection mode, rules, firm, window
/// width) starts on the safe default and lives in Settings.
///
/// 1. What do you trade? Gold is picked for you.
/// 2. Turn on alerts. One button, and the apps to cover where the phone allows it.
/// 3. You're set. What Guard will do, in three lines.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _page = PageController();
  int _step = 0;

  final List<Map<String, dynamic>> _instruments = [
    {'symbol': 'XAUUSD', 'basket': ['USD', 'EUR', 'GBP']},
  ];
  List<GateableApp> _apps = const [];
  final Set<String> _gated = {'net.metaquotes.metatrader5'};

  static const _steps = 3;

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
    if (_step < _steps - 1) {
      setState(() => _step++);
      await _page.animateToPage(_step, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      return;
    }
    final c = ControllerScope.of(context);
    await c.updateSettings({
      'protection': 'soft-gate',
      'mode': 'conservative',
      'windowBeforeMin': 5,
      'windowAfterMin': 5,
    });
    await c.replaceInstruments(_instruments);
    await c.setGatedApps(_gated.toList());
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
    final text = Theme.of(context).textTheme;
    final notificationsOn = state.permissions[GuardPermission.notifications] == true;
    final nextLabel = switch (_step) {
      0 => 'Next',
      1 => notificationsOn ? 'Next' : 'Skip for now',
      _ => 'Start',
    };

    final pages = [
      _Step(
        title: 'What do you trade?',
        subtitle: state.pro
            ? 'Pick your instruments. You can change them any time in Settings.'
            : 'Pick up to two. You can change them any time in Settings.',
        child: _InstrumentPicker(
          selected: _instruments,
          max: state.pro ? 50 : 2,
          onChanged: (v) => setState(() => _instruments
            ..clear()
            ..addAll(v)),
        ),
      ),
      _Step(
        title: 'Turn on alerts',
        subtitle: 'Guard warns you before high impact news, so you are never caught in a trade.',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (notificationsOn)
            const _Done(key: Key('onboarding-notifications-on'), label: 'Alerts are on')
          else
            FilledButton(
              key: const Key('onboarding-allow-notifications'),
              onPressed: () => c.requestPermission(GuardPermission.notifications),
              child: const Text('Allow alerts'),
            ),
          const SizedBox(height: 8),
          Text('They reach you with the phone locked, 60, 15, 5 and 1 minute before the news.', style: text.bodySmall),
          if (c.bridge.hasGate) ...[
            const SizedBox(height: Tokens.gutter * 1.5),
            Text('Cover your trading apps', style: text.titleMedium),
            const SizedBox(height: 4),
            Text('During the news, these apps are covered so you can\'t trade by accident.', style: text.bodySmall),
            const SizedBox(height: 8),
            if (c.bridge.usesSystemPicker)
              _gated.contains('screen-time')
                  ? const _Done(key: Key('onboarding-apps-chosen'), label: 'Apps chosen')
                  : OutlinedButton(
                      key: const Key('gate-pick'),
                      onPressed: () async {
                        if (await c.bridge.pickApps()) {
                          setState(() => _gated
                            ..clear()
                            ..add('screen-time'));
                        }
                      },
                      child: const Text('Choose apps'),
                    )
            else
              for (final app in _apps)
                CheckboxListTile(
                  key: Key('gate-${app.id}'),
                  value: _gated.contains(app.id),
                  onChanged: (v) => setState(() => v == true ? _gated.add(app.id) : _gated.remove(app.id)),
                  title: Text(app.label),
                  contentPadding: EdgeInsets.zero,
                ),
          ],
        ]),
      ),
      _Step(
        title: 'You\'re set',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _Line(icon: Icons.notifications_active_outlined, text: 'Before high impact news, Guard warns you in good time.'),
          if (c.bridge.hasGate)
            const _Line(icon: Icons.shield_outlined, text: 'During the news, your trading apps are covered until it\'s safe.'),
          const _Line(icon: Icons.lock_outline, text: 'Guard never touches your trades, your account or your broker.'),
          const SizedBox(height: Tokens.gutter),
          Text('Change anything later in Settings. Not financial advice, and your firm\'s rules come first.', style: text.bodySmall),
        ]),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Tokens.gutter, 12, Tokens.gutter, 0),
            child: Row(children: [
              for (var i = 0; i < _steps; i++)
                Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: i <= _step ? Tokens.sky : Tokens.skyHairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
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
                  onPressed: _instruments.isEmpty ? null : _next,
                  child: Text(nextLabel),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(Tokens.gutter),
      children: [
        const SizedBox(height: 8),
        Text(title, style: text.headlineMedium),
        if (subtitle != null) ...[const SizedBox(height: 8), Text(subtitle!, style: text.bodyLarge)],
        const SizedBox(height: Tokens.gutter * 1.5),
        child,
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Tokens.sky.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Tokens.radius),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle, color: Tokens.sky),
        const SizedBox(width: 10),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
      ]),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Tokens.sky),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
      ]),
    );
  }
}

class _InstrumentPicker extends StatelessWidget {
  const _InstrumentPicker({required this.selected, required this.max, required this.onChanged});

  final List<Map<String, dynamic>> selected;
  final int max;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  static const _common = [
    ('XAUUSD', 'Gold'),
    ('EURUSD', 'Euro'),
    ('GBPUSD', 'Pound'),
    ('USDJPY', 'Yen'),
    ('US30', 'Dow'),
    ('US500', 'S&P 500'),
    ('USTEC', 'Nasdaq'),
    ('DE40', 'DAX'),
    ('UK100', 'FTSE'),
    ('BTCUSD', 'Bitcoin'),
  ];

  @override
  Widget build(BuildContext context) {
    final chosen = selected.map((i) => i['symbol'] as String).toSet();
    final full = chosen.length >= max;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final (symbol, name) in _common)
        FilterChip(
          key: Key('inst-$symbol'),
          label: Text('$name  $symbol'),
          selected: chosen.contains(symbol),
          onSelected: !chosen.contains(symbol) && full
              ? null
              : (on) {
                  final next = [...selected];
                  if (on) {
                    next.add({'symbol': symbol});
                  } else {
                    next.removeWhere((i) => i['symbol'] == symbol);
                  }
                  onChanged(next);
                },
        ),
    ]);
  }
}
