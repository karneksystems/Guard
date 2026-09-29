import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guard_app/main.dart';
import 'package:guard_app/platform/platform_bridge.dart';
import 'package:guard_app/state/guard_controller.dart';
import 'package:guard_app/state/guard_state.dart';
import 'package:guard_app/state/news_phase.dart';

NewsSpan span(String id, DateTime opens, DateTime closes) =>
    NewsSpan(windowId: id, instrument: 'XAUUSD', events: 'CPI 13:30', opens: opens, closes: closes);

void main() {
  final t0 = DateTime.utc(2026, 9, 29, 12);

  test('clear, then amber five minutes out, red while open, clear after', () {
    final s = [span('a', t0.add(const Duration(minutes: 10)), t0.add(const Duration(minutes: 20)))];
    final far = newsAt(s, t0);
    expect(far.phase, NewsPhase.clear);
    expect(far.nextChange, t0.add(const Duration(minutes: 5)));
    expect(newsAt(s, t0.add(const Duration(minutes: 5))).phase, NewsPhase.soon);
    final live = newsAt(s, t0.add(const Duration(minutes: 10)));
    expect(live.phase, NewsPhase.live);
    expect(live.span!.windowId, 'a');
    expect(live.nextChange, t0.add(const Duration(minutes: 20)));
    final after = newsAt(s, t0.add(const Duration(minutes: 20)));
    expect(after.phase, NewsPhase.clear);
    expect(after.nextChange, isNull);
  });

  test('a live window beats a soon one, and the latest close wins among live ones', () {
    final s = [
      span('soon', t0.add(const Duration(minutes: 3)), t0.add(const Duration(minutes: 8))),
      span('short', t0.subtract(const Duration(minutes: 1)), t0.add(const Duration(minutes: 2))),
      span('long', t0.subtract(const Duration(minutes: 2)), t0.add(const Duration(minutes: 6))),
    ];
    final n = newsAt(s, t0);
    expect(n.phase, NewsPhase.live);
    expect(n.span!.windowId, 'long');
    expect(n.nextChange, t0.add(const Duration(minutes: 2)));
  });

  testWidgets('the edge glows amber before the test window and red while it is open', (tester) async {
    var clock = t0;
    final state = GuardState(onboarded: true, now: () => clock);
    final bridge = FakeBridge();
    final controller = GuardController(state: state, bridge: bridge, now: () => clock);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GuardApp(state: state, controller: controller));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('news-glow-soon')), findsNothing);
    expect(find.byKey(const Key('news-glow-live')), findsNothing);

    await controller.startTestWindow(); // opens at t0+2, closes at t0+4
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('news-glow-soon')), findsOneWidget);

    clock = t0.add(const Duration(minutes: 2, seconds: 1));
    await tester.pump(const Duration(minutes: 2, seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('news-glow-live')), findsOneWidget);

    clock = t0.add(const Duration(minutes: 4, seconds: 1));
    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('news-glow-live')), findsNothing);
    expect(find.byKey(const Key('news-glow-soon')), findsNothing);

    // The Lock Screen countdown followed along: nothing sent while clear, then
    // amber, red and clear, each once.
    expect(bridge.countdowns.map((c) => c.phase), ['soon', 'live', 'clear']);
    expect(bridge.countdowns.first.windowId, 'test-window-000000000');
    expect(bridge.countdowns.first.events, 'Test window');
    expect(bridge.countdowns.first.opensAtMs, t0.add(const Duration(minutes: 2)).millisecondsSinceEpoch);
  });

  testWidgets('the countdown starts an hour out in sky and turns amber at five minutes', (tester) async {
    // The sample calendar's EUR CPI at 09:00 UTC on 1 Oct gives XAUUSD a window.
    final opens = DateTime.parse(GuardState(onboarded: true).windows.first.opensAtUtc).toUtc();
    var clock = opens.subtract(const Duration(minutes: 90));
    final state = GuardState(onboarded: true, now: () => clock);
    final bridge = FakeBridge();
    final controller = GuardController(state: state, bridge: bridge, now: () => clock);
    await tester.pumpWidget(GuardApp(state: state, controller: controller));
    await tester.pumpAndSettle();
    expect(bridge.countdowns, isEmpty);

    clock = opens.subtract(const Duration(minutes: 59));
    await tester.pump(const Duration(minutes: 31));
    await tester.pumpAndSettle();
    expect(bridge.countdowns.map((c) => c.phase), ['upcoming']);

    clock = opens.subtract(const Duration(minutes: 4, seconds: 59));
    await tester.pump(const Duration(minutes: 55));
    await tester.pumpAndSettle();
    expect(bridge.countdowns.map((c) => c.phase), ['upcoming', 'soon']);
    expect(find.byKey(const Key('news-glow-soon')), findsOneWidget);
  });

  testWidgets('nothing reaches the Lock Screen before onboarding', (tester) async {
    var clock = t0;
    final state = GuardState(now: () => clock);
    final bridge = FakeBridge();
    final controller = GuardController(state: state, bridge: bridge, now: () => clock);
    await tester.pumpWidget(GuardApp(state: state, controller: controller));
    await controller.startTestWindow();
    await tester.pumpAndSettle();
    expect(bridge.countdowns, isEmpty);
  });
}
