import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guard_app/platform/platform_bridge.dart';
import 'package:guard_app/state/guard_controller.dart';
import 'package:guard_app/state/guard_state.dart';
import 'package:guard_app/sync/api_client.dart';
import 'package:guard_app/sync/sync_payload.dart';
import 'package:guard_app/sync/sync_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const payloadJson = {
  'serverTimeUtc': '2026-10-01T06:00:00Z',
  'pro': false,
  'settings': {'mode': 'conservative', 'protection': 'soft-gate', 'window_before_min': 5, 'window_after_min': 5},
  'instruments': [
    {'symbol': 'XAUUSD', 'basket': ['USD', 'EUR', 'GBP']},
  ],
  'events': [
    {'id': '1', 'currency': 'EUR', 'title': 'CPI Flash Estimate y/y', 'impact': 'high', 'scheduledAtUtc': '2026-10-01T09:00:00Z'},
    {'id': '2', 'currency': 'USD', 'title': 'Non-Farm Payrolls', 'impact': 'high', 'scheduledAtUtc': '2026-10-02T12:30:00Z'},
  ],
  'windows': [],
  'ladder': [],
};

void main() {
  test('a payload hands the device engine\'s windows to the platform gate in epoch ms', () async {
    final bridge = FakeBridge();
    final state = GuardState(onboarded: true);
    final c = GuardController(state: state, bridge: bridge, store: MemoryStore());

    await c.applyPayload(SyncPayload.fromJson(payloadJson));

    expect(bridge.scheduleCalls, 1);
    expect(bridge.scheduledWindows.length, 2);
    final cpi = bridge.scheduledWindows.first;
    expect(cpi.instrument, 'XAUUSD');
    expect(cpi.opensAtMs, DateTime.utc(2026, 10, 1, 8, 55).millisecondsSinceEpoch);
    expect(cpi.closesAtMs, DateTime.utc(2026, 10, 1, 9, 5).millisecondsSinceEpoch);
    expect(cpi.events, 'CPI Flash Estimate y/y');
    expect(bridge.scheduledGatedAppIds, ['net.metaquotes.metatrader5']);
    expect(bridge.scheduledProtection, 'soft-gate');
  });

  test('changing protection or gated apps re-pushes the schedule', () async {
    final bridge = FakeBridge();
    final c = GuardController(state: GuardState(onboarded: true), bridge: bridge, store: MemoryStore());
    await c.applyPayload(SyncPayload.fromJson(payloadJson));

    await c.updateSettings({'protection': 'warn-only'});
    expect(bridge.scheduledProtection, 'warn-only');

    await c.setGatedApps(['net.metaquotes.metatrader5', 'com.spotware.ct']);
    expect(bridge.scheduledGatedAppIds, contains('com.spotware.ct'));
    expect(bridge.scheduleCalls, 3);
  });

  test('a platform without a gate is never asked to schedule', () async {
    final bridge = FakeBridge()..hasGate = false;
    final c = GuardController(state: GuardState(onboarded: true), bridge: bridge, store: MemoryStore());

    await c.applyPayload(SyncPayload.fromJson(payloadJson));

    expect(bridge.scheduleCalls, 0);
  });

  test('gate outcomes drain into state and post to the backend without any package name', () async {
    final requests = <http.Request>[];
    final api = ApiClient(
      baseUrl: 'https://guard.test',
      token: 'tok-1',
      client: MockClient((r) async {
        requests.add(r);
        return http.Response('{"ok":true,"id":1}', 201);
      }),
    );
    final bridge = FakeBridge()
      ..pendingOutcomes.addAll([
        GateOutcome(windowId: 'w' * 20, outcome: 'stayed-out', atUtc: DateTime.utc(2026, 10, 1, 8, 57)),
        GateOutcome(windowId: 'w' * 20, outcome: 'viewed', atUtc: DateTime.utc(2026, 10, 1, 9, 1)),
      ]);
    final state = GuardState(onboarded: true);
    final c = GuardController(state: state, bridge: bridge, api: api, store: MemoryStore());

    await c.drainGateJournal();

    expect(state.journal.map((e) => e.outcome), ['viewed', 'stayed-out']); // newest first
    expect(requests.length, 2);
    for (final r in requests) {
      expect(r.url.path, '/api/journal');
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), {'window_id', 'outcome', 'at_utc'});
      expect(r.body.contains('metaquotes'), isFalse);
    }
    expect(await bridge.drainJournal(), isEmpty, reason: 'drained once');
  });
}
