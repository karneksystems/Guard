/// How Guard says times, markets and events to a trader. Local time always,
/// plain words, and "to" between times, never a dash (house style).
library;

import 'package:rule_engine/rule_engine.dart';

/// "8:55", local, 24 hour, no leading zero on the hour.
String clock(DateTime t) {
  final l = t.toLocal();
  return '${l.hour}:${l.minute.toString().padLeft(2, '0')}';
}

/// "08:55", for the fixed width time column on Today.
String clockPadded(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// "8:55 to 9:05".
String span(DateTime from, DateTime to) => '${clock(from)} to ${clock(to)}';

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Tue 1 Oct".
String dateShort(DateTime t) {
  final l = t.toLocal();
  return '${_days[l.weekday - 1]} ${l.day} ${_months[l.month - 1]}';
}

/// "Today", "Tomorrow", or "Thu 3 Oct", against the trader's local day.
String dayWord(DateTime t, DateTime now) {
  final d = _day(t);
  final today = _day(now);
  final diff = d.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return dateShort(t);
}

bool sameLocalDay(DateTime a, DateTime b) => _day(a) == _day(b);

DateTime _day(DateTime t) {
  final l = t.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// "04:12" under an hour, "1:04:12" over it.
String countdown(Duration d) {
  final s = d.isNegative ? 0 : d.inSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
}

/// "$1,880".
String money(String currency, double v) {
  final whole = v.abs().round().toString();
  final grouped = whole.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '${v < 0 ? '-' : ''}$currency$grouped';
}

/// What a trader calls a market. Symbol codes stay for Today's detail.
String marketName(String symbol) => switch (symbol.toUpperCase()) {
      'XAUUSD' => 'Gold',
      'XAGUSD' => 'Silver',
      'EURUSD' => 'EUR',
      'GBPUSD' => 'GBP',
      'USDJPY' => 'JPY',
      'AUDUSD' => 'AUD',
      'USDCAD' => 'CAD',
      'USDCHF' => 'CHF',
      'US30' || 'US500' || 'USTEC' || 'NAS100' => 'US indices',
      'DE40' => 'DAX',
      'UK100' => 'FTSE',
      'BTCUSD' => 'Bitcoin',
      'USOIL' || 'WTI' => 'Oil',
      _ => symbol,
    };

/// "gold, EUR": the status chip lowercases common nouns, keeps codes.
String marketsLine(Iterable<String> symbols) {
  final names = <String>[];
  for (final s in symbols) {
    final n = marketName(s);
    final spoken = n == 'Gold' || n == 'Silver' || n == 'Oil' ? n.toLowerCase() : n;
    if (!names.contains(spoken)) names.add(spoken);
  }
  return names.join(', ');
}

/// Currencies whose news moves this instrument, the same set the engine uses.
Set<String> currenciesFor(Map<String, dynamic> instrument) => RuleEngine.basketFor(instrument).toSet();

/// The short name a trader uses for a release: "EUR CPI", "NFP", "BoE Rate".
/// Falls back to the feed's title.
String eventShort(String currency, String title) {
  final t = title.toLowerCase();
  bool has(String s) => t.contains(s);
  if (has('non-farm') || has('nonfarm')) return 'NFP';
  if (has('fomc') || (currency == 'USD' && has('federal funds'))) return 'FOMC';
  if (has('cpi')) return '$currency CPI';
  if (has('pce')) return '$currency PCE';
  if (has('gdp')) return '$currency GDP';
  if (has('retail sales')) return '$currency Retail Sales';
  if (has('unemployment') || has('employment change') || has('jobless')) return '$currency Jobs';
  if (has('pmi')) return '$currency PMI';
  if (has('bank rate') || has('rate decision') || has('interest rate') || has('cash rate') || has('refinancing')) {
    final bank = switch (currency) {
      'GBP' => 'BoE',
      'EUR' => 'ECB',
      'USD' => 'Fed',
      'JPY' => 'BoJ',
      'AUD' => 'RBA',
      'CAD' => 'BoC',
      'CHF' => 'SNB',
      'NZD' => 'RBNZ',
      _ => currency,
    };
    return '$bank Rate';
  }
  return title;
}
