import 'package:flutter/material.dart';

import '../billing/billing.dart';
import '../state/guard_controller.dart';
import '../theme/tokens.dart';

/// One SKU. What Pro adds, what it costs, one button per period, restore.
/// No countdown, no fake scarcity, no pre-ticked upsell.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  ({String monthly, String yearly})? _prices;
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
    final text = Theme.of(context).textTheme;
    final c = ControllerScope.of(context);
    final p = _prices;
    return Scaffold(
      appBar: AppBar(title: const Text('Pro')),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.gutter),
        children: [
          Text('Precision, not safety', style: text.headlineMedium),
          const SizedBox(height: 4),
          Text('Free already wakes you and gates the app. Pro matches your firm\'s exact rules.', style: text.bodyLarge),
          const SizedBox(height: Tokens.gutter),
          for (final line in const [
            'Firm match: your firm\'s pack, with a flag when its rules change',
            'Custom windows: 2, 3, 5, 10 minutes or your own',
            'Hard block where the platform allows it',
            'Unlimited instruments',
            'Full journal history and streak',
            'No ads',
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.check, size: 18, color: Tokens.metal),
                const SizedBox(width: 8),
                Expanded(child: Text(line)),
              ]),
            ),
          const SizedBox(height: Tokens.gutter),
          FilledButton(
            key: const Key('paywall-yearly'),
            onPressed: _busy || c.billing == null ? null : () => _go(Plan.yearly),
            child: Text('Yearly · ${p?.yearly ?? '£39'} (two months free)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('paywall-monthly'),
            onPressed: _busy || c.billing == null ? null : () => _go(Plan.monthly),
            child: Text('Monthly · ${p?.monthly ?? '£4.99'}'),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('paywall-restore'),
            onPressed: _busy || c.billing == null ? null : () => _go(Plan.monthly, restore: true),
            child: const Text('Restore purchases'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(_message!, key: const Key('paywall-message')),
          ],
          const SizedBox(height: Tokens.gutter),
          Text(
            'Renews until cancelled in your store account. Cancel any time; Pro runs to the end of the period. '
            'Being woken up is never behind this screen.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}
