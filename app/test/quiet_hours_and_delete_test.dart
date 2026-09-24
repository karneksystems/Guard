import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guard_app/notifications/ladder_mirror.dart';
import 'package:guard_app/notifications/notification_scheduler.dart';
import 'package:guard_app/platform/platform_bridge.dart';
import 'package:guard_app/state/guard_controller.dart';
import 'package:guard_app/state/guard_state.dart';
import 'package:guard_app/sync/api_client.dart';
import 'package:guard_app/sync/sync_payload.dart';
import 'package:guard_app/sync/sync_service.dart';
import 'package:guard_app/sync/sync_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

SyncPayload payload() => SyncPayload.fromJson({
      'serverTimeUtc': '2026-10-02T00:00:00Z',
      'pro': false,
      'settings': <String, dynamic>{'quiet_hours': {'start': '23:00', 'end': '06:00'}},
      'instruments': [],
      'events': [
        {'id': '7', 'currency': 'USD', 'title': 'FOMC', 'impact': 'high', 'scheduledAtUtc': '2026-10-02T02:00:00Z'},
      ],
      'windows': [
        {'windowId': 'w' * 20, 'instrument': 'XAUUSD', 'opensAtUtc': '2026-10-02T01:55:00Z', 'closesAtUtc': '2026-10-02T02:05:00Z', 'reasons': ['7'], 'verified': true},
      ],
      'ladder': [
        {'alertId': 'a1'.padRight(20, '0'), 'windowId': 'w' * 20, 'kind': 't-60', 'fireAtUtc': '2026-10-02T00:55:00Z'},
        {'alertId': 'a2'.padRight(20, '0'), 'windowId': 'w' * 20, 'kind': 't-15', 'fireAtUtc': '2026-10-02T01:40:00Z'},
        {'alertId': 'a3'.padRight(20, '0'), 'windowId': 'w' * 20, 'kind': 't-5', 'fireAtUtc': '2026-10-02T01:50:00Z'},
        {'alertId': 'a4'.padRight(20, '0'), 'windowId': 'w' * 20, 'kind': 't-1', 'fireAtUtc': '2026-10-02T01:54:00Z'},
        {'alertId': 'a5'.padRight(20, '0'), 'windowId': 'w' * 20, 'kind': 'open', 'fireAtUtc': '2026-10-02T01:55:00Z'},
        {'alertId': 'a6'.padRight(20, '0'), 'windowId': 'w' * 20, 'kind': 'end', 'fireAtUtc': '2026-10-02T02:05:00Z'},
      ],
    });

