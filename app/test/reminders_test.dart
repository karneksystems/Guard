import 'package:flutter_test/flutter_test.dart';
import 'package:guard_app/features/tracker.dart';
import 'package:guard_app/notifications/ladder_mirror.dart';
import 'package:guard_app/notifications/notification_scheduler.dart';
import 'package:guard_app/notifications/reminders.dart';
import 'package:guard_app/sync/sync_payload.dart';
import 'package:rule_engine/rule_engine.dart';

Window win(String id, String opens, String closes, {String instrument = 'XAUUSD', List<String> reasons = const ['nfp']}) =>
    Window(windowId: id, instrument: instrument, opensAtUtc: opens, closesAtUtc: closes, reasons: reasons, verified: true);

String title(String id) => switch (id) { 'nfp' => 'Non-Farm Payrolls', 'cpi' => 'CPI y/y', _ => id };

void main() {
  // Tuesday 29 Sep 2026, 06:00 UTC, user in UTC+1.
  final now = DateTime.utc(2026, 9, 29, 6);
  const offset = Duration(hours: 1);

  test('digest fires at the digest time the evening before each day with windows, in local time', () {
    final planner = ReminderPlanner(FakeScheduler(), utcOffset: offset);
    final plan = planner.plan(
      windows: [
        win('a', '2026-10-01T08:55:00Z', '2026-10-01T09:05:00Z', reasons: ['cpi']),
        win('b', '2026-10-01T12:25:00Z', '2026-10-01T12:35:00Z'),
        // 23:30 UTC on 1 Oct is 00:30 local on 2 Oct: it belongs to the next day's digest.
        win('c', '2026-10-01T23:30:00Z', '2026-10-01T23:40:00Z', instrument: 'EURUSD', reasons: ['cpi']),
      ],
      titleFor: title,
      digestLocalTime: '20:00',
      tracker: const Tracker(weekendWarning: false, inactivityDays: 0),
      now: now,
    );
    expect(plan.length, 2);
    final first = plan.singleWhere((n) => n.alertId == 'digest:2026-10-01');
    expect(first.atUtc, DateTime.utc(2026, 9, 30, 19, 0));
    expect(first.title, 'Tomorrow: 2 restricted windows');
    expect(first.body, 'CPI y/y, Non-Farm Payrolls on XAUUSD. First at 09:55.');
    expect(first.channel, 'digest');
    expect(first.id, greaterThanOrEqualTo(kReminderIdBase));
    final second = plan.singleWhere((n) => n.alertId == 'digest:2026-10-02');
    expect(second.atUtc, DateTime.utc(2026, 10, 1, 19, 0));
    expect(second.title, 'Tomorrow: 1 restricted window');
  });

  test('a digest whose time has passed is not scheduled', () {
    final planner = ReminderPlanner(FakeScheduler(), utcOffset: offset);
    final plan = planner.plan(
      windows: [win('a', '2026-09-29T12:25:00Z', '2026-09-29T12:35:00Z')],
      titleFor: title,
      digestLocalTime: '20:00',
      tracker: const Tracker(weekendWarning: false, inactivityDays: 0),
      now: now,
    );
    expect(plan, isEmpty);
  });

  test('weekend warning lands on the coming Friday at 20:30 UTC, and only when on', () {
    final planner = ReminderPlanner(FakeScheduler(), utcOffset: offset);
    final on = planner.plan(windows: [], titleFor: title, digestLocalTime: '20:00', tracker: const Tracker(inactivityDays: 0), now: now);
    expect(on.single.alertId, 'weekend:2026-10-02');
    expect(on.single.atUtc, DateTime.utc(2026, 10, 2, 20, 30));
    // Friday after the slot rolls to the next Friday.
    final late = planner.plan(windows: [], titleFor: title, digestLocalTime: '20:00', tracker: const Tracker(inactivityDays: 0), now: DateTime.utc(2026, 10, 2, 21));
    expect(late.single.alertId, 'weekend:2026-10-09');
    final off = planner.plan(windows: [], titleFor: title, digestLocalTime: '20:00', tracker: const Tracker(weekendWarning: false, inactivityDays: 0), now: now);
    expect(off, isEmpty);
  });

  test('inactivity reminder is three days before the limit, at 09:00 local, from the last logged trade', () {
    final planner = ReminderPlanner(FakeScheduler(), utcOffset: offset);
    const t = Tracker(weekendWarning: false, inactivityDays: 30, entries: [PnlEntry(date: '2026-09-20', amount: -1)]);
    final plan = planner.plan(windows: [], titleFor: title, digestLocalTime: '20:00', tracker: t, now: now);
    expect(plan.single.alertId, 'inactivity:2026-09-20');
    expect(plan.single.atUtc, DateTime.utc(2026, 10, 17, 8, 0));
    expect(plan.single.title, 'No trade in 27 days');
    final none = planner.plan(windows: [], titleFor: title, digestLocalTime: '20:00', tracker: const Tracker(weekendWarning: false), now: now);
    expect(none, isEmpty, reason: 'no activity known, nothing to count from');
  });

  test('reconcile only cancels its own id range and the ladder mirror leaves reminders alone', () async {
    final scheduler = FakeScheduler();
    // A ladder rung already pending, plus a stale reminder.
    await scheduler.schedule(ScheduledNotification(id: 42, alertId: 'rung', title: '', body: '', atUtc: now, channel: 'ladder'));
    await scheduler.schedule(ScheduledNotification(id: kReminderIdBase + 999, alertId: 'stale', title: '', body: '', atUtc: now, channel: 'digest'));

    final planner = ReminderPlanner(scheduler, utcOffset: offset);
    final r = await planner.reconcile(windows: [], titleFor: title, digestLocalTime: '20:00', tracker: const Tracker(inactivityDays: 0), now: now);
    expect(r.cancelled, 1);
    expect(scheduler.pending.keys, containsAll([42, kReminderIdBase + 1]));
    expect(scheduler.pending.containsKey(kReminderIdBase + 999), isFalse);

    // The ladder mirror with an empty ladder cancels the rung, not the reminder.
    final payload = SyncPayload.fromJson({'serverTimeUtc': '2026-09-29T06:00:00Z', 'pro': false, 'settings': <String, dynamic>{}, 'instruments': [], 'events': [], 'windows': [], 'ladder': []});
    final m = await LadderMirror(scheduler).reconcile(payload, now: now);
    expect(m.cancelled, 1);
    expect(scheduler.pending.keys, [kReminderIdBase + 1]);
  });
}
