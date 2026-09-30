import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guard_app/main.dart';
import 'package:guard_app/platform/platform_bridge.dart';
import 'package:guard_app/state/guard_controller.dart';
import 'package:guard_app/state/guard_state.dart';
import 'package:guard_app/sync/api_client.dart';
import 'package:guard_app/sync/sync_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class Harness {
  Harness({bool onboarded = false, Map<GuardPermission, bool>? granted})
      : requests = [],
        store = MemoryStore(),
        bridge = FakeBridge(granted: granted ?? {for (final p in GuardPermission.values) p: true}) {
    final api = ApiClient(
      baseUrl: 'https://guard.test',
      token: 'tok-1',
      client: MockClient((r) async {
        requests.add(r);
        return http.Response('{"ok":true}', 200);
      }),
    );
    state = GuardState(onboarded: onboarded);
    controller = GuardController(state: state, bridge: bridge, api: api, store: store);
  }

  final List<http.Request> requests;
  final MemoryStore store;
  final FakeBridge bridge;
  late final GuardState state;
  late final GuardController controller;

  Widget app() => GuardApp(state: state, controller: controller);
}

Future<void> pump(WidgetTester tester, Widget app, {Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a new install lands on onboarding, not Home', (tester) async {
    final h = Harness();
    await pump(tester, h.app());
    expect(find.text('What do you trade?'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('the three steps write settings, instruments, gated apps and the flag', (tester) async {
    final h = Harness();
    await pump(tester, h.app());

    // 1 markets: gold and EUR are picked; Free watches two, so a third is off.
    expect(tester.widget<Opacity>(find.ancestor(of: find.byKey(const Key('inst-GBPUSD')), matching: find.byType(Opacity)).first).opacity, lessThan(1));
    await tester.tap(find.byKey(const Key('inst-GBPUSD')));
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    // 2 alerts and apps: one switch for notifications, MT5 covered by default.
    expect(find.text('Skip for now'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-allow-notifications')));
    await tester.pumpAndSettle();
    expect(h.bridge.requested, [GuardPermission.notifications]);
    expect(find.byKey(const Key('onboarding-notifications-on')), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('MetaTrader 5'), findsNothing);
    expect(find.text('MT5'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-cover-row')));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('gate-net.metaquotes.metatrader5'))).value, isTrue);
    await tester.tap(find.byKey(const Key('gate-com.spotware.ct')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('gate-done')));
    await tester.pumpAndSettle();
    expect(find.text('MT5, cTrader'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    // 3 you're set
    expect(find.text("You're set"), findsOneWidget);
    expect(find.textContaining('Cover is on for gold, EUR.'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-next-steps')), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    // Landed on Home with the safe defaults.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(h.state.onboarded, isTrue);
    expect(h.state.instruments.map((i) => i['symbol']), ['XAUUSD', 'EURUSD']);
    expect(h.state.gatedAppIds.toSet(), {'net.metaquotes.metatrader5', 'com.spotware.ct'});
    expect(h.state.settings['protection'], 'soft-gate');
    expect(h.state.settings['mode'], 'conservative');
    expect(h.state.tracker.tomorrowNews, isTrue);

    // Wire: one settings PUT and one instruments PUT, snake_case on settings.
    final puts = h.requests.where((r) => r.method == 'PUT').toList();
    expect(puts.map((r) => r.url.path), ['/api/settings', '/api/instruments']);
    final settingsBody = jsonDecode(puts.first.body) as Map<String, dynamic>;
    expect(settingsBody['window_before_min'], 5);
    expect(settingsBody['protection'], 'soft-gate');
    final instBody = jsonDecode(puts.last.body) as Map<String, dynamic>;
    expect((instBody['instruments'] as List).length, 2);

    // Persisted: prefs in the store, gated apps never in any request body.
    final prefs = await h.store.prefs();
    expect(prefs['onboarded'], isTrue);
    expect((prefs['gatedApps'] as List).length, 2);
    for (final r in h.requests) {
      expect(r.body.contains('metaquotes'), isFalse, reason: 'gated app ids must never leave the device');
      expect(r.body.contains('spotware'), isFalse, reason: 'gated app ids must never leave the device');
    }
  });

  testWidgets('with alerts refused, step two offers a skip and setup still finishes', (tester) async {
    final h = Harness(granted: {for (final p in GuardPermission.values) p: false});
    await pump(tester, h.app());
    // Down to gold alone, then on.
    await tester.tap(find.byKey(const Key('inst-EURUSD')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-allow-notifications')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onboarding-notifications-on')), findsNothing);
    expect(find.text('Skip for now'), findsOneWidget);
    // Alarms are off, so the plain warning shows. Tomorrow's news goes off.
    expect(find.byKey(const Key('onboarding-alarms-warning')), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-tomorrow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(h.state.onboarded, isTrue);
    expect(h.state.instruments.map((i) => i['symbol']), ['XAUUSD']);
    expect(h.state.tracker.tomorrowNews, isFalse);
  });

  testWidgets('an onboarded install goes straight to Home and the banner shows missing permissions', (tester) async {
    final h = Harness(onboarded: true, granted: {
      for (final p in GuardPermission.values) p: true,
      GuardPermission.usageStats: false,
      GuardPermission.overlay: false,
    });
    await h.controller.refreshPermissions();
    await pump(tester, h.app());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const Key('permission-banner')), findsOneWidget);
    expect(find.text('Usage access · Display over apps'), findsOneWidget);

    // Tapping through opens the permissions screen; granting refreshes the banner.
    await tester.tap(find.byKey(const Key('permission-banner')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('grant-usageStats')), findsOneWidget);
    h.bridge.grant(GuardPermission.usageStats);
    h.bridge.grant(GuardPermission.overlay);
    await tester.tap(find.byKey(const Key('grant-usageStats')));
    await tester.pumpAndSettle();
    expect(h.bridge.requested, [GuardPermission.usageStats]);
    expect(h.state.missingPermissions, isEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('permission-banner')), findsNothing);
  });

  testWidgets('settings edits apply locally and PUT to the backend', (tester) async {
    final h = Harness(onboarded: true);
    await pump(tester, h.app());
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('setting-protection')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('option-warn-only')));
    await tester.pumpAndSettle();
    expect(h.state.settings['protection'], 'warn-only');
    expect(find.text('Warnings only'), findsOneWidget);

    final put = h.requests.singleWhere((r) => r.url.path == '/api/settings');
    expect(jsonDecode(put.body), {'protection': 'warn-only'});
  });
}