void main() {
  test('quiet hours keep T-5, T-1 and open in the local mirror and drop the rest', () async {
    final scheduler = FakeScheduler();
    // User in UTC+1: 00:55 UTC is 01:55 local, inside 23:00 to 06:00.
    final mirror = LadderMirror(scheduler, utcOffset: const Duration(hours: 1));
    final p = payload();
    final r = await mirror.reconcile(p, now: DateTime.utc(2026, 10, 2), quietHours: p.settings['quietHours'] as Map<String, dynamic>?);
    expect(r.scheduled, 3);
    expect(scheduler.pending.values.map((n) => n.alertId.substring(0, 2)).toSet(), {'a3', 'a4', 'a5'});

    // Quiet hours off: all six.
    final all = await LadderMirror(FakeScheduler(), utcOffset: const Duration(hours: 1)).reconcile(p, now: DateTime.utc(2026, 10, 2));
    expect(all.scheduled, 6);

    // A range that does not cross midnight, and a fire time just outside it.
    final m = LadderMirror(FakeScheduler(), utcOffset: Duration.zero);
    expect(m.inQuietHours({'start': '01:00', 'end': '03:00'}, DateTime.utc(2026, 10, 2, 2, 59)), isTrue);
    expect(m.inQuietHours({'start': '01:00', 'end': '03:00'}, DateTime.utc(2026, 10, 2, 3, 0)), isFalse);
    expect(m.inQuietHours({'start': '01:00', 'end': '01:00'}, DateTime.utc(2026, 10, 2, 1, 0)), isFalse);
  });

  test('quiet hours travel to the server in snake_case and reach the mirror', () async {
    final seen = <http.Request>[];
    final client = MockClient((r) async {
      seen.add(r);
      if (r.url.path == '/api/devices') return http.Response(jsonEncode({'deviceId': 'd', 'token': 't'}), 201);
      if (r.url.path == '/api/sync') return http.Response(jsonEncode(payload().toJson()..['settings'] = <String, dynamic>{}), 200);
      return http.Response('{"ok":true}', 200);
    });
    final api = ApiClient(baseUrl: 'https://guard.test', client: client);
    final store = MemoryStore();
    final scheduler = FakeScheduler();
    final state = GuardState(onboarded: true);
    final c = GuardController(
      state: state,
      bridge: FakeBridge(supported: const {}),
      api: api,
      store: store,
      sync: SyncService(api: api, store: store, platform: 'android', tz: 'UTC', appVersion: '0'),
      mirror: LadderMirror(scheduler, utcOffset: const Duration(hours: 1)),
      now: () => DateTime.utc(2026, 10, 2),
    );
    await c.start();
    expect(scheduler.pending.length, 6);

    await c.updateSettings({'quietHours': {'start': '23:00', 'end': '06:00'}});
    final put = seen.lastWhere((r) => r.url.path == '/api/settings');
    expect(jsonDecode(put.body), {'quiet_hours': {'start': '23:00', 'end': '06:00'}});
    expect(scheduler.pending.length, 3);
  });

  test('delete everything calls the server, wipes the store, resets state and clears the schedules', () async {
    final seen = <http.Request>[];
    final client = MockClient((r) async {
      seen.add(r);
      if (r.url.path == '/api/devices') return http.Response(jsonEncode({'deviceId': 'd', 'token': 't'}), 201);
      if (r.url.path == '/api/sync') return http.Response(jsonEncode(payload().toJson()), 200);
      return http.Response('{"ok":true}', 200);
    });
    final api = ApiClient(baseUrl: 'https://guard.test', client: client);
    final store = MemoryStore();
    final scheduler = FakeScheduler();
    final bridge = FakeBridge();
    final state = GuardState(onboarded: true);
    final c = GuardController(
      state: state,
      bridge: bridge,
      api: api,
      store: store,
      sync: SyncService(api: api, store: store, platform: 'android', tz: 'UTC', appVersion: '0'),
      mirror: LadderMirror(scheduler),
      now: () => DateTime.utc(2026, 10, 2),
    );
    await c.start();
    await c.finishOnboarding();
    await c.logPnl(-5);
    expect(scheduler.pending, isNotEmpty);
    expect(await store.credentials(), isNotNull);

    expect(await c.deleteEverything(), isTrue);

    final del = seen.singleWhere((r) => r.method == 'DELETE');
    expect(del.url.path, '/api/account');
    expect(del.headers['Authorization'], 'Bearer t');
    expect(await store.credentials(), isNull);
    expect(await store.prefs(), isEmpty);
    expect(state.onboarded, isFalse);
    expect(state.tracker.entries, isEmpty);
    expect(state.isSample, isTrue);
    expect(scheduler.pending, isEmpty);
    expect(bridge.scheduledWindows, isEmpty);
    expect(api.token, isNull);
  });

  test('delete everything does nothing when the server is unreachable', () async {
    final client = MockClient((r) async {
      if (r.url.path == '/api/devices') return http.Response(jsonEncode({'deviceId': 'd', 'token': 't'}), 201);
      if (r.url.path == '/api/account') return http.Response('down', 503);
      return http.Response(jsonEncode(payload().toJson()), 200);
    });
    final api = ApiClient(baseUrl: 'https://guard.test', client: client);
    final store = MemoryStore();
    final state = GuardState(onboarded: true);
    final c = GuardController(
      state: state,
      bridge: FakeBridge(),
      api: api,
      store: store,
      sync: SyncService(api: api, store: store, platform: 'android', tz: 'UTC', appVersion: '0'),
    );
    await c.start();
    expect(await c.deleteEverything(), isFalse);
    expect(await store.credentials(), isNotNull);
    expect(state.isSample, isFalse);
  });
}
