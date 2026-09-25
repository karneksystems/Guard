import 'package:flutter/material.dart';

import '../platform/platform_bridge.dart';
import '../state/guard_controller.dart';
import '../state/guard_state.dart';
import '../theme/tokens.dart';

/// Six steps, per the brief: protection mode, instruments, rule mode (plus firm
/// when Firm match), window default, which apps to gate, and the "we never touch
/// your trades" explainer. Every choice is editable afterwards in Settings.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _page = PageController();
  int _step = 0;

  String _protection = 'soft-gate';
  final List<Map<String, dynamic>> _instruments = [
    {'symbol': 'XAUUSD', 'basket': ['USD', 'EUR', 'GBP']},
  ];
  String _mode = 'conservative';
  String? _firmId;
  int _before = 5;
  int _after = 5;
  List<GateableApp> _apps = const [];
  final Set<String> _gated = {'net.metaquotes.metatrader5'};

  static const _steps = 6;

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
      'protection': _protection,
      'mode': _mode,
      'firmId': _firmId,
      'windowBeforeMin': _before,
      'windowAfterMin': _after,
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
    final pro = GuardScope.of(context).pro;
    final c = ControllerScope.of(context);
    final text = Theme.of(context).textTheme;
    final pages = [
      _Step(
        title: 'How should it protect you?',
        child: _Choice(
          value: _protection,
          onChanged: (v) => setState(() => _protection = v),
          options: [
            ('warn-only', 'Warn only', 'Alerts and a timer. MT5 always opens.'),
            ('soft-gate', 'Soft gate', 'Opening MT5 in a window shows a full-screen gate with a countdown. You can still hold to view.'),
            ('hard-block', pro ? 'Hard block' : 'Hard block (Pro)', 'Trading apps locked until the window ends.'),
          ],
          disabled: pro ? const {} : const {'hard-block'},
        ),
      ),
      _Step(
        title: 'What do you trade?',
        subtitle: pro ? null : 'Free covers two instruments.',
        child: _InstrumentPicker(
          selected: _instruments,
          max: pro ? 50 : 2,
          onChanged: (v) => setState(() => _instruments
            ..clear()
            ..addAll(v)),
        ),
      ),
      _Step(
        title: 'Which rules?',
        child: Column(children: [
          _Choice(
            value: _mode,
            onChanged: (v) => setState(() => _mode = v),
            options: [
              ('conservative', 'Conservative', 'High-impact events whose currency touches your instruments. Gold counts USD, EUR and GBP.'),
              ('firm-match', pro ? 'Firm match' : 'Firm match (Pro)', 'Your firm\'s official pack: window, event list, source and verified date.'),
            ],
            disabled: pro ? const {} : const {'firm-match'},
          ),
          if (_mode == 'firm-match') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('firm'),
              initialValue: _firmId,
              decoration: const InputDecoration(labelText: 'Firm'),
              items: const [
                DropdownMenuItem(value: 'ftmo', child: Text('FTMO')),
                DropdownMenuItem(value: 'fundednext', child: Text('FundedNext')),
                DropdownMenuItem(value: 'fundingpips', child: Text('FundingPips')),
                DropdownMenuItem(value: 'alpha-capital', child: Text('Alpha Capital')),
                DropdownMenuItem(value: 'blue-guardian', child: Text('Blue Guardian')),
              ],
              onChanged: (v) => setState(() => _firmId = v),
            ),
            const SizedBox(height: 8),
            Text('Packs are marked unverified until a human has read the firm\'s page.', style: text.bodySmall),
          ],
        ]),
      ),
      _Step(
        title: 'How wide a window?',
        subtitle: pro ? 'Minutes before and after each event.' : 'Free uses 5 minutes either side. Pro unlocks presets and custom.',
        child: _WindowPicker(
          before: _before,
          after: _after,
          enabled: pro,
          onChanged: (b, a) => setState(() {
            _before = b;
            _after = a;
          }),
        ),
      ),
      _Step(
        title: 'Which apps to gate?',
        subtitle: 'This stays on your device. We never send it anywhere.',
        child: Column(children: [
          if (!c.bridge.hasGate)
            Text('This build can\'t cover apps on this device yet. The alerts still work, and the gate arrives with the next build.', style: text.bodyMedium)
          else if (c.bridge.usesSystemPicker) ...[
            Text('Apple\'s Screen Time picker chooses the apps. We only ever hold a token; not even we learn which apps you picked.', style: text.bodyMedium),
            const SizedBox(height: 12),
            FilledButton.tonal(
              key: const Key('gate-pick'),
              onPressed: () async {
                if (await c.bridge.pickApps()) {
                  setState(() => _gated
                    ..clear()
                    ..add('screen-time'));
                }
              },
              child: Text(_gated.contains('screen-time') ? 'Apps chosen. Change' : 'Choose apps'),
            ),
          ] else
          for (final app in _apps)
            CheckboxListTile(
              key: Key('gate-${app.id}'),
              value: _gated.contains(app.id),
              onChanged: (v) => setState(() => v == true ? _gated.add(app.id) : _gated.remove(app.id)),
              title: Text(app.label),
              subtitle: Text(app.installed ? 'Installed' : 'Not installed'),
              contentPadding: EdgeInsets.zero,
            ),
        ]),
      ),
      _Step(
        title: 'We never touch your trades.',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('No account login. No master password. No trade API. Nothing your firm can see.', style: text.bodyLarge),
          const SizedBox(height: 12),
          Text('The guard reads a licensed economic calendar, works out your restricted windows, and gets between you and MT5 when one is open. That\'s all it does.', style: text.bodyMedium),
          const SizedBox(height: 12),
          Text('Not a broker. Not affiliated with any firm. Not financial advice. Your firm\'s current rules are your responsibility, and times can change.', style: text.bodySmall),
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
                    height: 3,
                    margin: const EdgeInsets.only(right: 4),
                    color: i <= _step ? Tokens.metal : Tokens.champagneHairline,
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
                  onPressed: _next,
                  child: Text(_step == _steps - 1 ? 'Start guarding' : 'Next'),
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
        Text(title, style: text.headlineMedium),
        if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: text.bodySmall)],
        const SizedBox(height: Tokens.gutter),
        child,
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.value, required this.onChanged, required this.options, this.disabled = const {}});

  final String value;
  final ValueChanged<String> onChanged;
  final List<(String, String, String)> options;
  final Set<String> disabled;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<String>(
      groupValue: value,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      child: Column(children: [
        for (final (id, label, body) in options)
          Card(
            child: RadioListTile<String>(
              key: Key('choice-$id'),
              value: id,
              enabled: !disabled.contains(id),
              title: Text(label),
              subtitle: Text(body),
            ),
          ),
      ]),
    );
  }
}

