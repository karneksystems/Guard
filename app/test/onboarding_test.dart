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
    expect(find.text('How should it protect you?'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('walking through the six steps writes settings, instruments, gated apps and the flag', (tester) async {
    final h = Harness();
    await pump(tester, h.app());

    // 1 protection: keep soft gate (default). Hard block is disabled on Free.
    final hard = tester.widget<RadioListTile<String>>(find.byKey(const Key('choice-hard-block')));
    expect(hard.enabled, isFalse);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    // 2 instruments: gold is preselected; add EURUSD; a third is refused on Free.
    await tester.tap(find.byKey(const Key('inst-EURUSD')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inst-GBPUSD')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    // 3 rules: conservative (firm match disabled on Free)
    final firm = tester.widget<RadioListTile<String>>(find.byKey(const Key('choice-firm-match')));
    expect(firm.enabled, isFalse);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    // 4 window: fixed on Free
    final ten = tester.widget<ChoiceChip>(find.byKey(const Key('window-10')));
    expect(ten.onSelected, isNull);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    // 5 gated apps: MT5 on by default, add cTrader
    expect(find.byKey(const Key('gate-net.metaquotes.metatrader5')), findsOneWidget);
    await tester.tap(find.byKey(const Key('gate-com.spotware.ct')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    // 6 explainer
    expect(find.text('We never touch your trades.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    // Landed on Home
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(h.state.onboarded, isTrue);
    expect(h.state.instruments.map((i) => i['symbol']), ['XAUUSD', 'EURUSD']);
    expect(h.state.gatedAppIds.toSet(), {'net.metaquotes.metatrader5', 'com.spotware.ct'});
    expect(h.state.settings['protection'], 'soft-gate');

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
    }
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
    expect(find.text('Usage access · Display over other apps'), findsOneWidget);

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
    expect(find.text('Warn only'), findsOneWidget);

    final put = h.requests.singleWhere((r) => r.url.path == '/api/settings');
    expect(jsonDecode(put.body), {'protection': 'warn-only'});
  });
}
