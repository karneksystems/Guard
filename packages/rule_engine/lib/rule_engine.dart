/// The rule engine, as specified in docs/RULE-ENGINE.md.
///
/// A pure function of its input. Reads no clock, no database and no network.
/// fixtures/rule-engine/reference.py is the tie-breaker when this and the PHP
/// engine disagree; both must pass every case in fixtures/rule-engine/cases.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

const Map<String, List<String>> defaultBaskets = {
  'XAUUSD': ['USD', 'EUR', 'GBP'],
  'XAGUSD': ['USD', 'EUR', 'GBP'],
  'US30': ['USD'],
  'US500': ['USD'],
  'USTEC': ['USD'],
  'US2000': ['USD'],
  'DE40': ['EUR'],
  'FR40': ['EUR'],
  'EU50': ['EUR'],
  'UK100': ['GBP'],
  'JP225': ['JPY'],
  'HK50': ['CNY', 'HKD'],
  'AUS200': ['AUD'],
  'USOIL': ['USD'],
  'UKOIL': ['USD'],
  'BTCUSD': ['USD'],
  'ETHUSD': ['USD'],
};

const List<(String, int)> _rungs = [
  ('t-60', -60),
  ('t-15', -15),
  ('t-5', -5),
  ('t-1', -1),
  ('open', 0),
];

/// Loads a pack by firm id. The app supplies one backed by its local store.
typedef PackLoader = Map<String, dynamic> Function(String firmId);

class Window {
  Window({
    required this.windowId,
    required this.instrument,
    required this.opensAtUtc,
    required this.closesAtUtc,
    required this.reasons,
    required this.verified,
  });

  final String windowId;
  final String instrument;
  final String opensAtUtc;
  final String closesAtUtc;
  final List<String> reasons;
  final bool verified;

  Map<String, dynamic> toJson() => {
        'windowId': windowId,
        'instrument': instrument,
        'opensAtUtc': opensAtUtc,
        'closesAtUtc': closesAtUtc,
        'reasons': reasons,
        'verified': verified,
      };
}

class Rung {
  Rung({
    required this.alertId,
    required this.windowId,
    required this.kind,
    required this.fireAtUtc,
  });

  final String alertId;
  final String windowId;
  final String kind;
  final String fireAtUtc;

  Map<String, dynamic> toJson() => {
        'alertId': alertId,
        'windowId': windowId,
        'kind': kind,
        'fireAtUtc': fireAtUtc,
      };
}

class WindowsResult {
  WindowsResult(this.windows, this.notes);

  final List<Window> windows;
  final List<String> notes;
}

class Reconciliation {
  Reconciliation(this.cancelledAlertIds, this.createdAlertIds, this.keptAlertIds);

  final List<String> cancelledAlertIds;
  final List<String> createdAlertIds;
  final List<String> keptAlertIds;
}

class RuleEngine {
  RuleEngine(this._loadPack);

  final PackLoader _loadPack;

