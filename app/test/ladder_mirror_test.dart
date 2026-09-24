import 'package:flutter_test/flutter_test.dart';
import 'package:guard_app/notifications/ladder_mirror.dart';
import 'package:guard_app/notifications/notification_scheduler.dart';
import 'package:guard_app/sync/sync_payload.dart';

SyncPayload payloadWith({required String opens, required String closes, required List<Map<String, String>> ladder}) {
  return SyncPayload.fromJson({
    'serverTimeUtc': '2026-10-02T06:00:00Z',
    'pro': false,
    'settings': {'mode': 'conservative', 'window_before_min': 5, 'window_after_min': 5},
    'instruments': [
      {'symbol': 'XAUUSD', 'basket': ['USD', 'EUR', 'GBP']},
    ],
    'events': [
      {'id': '7', 'currency': 'USD', 'title': 'Non-Farm Payrolls', 'impact': 'high', 'scheduledAtUtc': '2026-10-02T12:30:00Z'},
    ],
    'windows': [
      {'windowId': 'w' * 20, 'instrument': 'XAUUSD', 'opensAtUtc': opens, 'closesAtUtc': closes, 'reasons': ['7'], 'verified': true},
    ],
    'ladder': ladder,
  });
}

List<Map<String, String>> ladderFor(String opens, String closes, {String prefix = 'a'}) {
  final o = DateTime.parse(opens).toUtc();
  String at(int minutesBefore) => o.subtract(Duration(minutes: minutesBefore)).toIso8601String().replaceFirst('.000', '');
  return [
    {'alertId': '${prefix}1'.padRight(20, '0'), 'windowId': 'w' * 20, 'kind': 't-60', 'fireAtUtc': at(60)},
    {'alertId': '${prefix}2'.padRight(20, '0'), 'windowId': 'w' * 20, 'kind': 't-15', 'fireAtUtc': at(15)},
    {'alertId': '${prefix}3'.padRight(20, '0'), 'windowId': 'w' * 20, 'kind': 't-5', 'fireAtUtc': at(5)},
    {'alertId': '${prefix}4'.padRight(20, '0'), 'windowId': 'w' * 20, 'kind': 't-1', 'fireAtUtc': at(1)},
    {'alertId': '${prefix}5'.padRight(20, '0'), 'windowId': 'w' * 20, 'kind': 'open', 'fireAtUtc': at(0)},
    {'alertId': '${prefix}6'.padRight(20, '0'), 'windowId': 'w' * 20, 'kind': 'end', 'fireAtUtc': closes},
  ];
}

void main() {
  final now = DateTime.utc(2026, 10, 2, 6);

  test('mirrors every future rung at fire time plus the grace period, with the backend\'s words', () async {
    final scheduler = FakeScheduler();
    final mirror = LadderMirror(scheduler);
    final payload = payloadWith(opens: '2026-10-02T12:25:00Z', closes: '2026-10-02T12:35:00Z', ladder: ladderFor('2026-10-02T12:25:00Z', '2026-10-02T12:35:00Z'));

    final r = await mirror.reconcile(payload, now: now);

    expect(r.scheduled, 6);
    expect(scheduler.pending.length, 6);
    final open = scheduler.pending.values.singleWhere((n) => n.alertId.startsWith('a5'));
    expect(open.title, 'Restricted: XAUUSD');
    expect(open.body, 'Non-Farm Payrolls. Stay out until 12:35 UTC.');
    expect(open.channel, 'ladder_urgent');
    expect(open.atUtc, DateTime.utc(2026, 10, 2, 12, 25, 20));
    final t60 = scheduler.pending.values.singleWhere((n) => n.alertId.startsWith('a1'));
    expect(t60.channel, 'ladder');
    expect(t60.atUtc, DateTime.utc(2026, 10, 2, 11, 25, 20));
  });

  test('a revised ladder cancels the old ids and schedules the new ones', () async {
    final scheduler = FakeScheduler();
    final mirror = LadderMirror(scheduler);
    await mirror.reconcile(payloadWith(opens: '2026-10-02T12:25:00Z', closes: '2026-10-02T12:35:00Z', ladder: ladderFor('2026-10-02T12:25:00Z', '2026-10-02T12:35:00Z')), now: now);
    final oldIds = scheduler.pending.keys.toSet();

    final r = await mirror.reconcile(payloadWith(opens: '2026-10-02T13:25:00Z', closes: '2026-10-02T13:35:00Z', ladder: ladderFor('2026-10-02T13:25:00Z', '2026-10-02T13:35:00Z', prefix: 'b')), now: now);

    expect(r.cancelled, 6);
    expect(r.scheduled, 6);
    expect(scheduler.cancelled.toSet(), oldIds);
    expect(scheduler.pending.keys.toSet().intersection(oldIds), isEmpty);
  });

  test('rungs already in the past are not scheduled', () async {
    final scheduler = FakeScheduler();
    final mirror = LadderMirror(scheduler);
    final late = DateTime.utc(2026, 10, 2, 12, 26); // after t-60 .. open, before end

    final r = await mirror.reconcile(payloadWith(opens: '2026-10-02T12:25:00Z', closes: '2026-10-02T12:35:00Z', ladder: ladderFor('2026-10-02T12:25:00Z', '2026-10-02T12:35:00Z')), now: late);

    expect(r.scheduled, 1);
    expect(scheduler.pending.values.single.title, 'Clear: XAUUSD');
  });

  test('a push arriving cancels only its own mirror', () async {
    final scheduler = FakeScheduler();
    final mirror = LadderMirror(scheduler);
    await mirror.reconcile(payloadWith(opens: '2026-10-02T12:25:00Z', closes: '2026-10-02T12:35:00Z', ladder: ladderFor('2026-10-02T12:25:00Z', '2026-10-02T12:35:00Z')), now: now);

    await mirror.pushArrived('a4'.padRight(20, '0'));

    expect(scheduler.pending.length, 5);
    expect(scheduler.pending.values.any((n) => n.alertId.startsWith('a4')), isFalse);
  });

  test('notification ids are stable and fit the OS', () {
    expect(notificationIdFor('a4'.padRight(20, '0')), notificationIdFor('a4'.padRight(20, '0')));
    expect(notificationIdFor('ffffffffffffffffffff'), lessThan(1 << 31));
  });
}
