import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../ui/parts.dart';
import '../ui/words.dart';

/// The cover, in Flutter: desktop, and the reference the Android and iPhone
/// covers follow. Arc countdown, four facts, the promise, Stay out, and Hold
/// to look only for three seconds. Block hides the second action.
/// Boards: docs/redesign/grok-final/phone/gate-*.png.
class GateScreen extends StatefulWidget {
  const GateScreen({
    super.key,
    required this.what,
    required this.opensAtUtc,
    required this.closesAtUtc,
    required this.hardBlock,
    required this.onStayOut,
    required this.onView,
    required this.onExpired,
    this.impact = 'high',
    this.holdDuration = Tokens.holdToView,
    this.now,
  });

  /// "Gold · EUR CPI".
  final String what;
  final DateTime opensAtUtc;
  final DateTime closesAtUtc;
  final bool hardBlock;
  final String impact;
  final VoidCallback onStayOut;
  final VoidCallback onView;
  final VoidCallback onExpired;
  final Duration holdDuration;

  /// Injectable clock for tests.
  final DateTime Function()? now;

  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen>
    with SingleTickerProviderStateMixin {
  Timer? _tick;
  Timer? _hold;
  late final AnimationController _holdProgress = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
  );

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
    _holdProgress.dispose();
    super.dispose();
  }

  void _startHold() {
    _holdProgress.forward(from: 0);
    setState(() {});
    _hold = Timer(widget.holdDuration, () {
      if (mounted) widget.onView();
    });
  }

  void _cancelHold() {
    _hold?.cancel();
    _holdProgress.reset();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final now = _now;
    final soon = now.isBefore(widget.opensAtUtc);
    final color = soon ? Tokens.amber : Tokens.red;
    final target = soon ? widget.opensAtUtc : widget.closesAtUtc;
    final left = target.difference(now);
    final whole = soon
        ? const Duration(minutes: 5)
        : widget.closesAtUtc.difference(widget.opensAtUtc);
    final progress = whole.inSeconds <= 0
        ? 0.0
        : (left.inSeconds / whole.inSeconds).clamp(0.0, 1.0);
    final kicker = soon
        ? 'Opens soon'
        : (widget.hardBlock ? 'Block is on' : 'Cover is on');
    final holding = _holdProgress.isAnimating || _holdProgress.value > 0;

    return Scaffold(
      backgroundColor: Tokens.inkBg,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.55),
            radius: 1.1,
            colors: [color.withValues(alpha: 0.16), Tokens.inkBg],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: CustomPaint(
                  painter: _Corners(color),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(width: 18, height: 1, color: color),
                            const SizedBox(width: 8),
                            Kicker(
                              kicker,
                              key: const Key('gate-kicker'),
                              color: color,
                              size: 11,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: PhaseRing(
                            size: 220,
                            stroke: Tokens.ringStrokeGate,
                            color: color,
                            progress: progress,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  countdown(left),
                                  key: const Key('gate-countdown'),
                                  style: TextStyle(
                                    fontFamily: Tokens.displayFamily,
                                    fontSize: Tokens.typeDisplayGate,
                                    height: 1,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -2,
                                    color: color,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: 120,
                                  child: Text(
                                    soon
                                        ? 'until cover starts'
                                        : 'until you can trade again',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: Tokens.bodyFamily,
                                      fontSize: 12,
                                      color: Tokens.inkTextMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _Fact(
                                label: 'What',
                                value: widget.what,
                                tint: color,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _Fact(
                                label: 'When',
                                value:
                                    '${dayWord(widget.opensAtUtc, now)} · ${span(widget.opensAtUtc, widget.closesAtUtc)}',
                                tint: color,
                                valueColor: Tokens.sky,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _Fact(
                                label: 'Mode',
                                value: widget.hardBlock
                                    ? 'Block · no look'
                                    : 'Cover · look ok',
                                tint: color,
                                valueColor: Tokens.sky,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _Fact(
                                label: 'Impact',
                                tint: color,
                                valueWidget: Row(
                                  children: [
                                    ImpactBars(widget.impact, height: 12),
                                    const SizedBox(width: 6),
                                    Text(
                                      impactWord(widget.impact),
                                      style: TextStyle(
                                        fontFamily: Tokens.bodyFamily,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: impactColor(widget.impact),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          widget.hardBlock
                              ? "We never touch your trades. Trading now may break your firm's rules."
                              : "We never touch your trades. Looking is fine. Trading now may break your firm's rules.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: Tokens.bodyFamily,
                            fontSize: 13,
                            height: 1.4,
                            color: Tokens.inkTextMuted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 52,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                Tokens.radiusSm,
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color.lerp(color, Colors.white, 0.12)!,
                                  color,
                                ],
                              ),
                            ),
                            child: FilledButton(
                              key: const Key('gate-stay-out'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: soon
                                    ? Tokens.brandDeep
                                    : Colors.white,
                                shadowColor: Colors.transparent,
                              ),
                              onPressed: widget.onStayOut,
                              child: const Text('Stay out'),
                            ),
                          ),
                        ),
                        if (!widget.hardBlock) ...[
                          const SizedBox(height: 10),
                          Listener(
                            key: const Key('gate-hold-view'),
                            onPointerDown: (_) => _startHold(),
                            onPointerUp: (_) => _cancelHold(),
                            onPointerCancel: (_) => _cancelHold(),
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Tokens.inkText,
                                side: BorderSide(
                                  color: Tokens.sky.withValues(alpha: 0.35),
                                ),
                                backgroundColor: Tokens.inkSurface,
                              ),
                              onPressed: () {},
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedBuilder(
                                    animation: _holdProgress,
                                    builder: (_, _) => SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CustomPaint(
                                        painter: _HoldDial(_holdProgress.value),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    holding
                                        ? 'Keep holding…'
                                        : 'Hold to look only',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.label,
    required this.tint,
    this.value,
    this.valueColor,
    this.valueWidget,
  });

  final String label;
  final Color tint;
  final String? value;
  final Color? valueColor;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
    decoration: BoxDecoration(
      color: Color.alphaBlend(tint.withValues(alpha: 0.04), Tokens.inkSurface),
      borderRadius: BorderRadius.circular(Tokens.radius),
      border: Border.all(color: tint.withValues(alpha: 0.28)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Kicker(label, size: 9),
        const SizedBox(height: 6),
        valueWidget ??
            Text(
              value ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: Tokens.bodyFamily,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Tokens.inkText,
              ),
            ),
      ],
    ),
  );
}

/// Corner brackets round the cover, in the phase colour.
class _Corners extends CustomPainter {
  _Corners(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const l = 16.0;
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final w = size.width;
    final h = size.height;
    for (final (x, y, dx, dy) in [
      (0.0, 0.0, 1.0, 1.0),
      (w, 0.0, -1.0, 1.0),
      (0.0, h, 1.0, -1.0),
      (w, h, -1.0, -1.0),
    ]) {
      canvas.drawLine(Offset(x, y), Offset(x + l * dx, y), p);
      canvas.drawLine(Offset(x, y), Offset(x, y + l * dy), p);
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_Corners old) => old.color != color;
}

/// Fills over the three second hold.
class _HoldDial extends CustomPainter {
  _HoldDial(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1.5);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Tokens.sky.withValues(alpha: 0.25),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * (value == 0 ? 0.25 : value),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = Tokens.sky,
    );
  }

  @override
  bool shouldRepaint(_HoldDial old) => old.value != value;
}
