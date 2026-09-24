import 'package:flutter_test/flutter_test.dart';
import 'package:guard_app/platform/platform_bridge.dart';
import 'package:guard_app/state/guard_controller.dart';
import 'package:guard_app/state/guard_state.dart';
import 'package:guard_app/sync/sync_store.dart';

void main() {
  test('journal outcomes survive a restart through the store, amendments included', () async {
    final store = MemoryStore();
    final now = DateTime.utc(2026, 10, 2, 10);
    final first = GuardController(state: GuardState(onboarded: true), bridge: FakeBridge(), store: store, now: () => now);
    await first.recordOutcome('w1', 'viewed', DateTime.utc(2026, 10, 1, 9));
    await first.recordOutcome('w2', 'stayed-out', DateTime.utc(2026, 10, 2, 9));
    await first.amendOutcome('w1', 'traded-anyway');

    final second = GuardController(state: GuardState(onboarded: true), bridge: FakeBridge(), store: store, now: () => now);
    await second.start();
    expect(second.state.journal.map((e) => '${e.windowId}:${e.outcome}'), ['w2:stayed-out', 'w1:traded-anyway']);
  });

  test('streak counts consecutive clean gate days ending today or yesterday', () {
    final s = GuardState(onboarded: true);
    DateTime at(int day, [int hour = 9]) => DateTime.utc(2026, 10, day, hour);
    expect(s.streak(at(5).toLocal()), 0);

    s.addJournal([
      GateOutcome(windowId: 'a', outcome: 'stayed-out', atUtc: at(1)),
      GateOutcome(windowId: 'b', outcome: 'viewed', atUtc: at(2)),
      GateOutcome(windowId: 'c', outcome: 'stayed-out', atUtc: at(3)),
      GateOutcome(windowId: 'd', outcome: 'stayed-out', atUtc: at(4)),
    ]);
    expect(s.streak(at(4, 12).toLocal()), 4, reason: 'today counts');
    expect(s.streak(at(5, 12).toLocal()), 4, reason: 'yesterday still counts');
    expect(s.streak(at(6, 12).toLocal()), 0, reason: 'a gap ends it');

    s.amendJournal('c', 'traded-anyway');
    expect(s.streak(at(4, 12).toLocal()), 1, reason: 'the trade on day 3 breaks the run');
  });
}
