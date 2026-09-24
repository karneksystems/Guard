import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guard_app/gate/desktop_gate.dart';
import 'package:guard_app/gate/gate_screen.dart';
import 'package:guard_app/main.dart';
import 'package:guard_app/platform/platform_bridge.dart';
import 'package:guard_app/state/guard_controller.dart';
import 'package:guard_app/state/guard_state.dart';
import 'package:guard_app/sync/sync_payload.dart';
import 'package:guard_app/sync/sync_store.dart';

const payloadJson = {
  'serverTimeUtc': '2026-10-01T08:00:00Z',
  'pro': false,
  'settings': {'mode': 'conservative', 'protection': 'soft-gate', 'window_before_min': 5, 'window_after_min': 5},
  'instruments': [
    {'symbol': 'XAUUSD', 'basket': ['USD', 'EUR', 'GBP']},
  ],
  'events': [
    {'id': '1', 'currency': 'EUR', 'title': 'CPI Flash Estimate y/y', 'impact': 'high', 'scheduledAtUtc': '2026-10-01T09:00:00Z'},
  ],
  'windows': [],
  'ladder': [],
};

class Harness {
  Harness({String protection = 'soft-gate', DateTime? clock}) {
    bridge = FakeBridge();
    state = GuardState(onboarded: true);
    controller = GuardController(state: state, bridge: bridge, store: MemoryStore());
    state.update(SyncPayload.fromJson({
      ...payloadJson,
      'settings': <String, dynamic>{...payloadJson['settings'] as Map<String, dynamic>, 'protection': protection},
    }));
    navigatorKey = GlobalKey<NavigatorState>();
    now = clock ?? DateTime.utc(2026, 10, 1, 8, 57);
    gate = DesktopGate(controller: controller, navigatorKey: navigatorKey, now: () => now)..start();
  }

  late final FakeBridge bridge;
  late final GuardState state;
  late final GuardController controller;
  late final GlobalKey<NavigatorState> navigatorKey;
  late final DesktopGate gate;
  late DateTime now;

  String get windowId => state.windows.single.windowId;

  Widget app() => GuardApp(state: state, controller: controller, navigatorKey: navigatorKey);
}

Future<void> pump(WidgetTester tester, Harness h) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(h.app());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a trigger raises the window and shows the gate with the countdown', (tester) async {
    final h = Harness();
    await pump(tester, h);

    h.bridge.trigger(h.windowId, handle: 777);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(h.bridge.raised, [777]);
    expect(find.byType(GateScreen), findsOneWidget);
    expect(find.text('XAUUSD'), findsOneWidget);
    expect(find.textContaining('CPI Flash Estimate'), findsOneWidget);
    // 08:57 now, closes 09:05: eight minutes on the clock.
    expect(find.text('08:00'), findsOneWidget);
    expect(find.byKey(const Key('gate-hold-view')), findsOneWidget);
    h.gate.stop();
  });

  testWidgets('stay out minimises the trading app, records the outcome and closes the gate', (tester) async {
    final h = Harness();
    await pump(tester, h);
    h.bridge.trigger(h.windowId, handle: 777);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('gate-stay-out')));
    await tester.pumpAndSettle();

    expect(h.bridge.stayedOut, [777]);
    expect(find.byType(GateScreen), findsNothing);
    expect(h.state.journal.single.outcome, 'stayed-out');
    expect(h.gate.showing, isFalse);
    h.gate.stop();
  });

  testWidgets('holding to view lifts the gate for sixty seconds and ignores the next trigger', (tester) async {
    final h = Harness();
    await pump(tester, h);
    h.bridge.trigger(h.windowId);
    await tester.pumpAndSettle();

    final hold = find.byKey(const Key('gate-hold-view'));
    final gesture = await tester.startGesture(tester.getCenter(hold));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Keep holding…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byType(GateScreen), findsNothing);
    expect(h.bridge.viewingUntil, DateTime.utc(2026, 10, 1, 8, 58));
    expect(h.bridge.lowered, 1);
    expect(h.state.journal.single.outcome, 'viewed');

    h.bridge.trigger(h.windowId);
    await tester.pumpAndSettle();
    expect(find.byType(GateScreen), findsNothing, reason: 'inside the viewing grace');
    h.gate.stop();
  });

  testWidgets('releasing early does not count as viewing', (tester) async {
    final h = Harness();
    await pump(tester, h);
    h.bridge.trigger(h.windowId);
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('gate-hold-view'))));
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byType(GateScreen), findsOneWidget);
    expect(h.bridge.viewingUntil, isNull);
    await tester.tap(find.byKey(const Key('gate-stay-out')));
    await tester.pumpAndSettle();
    h.gate.stop();
  });

  testWidgets('hard block has no view option', (tester) async {
    final h = Harness(protection: 'hard-block');
    await pump(tester, h);
    h.bridge.trigger(h.windowId);
    await tester.pumpAndSettle();

    expect(find.byType(GateScreen), findsOneWidget);
    expect(find.byKey(const Key('gate-hold-view')), findsNothing);
    await tester.tap(find.byKey(const Key('gate-stay-out')));
    await tester.pumpAndSettle();
    h.gate.stop();
  });

  testWidgets('warn only never shows the gate', (tester) async {
    final h = Harness(protection: 'warn-only');
    await pump(tester, h);
    h.bridge.trigger(h.windowId);
    await tester.pumpAndSettle();

    expect(find.byType(GateScreen), findsNothing);
    expect(h.bridge.raised, isEmpty);
    h.gate.stop();
  });

  testWidgets('a trigger after the window closed is ignored', (tester) async {
    final h = Harness(clock: DateTime.utc(2026, 10, 1, 9, 10));
    await pump(tester, h);
    h.bridge.trigger(h.windowId);
    await tester.pumpAndSettle();

    expect(find.byType(GateScreen), findsNothing);
    h.gate.stop();
  });
}
