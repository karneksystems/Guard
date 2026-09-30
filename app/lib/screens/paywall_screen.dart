import 'package:flutter/material.dart';

import '../billing/billing.dart';
import '../state/guard_controller.dart';
import '../theme/tokens.dart';
import '../ui/parts.dart';

/// One SKU. What Pro adds, what it costs, one button per period, restore.
/// No countdown, no fake scarcity, no pre-ticked upsell.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  ({String monthly, String yearly})? _prices;

  /// Yearly is the default choice, as on the board.
  Plan _plan = Plan.yearly;
  bool _busy = false;
  String? _message;

  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asked) return;
    _asked = true;
    ControllerScope.of(context).billing?.prices().then((p) {
      if (mounted) setState(() => _prices = p);
    });
  }

  Future<void> _go(Plan plan, {bool restore = false}) async {
    final c = ControllerScope.of(context);
    setState(() {
      _busy = true;
      _message = null;
    });
    final ok = await c.upgrade(plan, restore: restore);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = ok
          ? 'Pro is on.'
          : restore
              ? 'Nothing to restore on this store account.'
              : c.billing == null
                  ? 'Purchases open with the store build.'
                  : 'Not completed. You have not been charged.';
    });
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = ControllerScope.of(context);
    final shade = Shade.of(context);
    // Store prices when they arrive; the list price until then. Never greyed
    // out while loading, which reads as broken.
    final monthly = _prices?.monthly ?? '£4.99';
    final yearly = _prices?.yearly ?? '£39';
    final price = _plan == Plan.yearly ? '$yearly/year' : '$monthly/month';
    final canBuy = !_busy && c.billing != null;

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Tokens.gutter, 0, Tokens.gutter, Tokens.gutter),
        children: [
          Kicker("When Free isn't enough", color: shade.accent, size: 11),
          const SizedBox(height: 10),
          Text("Your firm's exact rules", style: TextStyle(fontFamily: Tokens.displayFamily, fontSize: 30, fontWeight: FontWeight.w600, color: shade.text, letterSpacing: -0.5, height: 1.15)),
          const SizedBox(height: 8),
          Text("Pro adds your firm's rules, Block, unlimited markets, and a full stay out log.",
              style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 14, color: shade.muted)),
          const SizedBox(height: 18),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: _PlanCard(
                key: const Key('paywall-monthly'),
                name: 'Monthly',
                price: monthly,
                sub: 'a month',
                on: _plan == Plan.monthly,
                onTap: canBuy ? () => _choose(Plan.monthly) : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PlanCard(
                key: const Key('paywall-yearly'),
                name: 'Yearly',
                price: yearly,
                sub: '${_perMonth(yearly)}/mo',
                badge: 'Best value',
                on: _plan == Plan.yearly,
                onTap: canBuy ? () => _choose(Plan.yearly) : null,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Panel(
            child: Column(children: [
              for (final line in const [
                "Your firm's rules, matched",
                'Block (no look)',
                'Unlimited markets',
                'Full log and streak',
                'Custom cover windows',
                'No ads',
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    Icon(Icons.check, size: 16, color: shade.accent),
                    const SizedBox(width: 12),
                    Expanded(child: Text(line, style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 15, color: shade.text))),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 14),
          FilledButton(
            key: const Key('paywall-start'),
            onPressed: canBuy ? () => _go(_plan) : null,
            child: Text(_busy ? 'One moment…' : 'Start Pro · $price'),
          ),
          TextButton(
            key: const Key('paywall-restore'),
            onPressed: canBuy ? () => _go(Plan.monthly, restore: true) : null,
            child: const Text('Restore purchases'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 4),
            Text(_message!, key: const Key('paywall-message'), textAlign: TextAlign.center, style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 14, color: shade.text)),
          ],
          Promise(text: c.billing == null ? 'Purchases open with the store build. We never touch your trades.' : 'Cancel anytime. Pro runs to the end of the period. We never touch your trades.'),
        ],
      ),
    );
  }

  /// A tap on a plan card only picks it. Buying is always the button.
  void _choose(Plan plan) => setState(() => _plan = plan);

  /// "£39" → "£3.25".
  static String _perMonth(String yearly) {
    final m = RegExp(r'^(\D*)([\d.,]+)').firstMatch(yearly);
    final n = double.tryParse(m?.group(2)?.replaceAll(',', '') ?? '');
    if (m == null || n == null) return yearly;
    return '${m.group(1)}${(n / 12).toStringAsFixed(2)}';
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({super.key, required this.name, required this.price, required this.sub, required this.on, this.onTap, this.badge});

  final String name;
  final String price;
  final String sub;
  final bool on;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shade = Shade.of(context);
    return Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
      Panel(
        accent: on ? Tokens.sky : null,
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
        child: SizedBox(
          width: double.infinity,
          child: Column(children: [
            Text(name, style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 13, fontWeight: FontWeight.w600, color: shade.muted)),
            const SizedBox(height: 6),
            Text(price, style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 28, fontWeight: FontWeight.w700, color: shade.text)),
            const SizedBox(height: 4),
            Text(sub, style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 12, color: shade.muted)),
          ]),
        ),
      ),
      if (badge != null)
        Positioned(
          top: -9,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Tokens.sky, borderRadius: BorderRadius.circular(Tokens.radiusPill)),
            child: Text(badge!.toUpperCase(),
                style: const TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Tokens.brandDeep)),
          ),
        ),
    ]);
  }
}
