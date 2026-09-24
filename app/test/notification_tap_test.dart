import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guard_app/main.dart';
import 'package:guard_app/notifications/ladder_mirror.dart';
import 'package:guard_app/notifications/notification_scheduler.dart';
import 'package:guard_app/platform/platform_bridge.dart';
import 'package:guard_app/screens/digest_screen.dart';
import 'package:guard_app/screens/windows_screen.dart';
import 'package:guard_app/state/guard_controller.dart';
import 'package:guard_app/state/guard_state.dart';
import 'package:guard_app/sync/sync_payload.dart';
import 'package:guard_app/sync/sync_store.dart';

SyncPayload payload() => SyncPayload.fromJson({
      'serverTimeUtc': '2026-10-02T06:00:00Z',
      'pro': false,
      'settings': <String, dynamic>{},
      'instruments': [
        {'symbol': 'XAUUSD', 'basket': ['USD']},
      ],
      'events': [
        {'id': '7', 'currency': 'USD', 'title': 'Non-Farm Payrolls', 'impact': 'high', 'scheduledAtUtc': '2026-10-02T12:30:00Z'},
      ],
      'windows': [
        {'windowId': 'w' * 20, 'instrument': 'XAUUSD', 'opensAtUtc': '2026-10-02T12:25:00Z', 'closesAtUtc': '2026-10-02T12:35:00Z', 'reasons': ['7'], 'verified': true},
      ],
      'ladder': [
        {'alertId': 'a5'.padRight(20, '0'), 'windowId': 'w' * 20, 'kind': 'open', 'fireAtUtc': '2026-10-02T12:25:00Z'},
      ],
    });

void main() {
  late FakeScheduler scheduler;
  late GuardState state;
  late GuardController controller;

  setUp(() async {
    scheduler = FakeScheduler();
    state = GuardState(onboarded: true);
    controller = GuardController(
      state: state,
      bridge: FakeBridge(supported: const {}),
      store: MemoryStore(),
      mirror: LadderMirror(scheduler),
      now: () => DateTime.utc(2026, 10, 2, 12, 25, 30),
    );
    await controller.start();
    await controller.applyPayload(payload());
  });

  testWidgets('tapping a rung opens the Windows tab and the digest opens tomorrow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GuardApp(state: state, controller: controller));
    await tester.pumpAndSettle();
    expect(find.byType(WindowsScreen), findsNothing);

    scheduler.tap('a5'.padRight(20, '0'));
    await tester.pumpAndSettle();
    expect(find.byType(WindowsScreen), findsOneWidget);

    scheduler.tap('digest:2026-10-03');
    await tester.pumpAndSettle();
    expect(find.byType(DigestScreen), findsOneWidget);
  });

  test('snooze re-schedules the same rung a minute later with the same words', () async {
    final id = notificationIdFor('a5'.padRight(20, '0'));
    expect(scheduler.pending.containsKey(id), isFalse, reason: 'fire time is in the past at start');

    scheduler.tap('a5'.padRight(20, '0'), action: LocalNotificationScheduler.snoozeAction);
    await Future<void>.delayed(Duration.zero);

    final n = scheduler.pending[id]!;
    expect(n.atUtc, DateTime.utc(2026, 10, 2, 12, 26, 30));
    expect(n.title, 'Restricted: XAUUSD');
    expect(n.channel, 'ladder_urgent');
  });
}