class _InstrumentPicker extends StatelessWidget {
  const _InstrumentPicker({required this.selected, required this.max, required this.onChanged});

  final List<Map<String, dynamic>> selected;
  final int max;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  static const _common = ['XAUUSD', 'EURUSD', 'GBPUSD', 'USDJPY', 'US30', 'US500', 'USTEC', 'DE40', 'UK100', 'BTCUSD'];

  @override
  Widget build(BuildContext context) {
    final chosen = selected.map((i) => i['symbol'] as String).toSet();
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final s in _common)
        FilterChip(
          key: Key('inst-$s'),
          label: Text(s),
          selected: chosen.contains(s),
          onSelected: (on) {
            final next = [...selected];
            if (on) {
              if (next.length >= max) return;
              next.add({'symbol': s});
            } else {
              next.removeWhere((i) => i['symbol'] == s);
            }
            onChanged(next);
          },
        ),
    ]);
  }
}

class _WindowPicker extends StatelessWidget {
  const _WindowPicker({required this.before, required this.after, required this.enabled, required this.onChanged});

  final int before;
  final int after;
  final bool enabled;
  final void Function(int before, int after) onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, children: [
      for (final m in const [2, 3, 5, 10])
        ChoiceChip(
          key: Key('window-$m'),
          label: Text('$m min'),
          selected: before == m && after == m,
          onSelected: enabled ? (_) => onChanged(m, m) : null,
        ),
    ]);
  }
}
