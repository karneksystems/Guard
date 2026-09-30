import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../state/guard_controller.dart';
import '../state/guard_state.dart';
import '../state/news_phase.dart';
import '../theme/tokens.dart';

/// A coloured edge around the whole app while news is near: amber in the five
/// minutes before a window, red while it's open. It never takes a tap and it
/// never animates on a loop; it fades in once and sits still, and one timer
/// wakes it at the next change instead of polling. The same wake keeps the
/// Lock Screen countdown in step while the app is open.
class NewsGlow extends StatefulWidget {
  const NewsGlow({super.key, required this.child});

  final Widget child;

  @override
  State<NewsGlow> createState() => _NewsGlowState();
}

class _NewsGlowState extends State<NewsGlow> {
  GuardController? _controller;
  Timer? _wake;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = ControllerScope.of(context);
    if (!identical(c, _controller)) {
      _controller?.scheduleChanged.removeListener(_changed);
      _controller = c..scheduleChanged.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _controller?.scheduleChanged.removeListener(_changed);
    _wake?.cancel();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _armFor(List<DateTime?> changes) {
    _wake?.cancel();
    final times = changes.whereType<DateTime>().toList()..sort();
    if (times.isEmpty) return;
    final at = times.first;
    // A second past the boundary, so the next read lands on the new side of it.
    final wait = at.difference(_controller!.now.toUtc()) + const Duration(seconds: 1);
    _wake = Timer(wait.isNegative ? Duration.zero : wait, _changed);
  }

  @override
  Widget build(BuildContext context) {
    GuardScope.of(context); // rebuild when the windows change
    final c = _controller!;
    final news = c.newsNow();
    // Wake for whichever comes first: the glow's next change or the countdown's.
    _armFor([news.nextChange, c.countdownNow().nextChange]);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(c.syncCountdown()));
    final color = switch (news.phase) {
      NewsPhase.live => Tokens.red,
      NewsPhase.soon => Tokens.amber,
      NewsPhase.clear => null,
    };
    return Stack(fit: StackFit.passthrough, children: [
      widget.child,
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedOpacity(
            key: const Key('news-glow'),
            opacity: color == null ? 0 : 1,
            duration: const Duration(milliseconds: 400),
            child: color == null
                ? const SizedBox.expand()
                : CustomPaint(
                    key: Key('news-glow-${news.phase.name}'),
                    painter: _EdgePainter(news.phase == NewsPhase.live, _cornerRadius()),
                  ),
          ),
        ),
      ),
    ]);
  }

  /// Follow the screen's own corners so the edge doesn't cut across them.
  static double _cornerRadius() {
    if (kIsWeb) return 0;
    if (Platform.isIOS) return 47;
    if (Platform.isAndroid) return 24;
    return 0;
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter(this.red, this.radius);

  final bool red;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final wash = red ? Tokens.phaseGlowRed : Tokens.phaseGlowAmber;
    final core = red ? Tokens.phaseGlowRedCore : Tokens.phaseGlowAmberCore;
    // The pack's bloom: a soft inset wash, then the 3pt line on the edge.
    canvas.save();
    canvas.clipRRect(rect);
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = Tokens.glowBloom
        ..color = wash
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, Tokens.glowBloom / 2),
    );
    canvas.restore();
    canvas.drawRRect(
      rect.deflate(Tokens.glowWidth / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = Tokens.glowWidth
        ..color = core,
    );
  }

  @override
  bool shouldRepaint(_EdgePainter old) => old.red != red || old.radius != radius;
}