  WindowsResult computeWindows(Map<String, dynamic> input) {
    final rule = _effectiveRule(input);
    if (rule.before == null) {
      return WindowsResult([], rule.notes);
    }

    final events = (input['events'] as List).cast<Map<String, dynamic>>();
    final notes = [...rule.notes];
    // Only a real boolean true is tentative; strings and numbers are not booleans.
    final live = events.where((e) => e['tentative'] != true).toList();
    var selected = <Map<String, dynamic>>[];
    if (rule.selector == 'firm-list') {
      final ids = (input['firmEventIds'] as List).map((e) => e.toString()).toSet();
      selected = live.where((e) => ids.contains(e['id'])).toList();
    }
    if (rule.selector != 'firm-list' || selected.isEmpty) {
      // No list, or a list that names nothing we have: unknown means not
      // allowed, so the calendar's high-impact set applies.
      if (rule.selector == 'firm-list') notes.add("using the calendar, not the firm's list");
      selected = live.where((e) => e['impact'] == 'high').toList();
    }

    final raw = <_Raw>[];
    final seenSymbols = <String>{};
    for (final instrument in (input['instruments'] as List).cast<Map<String, dynamic>>()) {
      final basket = basketFor(instrument);
      final symbol = instrument['symbol'] as String;
      if (!seenSymbols.add(symbol)) continue; // a duplicate instrument must not duplicate reasons
      for (final event in selected) {
        if (rule.affected == 'event-currency' && !basket.contains(event['currency'])) {
          continue;
        }
        if (rule.affected == 'list' && !rule.affectedList.contains(symbol)) {
          continue;
        }
        final t = _parse(event['scheduledAtUtc'] as String);
        raw.add(_Raw(
          symbol,
          t.subtract(Duration(minutes: rule.before!)),
          t.add(Duration(minutes: rule.after!)),
          event['id'] as String,
        ));
      }
    }

    // Event id is the last key so the order is total: Dart's sort is not stable
    // above 32 items and the other engines must agree on reasons order.
    raw.sort((a, b) {
      final s = a.symbol.compareTo(b.symbol);
      if (s != 0) return s;
      final o = a.opens.compareTo(b.opens);
      if (o != 0) return o;
      final c = a.closes.compareTo(b.closes);
      if (c != 0) return c;
      return a.eventId.compareTo(b.eventId);
    });

    final merged = <_Merged>[];
    for (final r in raw) {
      if (merged.isNotEmpty &&
          merged.last.symbol == r.symbol &&
          !r.opens.isAfter(merged.last.closes)) {
        if (r.closes.isAfter(merged.last.closes)) {
          merged.last.closes = r.closes;
        }
        merged.last.reasons.add(r.eventId);
      } else {
        merged.add(_Merged(r.symbol, r.opens, r.closes, [r.eventId]));
      }
    }

    final userId = input['userId'] as String;
    rule.notes
      ..clear()
      ..addAll(notes);
    final windows = merged.map((m) {
      final o = _fmt(m.opens);
      final c = _fmt(m.closes);
      return Window(
        windowId: _shortSha([userId, m.symbol, o, c]),
        instrument: m.symbol,
        opensAtUtc: o,
        closesAtUtc: c,
        reasons: m.reasons,
        verified: rule.verified,
      );
    }).toList();

    return WindowsResult(windows, rule.notes);
  }

  List<Rung> computeLadder(String userId, List<Window> windows) {
    final ladder = <Rung>[];
    for (final w in windows) {
      final opens = _parse(w.opensAtUtc);
      for (final (kind, delta) in _rungs) {
        ladder.add(Rung(
          alertId: _shortSha([userId, w.windowId, kind, w.opensAtUtc]),
          windowId: w.windowId,
          kind: kind,
          fireAtUtc: _fmt(opens.add(Duration(minutes: delta))),
        ));
      }
      ladder.add(Rung(
        alertId: _shortSha([userId, w.windowId, 'end', w.opensAtUtc]),
        windowId: w.windowId,
        kind: 'end',
        fireAtUtc: w.closesAtUtc,
      ));
    }
    ladder.sort((a, b) {
      final f = a.fireAtUtc.compareTo(b.fireAtUtc);
      if (f != 0) return f;
      final w = a.windowId.compareTo(b.windowId);
      if (w != 0) return w;
      return a.kind.compareTo(b.kind);
    });
    return ladder;
  }

  static Reconciliation reconcile(List<Rung> before, List<Rung> after) {
    final b = before.map((r) => r.alertId).toSet();
    final a = after.map((r) => r.alertId).toSet();
    return Reconciliation(
      b.difference(a).toList()..sort(),
      a.difference(b).toList()..sort(),
      b.intersection(a).toList()..sort(),
    );
  }

  static List<String> basketFor(Map<String, dynamic> instrument) {
    final explicit = instrument['basket'] as List?;
    if (explicit != null && explicit.isNotEmpty) {
      return explicit.cast<String>();
    }
    final symbol = (instrument['symbol'] as String).toUpperCase();
    final known = defaultBaskets[symbol];
    if (known != null) return known;
    if (symbol.length == 6 && RegExp(r'^[A-Z]{6}$').hasMatch(symbol)) {
      return [symbol.substring(0, 3), symbol.substring(3)];
    }
    return const ['USD'];
  }

  /// Minutes are whole and never negative; anything else is a bad input, not a
  /// window of some other size. Both engines reject the same things.
  static int minutes(Object? v, String field) {
    if (v is int && v >= 0) return v;
    if (v is double && v == v.roundToDouble() && v >= 0) return v.toInt();
    if (v is String && RegExp(r'^\d+$').hasMatch(v)) return int.parse(v);
    throw FormatException('$field must be a whole number of minutes, got $v');
  }

