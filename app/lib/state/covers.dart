import 'package:rule_engine/rule_engine.dart';

import '../platform/platform_bridge.dart';
import '../ui/words.dart';
import 'guard_state.dart';

/// One cover window as the trader sees it: the engine makes a window per
/// instrument, and EUR CPI for someone watching gold and EUR is one cover, not
/// two. Grouped by time and events.
class Cover {
  Cover({
    required this.opens,
    required this.closes,
    required this.symbols,
    required this.eventIds,
    required this.title,
    required this.impact,
    this.isTest = false,
  });

  final DateTime opens;
  final DateTime closes;
  final List<String> symbols;
  final List<String> eventIds;

  /// "EUR CPI", or "EUR CPI, BoE Rate" when two releases share a window.
  final String title;

  /// high, medium, low or none: the loudest event in the window.
  final String impact;
  final bool isTest;

  /// "Gold" or "Gold, EUR".
  String get markets => symbols.map(marketName).toSet().join(', ');

  bool liveAt(DateTime now) => !now.isBefore(opens) && now.isBefore(closes);
  bool endedAt(DateTime now) => !now.isBefore(closes);
}

const _impactRank = {'none': 0, 'low': 1, 'medium': 2, 'high': 3};

String _loudest(Iterable<String> impacts) =>
    impacts.fold('none', (a, b) => (_impactRank[b] ?? 0) > (_impactRank[a] ?? 0) ? b : a);

/// Every cover, in time order, the tester's window included.
List<Cover> coversFor(GuardState state, {GateWindowSpec? test}) {
  final groups = <String, List<Window>>{};
  for (final w in state.windows) {
    final key = '${w.opensAtUtc}|${w.closesAtUtc}|${([...w.reasons]..sort()).join(',')}';
    groups.putIfAbsent(key, () => []).add(w);
  }
  final covers = [for (final g in groups.values) _cover(state, g)];
  if (test != null) {
    covers.add(Cover(
      opens: DateTime.fromMillisecondsSinceEpoch(test.opensAtMs, isUtc: true),
      closes: DateTime.fromMillisecondsSinceEpoch(test.closesAtMs, isUtc: true),
      symbols: const ['Test'],
      eventIds: const [],
      title: 'Test window',
      impact: 'high',
      isTest: true,
    ));
  }
  return covers..sort((a, b) => a.opens.compareTo(b.opens));
}

/// The trader's own order: gold first if they picked gold first.
int _order(GuardState state, String symbol) {
  final i = state.instruments.indexWhere((x) => x['symbol'] == symbol);
  return i < 0 ? 1 << 20 : i;
}

Cover _cover(GuardState state, List<Window> group) {
  final first = group.first;
  final events = first.reasons.map(state.eventById).whereType<Map<String, dynamic>>().toList();
  final names = <String>[];
  for (final e in events) {
    final n = eventShort(e['currency'] as String? ?? '', e['title'] as String? ?? 'News');
    if (!names.contains(n)) names.add(n);
  }
  return Cover(
    opens: DateTime.parse(first.opensAtUtc).toUtc(),
    closes: DateTime.parse(first.closesAtUtc).toUtc(),
    symbols: [for (final w in group) w.instrument]..sort((a, b) => _order(state, a).compareTo(_order(state, b))),
    eventIds: first.reasons,
    title: names.isEmpty ? 'High impact news' : names.join(', '),
    impact: _loudest(events.map((e) => e['impact'] as String? ?? 'high')),
  );
}

/// A calendar row on Today and Tomorrow's news.
class CalendarEntry {
  CalendarEntry({
    required this.id,
    required this.currency,
    required this.title,
    required this.short,
    required this.impact,
    required this.at,
    this.cover,
    this.tentative = false,
  });

  final String id;
  final String currency;
  final String title;
  final String short;

  /// high, medium, low or none.
  final String impact;
  final DateTime at;
  final Cover? cover;
  final bool tentative;
}

/// Events on the trader's currencies, every impact level, each with its cover
/// when one applies. The filter chips decide what shows.
List<CalendarEntry> calendarFor(GuardState state, List<Cover> covers) {
  final watched = <String>{for (final i in state.instruments) ...currenciesFor(i)};
  final entries = <CalendarEntry>[];
  for (final e in state.events) {
    final currency = e['currency'] as String? ?? '';
    if (!watched.contains(currency)) continue;
    final at = DateTime.tryParse(e['scheduledAtUtc'] as String? ?? '');
    if (at == null) continue;
    final id = e['id'] as String;
    Cover? cover;
    for (final c in covers) {
      if (c.eventIds.contains(id)) {
        cover = c;
        break;
      }
    }
    final impact = switch (e['impact']) {
      'high' => 'high',
      'medium' || 'mid' => 'medium',
      'low' => 'low',
      _ => 'none',
    };
    final title = e['title'] as String? ?? 'News';
    entries.add(CalendarEntry(
      id: id,
      currency: currency,
      title: title,
      short: eventShort(currency, title),
      impact: impact,
      at: at.toUtc(),
      cover: cover,
      tentative: e['tentative'] == true,
    ));
  }
  entries.sort((a, b) => a.at.compareTo(b.at));
  return entries;
}

/// "Gold · EUR CPI": what the cover, the shield and the Lock Screen say about
/// one engine window.
String coverWhat(GuardState state, Window w) {
  final names = <String>[];
  for (final e in w.reasons.map(state.eventById).whereType<Map<String, dynamic>>()) {
    final n = eventShort(e['currency'] as String? ?? '', e['title'] as String? ?? 'News');
    if (!names.contains(n)) names.add(n);
  }
  return '${marketName(w.instrument)} · ${names.isEmpty ? 'High impact news' : names.join(', ')}';
}
