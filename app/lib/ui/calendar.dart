import 'package:flutter/material.dart';

import '../state/covers.dart';
import '../theme/tokens.dart';
import 'parts.dart';
import 'words.dart';

/// Low, Mid, High chips with counts. Multi-select, High only by default
/// (Jamie's lock in docs/redesign/grok-final/HANDOFF-Claude.md).
class ImpactFilter extends StatelessWidget {
  const ImpactFilter({super.key, required this.entries, required this.selected, required this.onChanged});

  final List<CalendarEntry> entries;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  static const levels = ['low', 'medium', 'high'];

  @override
  Widget build(BuildContext context) {
    final shade = Shade.of(context);
    return Row(children: [
      for (final level in levels) ...[
        _Chip(
          key: Key('filter-$level'),
          label: impactWord(level),
          count: entries.where((e) => e.impact == level).length,
          color: impactColor(level),
          on: selected.contains(level),
          onTap: () {
            final next = {...selected};
            if (!next.remove(level)) next.add(level);
            // Never an empty calendar by accident: the last chip stays on.
            if (next.isNotEmpty) onChanged(next);
          },
          shade: shade,
        ),
        const SizedBox(width: 8),
      ],
    ]);
  }

  /// "Showing High · 2 mid & 1 low hidden", or null when nothing is hidden.
  static String? hint(List<CalendarEntry> entries, Set<String> selected) {
    final hidden = <String>[
      for (final level in ['medium', 'low', 'none'])
        if (!selected.contains(level))
          if (entries.where((e) => e.impact == level).length case final n when n > 0) '$n ${level == 'medium' ? 'mid' : level}',
    ];
    if (hidden.isEmpty) return null;
    final showing = [for (final l in levels.reversed) if (selected.contains(l)) impactWord(l)].join(', ');
    return 'Showing $showing · ${hidden.join(' & ')} hidden';
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.label, required this.count, required this.color, required this.on, required this.onTap, required this.shade});

  final String label;
  final int count;
  final Color color;
  final bool on;
  final VoidCallback onTap;
  final Shade shade;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(Tokens.radiusPill),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: on ? color.withValues(alpha: 0.14) : shade.surface,
              borderRadius: BorderRadius.circular(Tokens.radiusPill),
              border: Border.all(color: on ? color.withValues(alpha: 0.6) : shade.hairline),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 7),
              Text(label, style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 13, fontWeight: FontWeight.w600, color: on ? color : shade.text)),
              const SizedBox(width: 8),
              Text('$count', style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 12, color: shade.muted)),
            ]),
          ),
        ),
      );
}

/// One calendar row: time, flag, name, impact, the cover time, and how soon.
class EventRow extends StatelessWidget {
  const EventRow({super.key, required this.entry, required this.now, this.showEta = true});

  final CalendarEntry entry;
  final DateTime now;
  final bool showEta;

  @override
  Widget build(BuildContext context) {
    final shade = Shade.of(context);
    final cover = entry.cover;
    final live = cover != null && cover.liveAt(now);
    final soon = cover != null && !live && cover.opens.isAfter(now) && cover.opens.difference(now) <= const Duration(minutes: 5);
    final phase = live ? Tokens.red : (soon ? Tokens.amber : null);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: phase ?? Colors.transparent, width: 2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 50,
          child: Text(clockPadded(entry.at),
              style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 14, fontWeight: FontWeight.w700, color: shade.text, fontFeatures: const [FontFeature.tabularFigures()])),
        ),
        FlagBadge(entry.currency),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.short, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 15, fontWeight: FontWeight.w600, color: shade.text)),
            const SizedBox(height: 4),
            Row(children: [
              ImpactBars(entry.impact, height: 11),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  cover != null ? 'Cover ${span(cover.opens, cover.closes)}' : (entry.tentative ? 'Time not confirmed' : 'No cover'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 12, color: shade.muted),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(impactWord(entry.impact).toUpperCase(),
              style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1, color: impactColor(entry.impact))),
          if (showEta && cover != null) ...[
            const SizedBox(height: 6),
            _Eta(cover: cover, now: now),
          ],
        ]),
      ]),
    );
  }
}

class _Eta extends StatelessWidget {
  const _Eta({required this.cover, required this.now});

  final Cover cover;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final shade = Shade.of(context);
    final (text, color) = cover.liveAt(now)
        ? ('on', Tokens.red)
        : cover.endedAt(now)
            ? ('done', shade.muted)
            : cover.opens.difference(now) <= const Duration(minutes: 5)
                ? (countdown(cover.opens.difference(now)), Tokens.amber)
                : (cover.opens.difference(now) < const Duration(hours: 1) ? 'in ${cover.opens.difference(now).inMinutes} min' : 'later', shade.accent);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 12, fontWeight: FontWeight.w700, color: color, fontFeatures: const [FontFeature.tabularFigures()])),
    );
  }
}

/// Rows in one hairline panel, divided.
class EventGroup extends StatelessWidget {
  const EventGroup({super.key, required this.entries, required this.now, this.showEta = true});

  final List<CalendarEntry> entries;
  final DateTime now;
  final bool showEta;

  @override
  Widget build(BuildContext context) => Panel(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 14, endIndent: 14, color: Shade.of(context).hairline),
            EventRow(key: Key('event-${entries[i].id}'), entry: entries[i], now: now, showEta: showEta),
          ],
        ]),
      );
}