  _Rule _effectiveRule(Map<String, dynamic> input) {
    final s = input['settings'] as Map<String, dynamic>;
    final notes = <String>[];
    final userBefore = minutes(s['windowBeforeMin'], 'windowBeforeMin');
    final userAfter = minutes(s['windowAfterMin'], 'windowAfterMin');
    if (s['mode'] == 'conservative') {
      return _Rule(
        before: userBefore,
        after: userAfter,
        selector: 'high',
        affected: 'event-currency',
        verified: true,
        notes: notes,
      );
    }

    final pack = (input['pack'] as Map<String, dynamic>?) ??
        _loadPack(input['packId'] as String);
    final account = (pack['accountTypes'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((a) => a['id'] == input['accountTypeId'],
            orElse: () => throw StateError('Unknown account type ${input['accountTypeId']}'));
    final rule = account['newsRule'] as Map<String, dynamic>;
    // Unknown means not allowed (RULE-ENGINE.md): a missing field reads as its
    // most restrictive value. Only a real boolean counts as a boolean.
    final verified = pack['needsReverify'] == false;
    if (rule['applies'] == false) {
      return _Rule(
        verified: verified,
        notes: ['firm does not restrict news on this account type'],
      );
    }

    var before = rule['windowBeforeMin'] == null ? userBefore : minutes(rule['windowBeforeMin'], 'windowBeforeMin');
    var after = rule['windowAfterMin'] == null ? userAfter : minutes(rule['windowAfterMin'], 'windowAfterMin');
    if (!verified) {
      before = before > userBefore ? before : userBefore;
      after = after > userAfter ? after : userAfter;
      notes.add('pack unverified: using the larger of pack window and user default');
    }

    var selector = 'high';
    if (rule['eventSet'] == 'firm-list') {
      final ids = input['firmEventIds'] as List?;
      if (ids != null && ids.isNotEmpty) {
        selector = 'firm-list';
      } else {
        notes.add("using the calendar, not the firm's list");
      }
    }

    final affected = rule['affectedInstruments'] as String? ?? 'all';
    return _Rule(
      before: before,
      after: after,
      selector: selector,
      affected: affected,
      affectedList: {
        ...((rule['instruments'] as List?) ?? const []).map((e) => e.toString()),
        ...((input['affectedList'] as List?) ?? const []).map((e) => e.toString()),
      },
      verified: verified,
      notes: notes,
    );
  }
}

class _Rule {
  _Rule({
    this.before,
    this.after,
    this.selector,
    this.affected,
    this.affectedList = const {},
    required this.verified,
    required this.notes,
  });

  final int? before;
  final int? after;
  final String? selector;
  final String? affected;
  final Set<String> affectedList;
  final bool verified;
  final List<String> notes;
}

class _Raw {
  _Raw(this.symbol, this.opens, this.closes, this.eventId);

  final String symbol;
  final DateTime opens;
  final DateTime closes;
  final String eventId;
}

class _Merged {
  _Merged(this.symbol, this.opens, this.closes, this.reasons);

  final String symbol;
  final DateTime opens;
  DateTime closes;
  final List<String> reasons;
}

final _tsPattern = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$');

/// Exactly YYYY-MM-DDTHH:MM:SSZ, like the PHP engine: an offset, a fraction or
/// a missing seconds field would parse here and be refused there, and the ids
/// hashed from them must be identical.
DateTime _parse(String ts) {
  if (!_tsPattern.hasMatch(ts)) {
    throw FormatException('Timestamps must be YYYY-MM-DDTHH:MM:SSZ', ts);
  }
  return DateTime.parse(ts);
}

String _two(int n) => n.toString().padLeft(2, '0');

String _fmt(DateTime dt) {
  final u = dt.toUtc();
  return '${u.year.toString().padLeft(4, '0')}-${_two(u.month)}-${_two(u.day)}'
      'T${_two(u.hour)}:${_two(u.minute)}:${_two(u.second)}Z';
}

String _shortSha(List<String> parts) =>
    sha1.convert(utf8.encode(parts.join('|'))).toString().substring(0, 20);
