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
/// wakes it at the next change instead of polling.
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

  void _armFor(NewsNow news) {
    _wake?.cancel();
    final at = news.nextChange;
    if (at == null) return;
    // A second past the boundary, so the next read lands on the new side of it.
    final wait = at.difference(_controller!.now.toUtc()) + const Duration(seconds: 1);
    _wake = Timer(wait.isNegative ? Duration.zero : wait, _changed);
  }

  @override
  Widget build(BuildContext context) {
    GuardScope.of(context); // rebuild when the windows change
    final news = _controller!.newsNow();
    _armFor(news);
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
                    painter: _EdgePainter(color, _cornerRadius()),
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
  _EdgePainter(this.color, this.radius);

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    // A soft wash that fades inwards, then a crisp line on the edge itself.
    for (final (width, blur, alpha) in const [(28.0, 18.0, 0.35), (10.0, 6.0, 0.6)]) {
      canvas.drawRRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = color.withValues(alpha: alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      );
    }
    canvas.drawRRect(
      rect.deflate(1.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_EdgePainter old) => old.color != color || old.radius != radius;
}
