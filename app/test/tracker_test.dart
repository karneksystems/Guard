import 'package:flutter_test/flutter_test.dart';
import 'package:guard_app/features/tracker.dart';

void main() {
  test('room left is the limit minus today\'s losses, and profit does not add room', () {
    const t = Tracker(dailyLossLimit: 500, entries: [
      PnlEntry(date: '2026-10-01', amount: -120),
      PnlEntry(date: '2026-10-01', amount: 40),
      PnlEntry(date: '2026-09-30', amount: -400),
    ]);
    expect(t.pnlOn('2026-10-01'), -80);
    expect(t.roomLeft('2026-10-01'), 420);
    expect(t.roomLeft('2026-10-02'), 500);
    expect(const Tracker(dailyLossLimit: 100, entries: [PnlEntry(date: '2026-10-01', amount: 250)]).roomLeft('2026-10-01'), 100);
    expect(const Tracker(dailyLossLimit: 100, entries: [PnlEntry(date: '2026-10-01', amount: -250)]).roomLeft('2026-10-01'), 0);
    expect(const Tracker().roomLeft('2026-10-01'), isNull);
  });

  test('traded days are distinct dates since the start date', () {
    const t = Tracker(minTradingDays: 5, startDate: '2026-09-29', entries: [
      PnlEntry(date: '2026-09-28', amount: 1),
      PnlEntry(date: '2026-09-29', amount: 1),
      PnlEntry(date: '2026-09-29', amount: -1),
      PnlEntry(date: '2026-10-01', amount: 1),
    ]);
    expect(t.tradedDays(), 2);
    expect(t.daysToGo, 3);
    expect(t.lastActivityDate, '2026-10-01');
    expect(const Tracker().daysToGo, 0);
    expect(const Tracker(startDate: '2026-09-01').lastActivityDate, '2026-09-01');
  });

  test('json round trip and prune', () {
    const t = Tracker(currency: '£', dailyLossLimit: 500, minTradingDays: 4, startDate: '2026-09-01', inactivityDays: 20, weekendWarning: false, entries: [
      PnlEntry(date: '2026-06-01', amount: -5, note: 'old'),
      PnlEntry(date: '2026-10-01', amount: 12.5),
    ]);
    final back = Tracker.fromJson(t.toJson());
    expect(back.currency, '£');
    expect(back.dailyLossLimit, 500);
    expect(back.minTradingDays, 4);
    expect(back.inactivityDays, 20);
    expect(back.weekendWarning, isFalse);
    expect(back.entries.length, 2);
    expect(back.entries.first.note, 'old');
    expect(back.prune('2026-10-02').entries.map((e) => e.date), ['2026-10-01']);
  });
}
