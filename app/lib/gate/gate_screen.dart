import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The gate, in Flutter, for desktop. Same content and actions as the Android
/// native one: countdown, events, instrument, the promise, Stay out, Hold to
/// view only for three seconds. Hard block hides the second action.
class GateScreen extends StatefulWidget {
  const GateScreen({
    super.key,
    required this.instrument,
    required this.events,
    required this.closesAtUtc,
    required this.hardBlock,
    required this.onStayOut,
    required this.onView,
    required this.onExpired,
    this.holdDuration = const Duration(seconds: 3),
    this.now,
  });

  final String instrument;
  final String events;
  final DateTime closesAtUtc;
  final bool hardBlock;
  final VoidCallback onStayOut;
  final VoidCallback onView;
  final VoidCallback onExpired;
  final Duration holdDuration;

  /// Injectable clock for tests.
  final DateTime Function()? now;

  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> {
  Timer? _tick;
  Timer? _hold;
  bool _holding = false;

  DateTime get _now => (widget.now ?? DateTime.now)().toUtc();

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_now.isBefore(widget.closesAtUtc)) {
        _tick?.cancel();
        widget.onExpired();
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _hold?.cancel();
    super.dispose();
  }

  void _startHold() {
    setState(() => _holding = true);
    _hold = Timer(widget.holdDuration, () {
      if (mounted) widget.onView();
    });
  }

  void _cancelHold() {
    _hold?.cancel();
    if (mounted) setState(() => _holding = false);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.closesAtUtc.difference(_now);
    final s = remaining.isNegative ? 0 : remaining.inSeconds;
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    final close = '${widget.closesAtUtc.hour.toString().padLeft(2, '0')}:${widget.closesAtUtc.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Tokens.inkBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('RESTRICTED WINDOW', style: TextStyle(fontFamily: Tokens.bodyFamily, color: Tokens.metal, fontSize: 13, letterSpacing: 2, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text('$mm:$ss', key: const Key('gate-countdown'), style: const TextStyle(fontFamily: Tokens.displayFamily, color: Tokens.inkText, fontSize: 96, height: 1, fontWeight: FontWeight.w600, letterSpacing: -2)),
                const SizedBox(height: 16),
                Text(widget.instrument, style: const TextStyle(fontFamily: Tokens.displayFamily, color: Tokens.inkText, fontSize: 36, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(widget.events.isEmpty ? 'High-impact release' : widget.events, style: const TextStyle(fontFamily: Tokens.bodyFamily, color: Tokens.inkText, fontSize: 20)),
                const SizedBox(height: 4),
                Text('Until $close UTC', style: const TextStyle(fontFamily: Tokens.bodyFamily, color: Tokens.inkTextMuted, fontSize: 15)),
                const SizedBox(height: 40),
                const Text('We never touch your trades. Viewing is fine. Trading may breach.', style: TextStyle(fontFamily: Tokens.bodyFamily, color: Tokens.inkTextMuted, fontSize: 15)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(key: const Key('gate-stay-out'), onPressed: widget.onStayOut, child: const Text('Stay out')),
                ),
                if (!widget.hardBlock) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: Listener(
                      key: const Key('gate-hold-view'),
                      onPointerDown: (_) => _startHold(),
                      onPointerUp: (_) => _cancelHold(),
                      onPointerCancel: (_) => _cancelHold(),
                      child: OutlinedButton(
                        onPressed: () {},
                        child: Text(_holding ? 'Keep holding…' : 'Hold to view only'),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
