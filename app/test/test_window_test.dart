import 'package:flutter_test/flutter_test.dart';
import 'package:guard_app/notifications/ladder_mirror.dart';
import 'package:guard_app/notifications/notification_scheduler.dart';
import 'package:guard_app/platform/platform_bridge.dart';
import 'package:guard_app/state/guard_controller.dart';
import 'package:guard_app/state/guard_state.dart';
import 'package:guard_app/sync/sync_store.dart';

void main() {
  test('a test window is handed to the gate alongside the real ones, with its two alerts', () async {
    final bridge = FakeBridge();
    final scheduler = FakeScheduler();
    final c = GuardController(
      state: GuardState(onboarded: true),
      bridge: bridge,
      store: MemoryStore(),
      mirror: LadderMirror(scheduler),
      now: () => DateTime.utc(2026, 9, 24, 18, 0),
    );
    final id = await c.startTestWindow();
    final test = bridge.scheduledWindows.singleWhere((w) => w.windowId == id);
    expect(test.opensAtMs, DateTime.utc(2026, 9, 24, 18, 2).millisecondsSinceEpoch);
    expect(test.closesAtMs, DateTime.utc(2026, 9, 24, 18, 4).millisecondsSinceEpoch);
    expect(bridge.scheduledWindows.length, greaterThan(1), reason: 'the sample windows stay');
    final t1 = scheduler.pending.values.singleWhere((n) => n.alertId == 'test:t-1');
    expect(t1.atUtc, DateTime.utc(2026, 9, 24, 18, 1));
    expect(t1.channel, 'ladder_urgent');
    expect(scheduler.pending.values.singleWhere((n) => n.alertId == 'test:open').title, 'Restricted: TEST');
  });
}
