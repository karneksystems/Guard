import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens.dart';

/// The colours a widget needs for the current brightness, in one place.
class Shade {
  Shade._(this.dark);

  factory Shade.of(BuildContext context) => Shade._(Theme.of(context).brightness == Brightness.dark);

  final bool dark;
  Color get bg => dark ? Tokens.inkBg : Tokens.paperBg;
  Color get surface => dark ? Tokens.inkSurface : Tokens.paperSurface;
  Color get raised => dark ? Tokens.inkSurfaceRaised : Tokens.paperSurfaceRaised;
  Color get text => dark ? Tokens.inkText : Tokens.paperText;
  Color get muted => dark ? Tokens.inkTextMuted : Tokens.paperTextMuted;
  Color get hairline => dark ? Tokens.inkHairline : Tokens.paperHairline;

  /// Sky reads on navy; on paper the brand blue does the same job.
  Color get accent => dark ? Tokens.sky : Tokens.brand;
}

/// Impact colour for a calendar level. Rows and filter chips only, never the
/// phase glow.
Color impactColor(String impact) => switch (impact) {
      'high' => Tokens.impactHigh,
      'medium' => Tokens.impactMid,
      'low' => Tokens.impactLow,
      _ => Tokens.impactNone,
    };

String impactWord(String impact) => switch (impact) {
      'high' => 'High',
      'medium' => 'Mid',
      'low' => 'Low',
      _ => 'None',
    };

/// A hairline card with a faint top light, the pack's surface.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.accent, this.onTap});

  final Widget child;
  final EdgeInsets padding;

  /// A phase colour for the border, when the panel is about the next cover.
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ink = Shade.of(context);
    final radius = BorderRadius.circular(Tokens.radiusMd);
    final box = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: accent?.withValues(alpha: 0.55) ?? ink.hairline),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ink.raised, ink.surface],
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: radius, onTap: onTap, child: box),
    );
  }
}

/// Small caps label: "OPENS SOON", "LOSS ROOM".
class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.color, this.size = Tokens.typeMicro});

  final String text;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: Tokens.bodyFamily,
          fontSize: size,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: color ?? Shade.of(context).muted,
        ),
      );
}

/// One to three bars, coloured by impact.
class ImpactBars extends StatelessWidget {
  const ImpactBars(this.impact, {super.key, this.height = 12});

  final String impact;
  final double height;

  @override
  Widget build(BuildContext context) {
    final n = switch (impact) {
      'high' => 3,
      'medium' => 2,
      'low' => 1,
      _ => 0,
    };
    final c = impactColor(impact);
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (var i = 0; i < 3; i++) ...[
        if (i > 0) SizedBox(width: height / 6),
        Container(
          width: height / 4,
          height: height * (0.5 + i * 0.25),
          decoration: BoxDecoration(
            color: i < n ? c : c.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    ]);
  }
}

const _flags = {
  'EUR': 'eu',
  'USD': 'us',
  'GBP': 'gb',
  'JPY': 'jp',
  'CAD': 'ca',
  'AUD': 'au',
  'CHF': 'ch',
  'CNY': 'cn',
};

/// Flag over currency code, in a small tile.
class FlagBadge extends StatelessWidget {
  const FlagBadge(this.currency, {super.key});

  final String currency;

  @override
  Widget build(BuildContext context) {
    final ink = Shade.of(context);
    final flag = _flags[currency];
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: ink.bg,
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        border: Border.all(color: ink.hairline),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (flag != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SvgPicture.asset('assets/flags/$flag.svg', width: 18, height: 12, fit: BoxFit.cover),
          ),
        const SizedBox(height: 2),
        Text(currency, style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 8, fontWeight: FontWeight.w700, color: ink.muted)),
      ]),
    );
  }
}

/// The countdown ring: a track and an arc that empties clockwise from the top.
class PhaseRing extends StatelessWidget {
  const PhaseRing({super.key, required this.size, required this.stroke, required this.color, required this.progress, required this.child});

  final double size;
  final double stroke;
  final Color color;

  /// 0 to 1: how much of the arc is drawn.
  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(color, stroke, progress.clamp(0.0, 1.0), Shade.of(context).hairline),
          child: Center(child: child),
        ),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.color, this.stroke, this.progress, this.track);

  final Color color;
  final double stroke;
  final double progress;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(rect, 0, math.pi * 2, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color.withValues(alpha: 0.16));
    if (progress <= 0) return;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}

/// A labelled number in the metric strip.
class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Panel(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Kicker(label, size: 9),
          const SizedBox(height: 6),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 17, fontWeight: FontWeight.w600, color: Shade.of(context).text)),
        ]),
      );
}

/// Section heading on a list: "COVER WINDOWS".
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 20, 0, 10),
        child: Kicker(text, size: 11),
      );
}

/// Page title and its quiet line underneath.
class PageHead extends StatelessWidget {
  const PageHead(this.title, {super.key, this.sub});

  final String title;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final ink = Shade.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontFamily: Tokens.displayFamily, fontSize: 30, fontWeight: FontWeight.w600, color: ink.text, letterSpacing: -0.5)),
      if (sub != null) ...[
        const SizedBox(height: 4),
        Text(sub!, style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 13, color: ink.muted)),
      ],
    ]);
  }
}

/// "We never touch your trades." at the foot of a page.
class Promise extends StatelessWidget {
  const Promise({super.key, this.text = 'We never touch your trades.'});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 12, color: Shade.of(context).muted)),
      );
}
