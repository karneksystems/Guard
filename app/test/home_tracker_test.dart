import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guard_app/features/tracker.dart';
import 'package:guard_app/main.dart';
import 'package:guard_app/notifications/notification_scheduler.dart';
import 'package:guard_app/notifications/reminders.dart';
import 'package:guard_app/platform/platform_bridge.dart';
import 'package:guard_app/screens/home_screen.dart';
import 'package:guard_app/screens/tracker_screen.dart';
import 'package:guard_app/state/guard_controller.dart';
import 'package:guard_app/state/guard_state.dart';
import 'package:guard_app/sync/sync_store.dart';

class Harness {
  Harness({DateTime? now}) {
    scheduler = FakeScheduler();
    store = MemoryStore();
    state = GuardState(onboarded: true);
    controller = GuardController(
      state: state,
      bridge: FakeBridge(supported: const {}),
      store: store,
      reminders: ReminderPlanner(scheduler, utcOffset: Duration.zero),
      now: () => now ?? DateTime.utc(2026, 9, 30, 10),
    );
  }

  late final FakeScheduler scheduler;
  late final MemoryStore store;
  late final GuardState state;
  late final GuardController controller;

  Widget app() => GuardApp(state: state, controller: controller);
}

Future<void> pump(WidgetTester tester, Harness h) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(h.app());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('home tiles start unset and open the tracker', (tester) async {
    final h = Harness();
    await pump(tester, h);
    await tester.dragUntilVisible(find.byKey(const Key('home-loss')), find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.text('Set'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-loss')));
    await tester.pumpAndSettle();
    expect(find.byType(TrackerScreen), findsOneWidget);
  });

  testWidgets('setting a limit and logging a loss updates room left, persists, and counts a traded day', (tester) async {
    final h = Harness();
    await pump(tester, h);
    await tester.dragUntilVisible(find.byKey(const Key('home-loss')), find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-loss')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tracker-set-limit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tracker-number')), '500');
    await tester.tap(find.byKey(const Key('tracker-number-ok')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Room left today: \$500 of \$500'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tracker-log')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tracker-number')), '-120');
    await tester.tap(find.byKey(const Key('tracker-number-ok')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Room left today: \$380 of \$500'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tracker-set-days')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tracker-number')), '5');
    await tester.tap(find.byKey(const Key('tracker-number-ok')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 of 5 traded · 4 to go'), findsOneWidget);

    final saved = Tracker.fromJson((await h.store.prefs())['tracker'] as Map<String, dynamic>);
    expect(saved.dailyLossLimit, 500);
    expect(saved.entries.single.amount, -120);
    expect(saved.entries.single.date, '2026-09-30');

    // Back on Home the tiles reflect it.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(find.byKey(const Key('home-loss')), find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.text('\$380'), findsOneWidget);
    expect(find.text('1 of 5'), findsOneWidget);
  });

  testWidgets('reminders follow the tracker: weekend on by default, inactivity after a logged trade', (tester) async {
    final h = Harness();
    await pump(tester, h);
    await h.controller.refreshReminders();
    expect(h.scheduler.pending.values.map((n) => n.alertId), contains('weekend:2026-10-02'));
    expect(h.scheduler.pending.values.map((n) => n.alertId), isNot(contains(startsWith('inactivity'))));

    await h.controller.logPnl(-10);
    expect(h.scheduler.pending.values.map((n) => n.alertId), contains('inactivity:2026-09-30'));
    // Sample data has windows on 1 Oct: the digest for it fires tonight at 20:00.
    final digest = h.scheduler.pending.values.singleWhere((n) => n.alertId == 'digest:2026-10-01');
    expect(digest.atUtc, DateTime.utc(2026, 9, 30, 20));
  });

  testWidgets('the weekend banner shows on Friday afternoon and the digest screen lists tomorrow', (tester) async {
    final h = Harness(now: DateTime.utc(2026, 10, 2, 14));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GuardApp(
      state: h.state,
      controller: h.controller,
      home: Scaffold(body: HomeScreen(now: DateTime.utc(2026, 9, 30, 14))),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-weekend')), findsNothing, reason: 'Wednesday');
    await tester.dragUntilVisible(find.byKey(const Key('home-tomorrow')), find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tomorrow: 3 restricted windows'), findsOneWidget);

    await tester.pumpWidget(GuardApp(
      state: h.state,
      controller: h.controller,
      home: Scaffold(body: HomeScreen(now: DateTime.utc(2026, 10, 2, 14))),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-weekend')), findsOneWidget, reason: 'Friday afternoon');

    await tester.dragUntilVisible(find.byKey(const Key('home-tomorrow')), find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-tomorrow')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('digest-count')), findsOneWidget);
  });

  testWidgets('a viewed journal entry can be self-reported as traded', (tester) async {
    final h = Harness();
    await pump(tester, h);
    h.state.addJournal([GateOutcome(windowId: 'w1', outcome: 'viewed', atUtc: DateTime.utc(2026, 9, 30, 9))]);
    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('journal-traded-w1')));
    await tester.pumpAndSettle();
    expect(h.state.journal.first.outcome, 'traded-anyway');
    expect(find.text('Traded anyway'), findsOneWidget);
  });
}
