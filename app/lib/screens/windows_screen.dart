import 'dart:async';

import 'package:flutter/material.dart';

import '../state/covers.dart';
import '../state/guard_controller.dart';
import '../state/guard_state.dart';
import '../theme/tokens.dart';
import '../ui/calendar.dart';
import '../ui/parts.dart';
import '../ui/words.dart';
import 'digest_screen.dart';

/// Today: the day's news on the trader's currencies, High only unless they
/// ask for more, then tomorrow. Board: docs/redesign/grok-final/phone/today.png.
class WindowsScreen extends StatefulWidget {
  const WindowsScreen({super.key});

  @override
  State<WindowsScreen> createState() => _WindowsScreenState();
}

class _WindowsScreenState extends State<WindowsScreen> {
  Set<String> _levels = {'high'};
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = GuardScope.of(context);
    final c = ControllerScope.of(context);
    final now = c.now.toUtc();
    final covers = coversFor(state, test: c.testWindow);
    final all = calendarFor(state, covers);
    final today = all.where((e) => sameLocalDay(e.at, now)).toList();
    final tomorrowDay = now.toLocal().add(const Duration(days: 1));
    final tomorrow = all.where((e) => sameLocalDay(e.at, tomorrowDay)).toList();
    final shownToday = today.where((e) => _levels.contains(e.impact)).toList();
    final shownTomorrow = tomorrow.where((e) => _levels.contains(e.impact)).toList();
    final hint = ImpactFilter.hint(today, _levels);
    final tomorrowCovers = covers.where((x) => sameLocalDay(x.opens, tomorrowDay)).length;
    final source = all.isEmpty ? null : state.sourceFor(all.first.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 12, Tokens.gutter, Tokens.gutter),
      children: [
        PageHead('Today', sub: '${dateShort(now)} · local times'),
        const SizedBox(height: 16),
        ImpactFilter(entries: today, selected: _levels, onChanged: (v) => setState(() => _levels = v)),
        if (hint != null) ...[
          const SizedBox(height: 8),
          Text(hint, key: const Key('today-hint'), style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 12, color: Shade.of(context).muted)),
        ],
        SectionLabel(_levels.length == 1 && _levels.contains('high') ? 'Cover windows' : 'Today'),
        if (shownToday.isEmpty)
          Panel(
            key: const Key('today-empty'),
            child: Text(
              tomorrowCovers == 0
                  ? 'Nothing today.'
                  : 'Nothing today. Tomorrow has ${tomorrowCovers == 1 ? 'one cover window' : '$tomorrowCovers cover windows'}.',
              style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 15, color: Shade.of(context).text),
            ),
          )
        else
          EventGroup(entries: shownToday, now: now),
        SectionLabel('Tomorrow · ${dateShort(tomorrowDay)}'),
        if (shownTomorrow.isEmpty)
          Panel(child: Text('Nothing yet.', style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 15, color: Shade.of(context).muted)))
        else
          EventGroup(entries: shownTomorrow, now: now, showEta: false),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('today-open-tomorrow'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DigestScreen())),
            child: const Text("Tomorrow's news"),
          ),
        ),
        Promise(
          text: state.isSample
              ? 'Example news until Guard connects. Times can move. Not financial advice.'
              : 'Times from ${source ?? 'the news calendar'}. Times can move. Not financial advice.',
        ),
      ],
    );
  }
}
