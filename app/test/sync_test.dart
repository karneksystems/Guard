import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guard_app/state/guard_state.dart';
import 'package:guard_app/sync/api_client.dart';
import 'package:guard_app/sync/sync_payload.dart';
import 'package:guard_app/sync/sync_service.dart';
import 'package:guard_app/sync/sync_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const serverSync = {
  'serverTimeUtc': '2026-10-01T06:00:00Z',
  'pro': false,
  'settings': {'mode': 'conservative', 'protection': 'soft-gate', 'window_before_min': 5, 'window_after_min': 5, 'firm_id': null, 'account_type_id': null, 'digest_local_time': '20:00'},
  'instruments': [
    {'symbol': 'XAUUSD', 'basket': ['USD', 'EUR', 'GBP']},
  ],
  'events': [
    {'id': '1', 'currency': 'EUR', 'title': 'CPI Flash Estimate y/y', 'impact': 'high', 'scheduledAtUtc': '2026-10-01T09:00:00Z', 'tentative': false, 'source': 'fake'},
    {'id': '2', 'currency': 'USD', 'title': 'Chicago PMI', 'impact': 'medium', 'scheduledAtUtc': '2026-10-01T13:45:00Z', 'tentative': false, 'source': 'fake'},
  ],
  'windows': [],
  'ladder': [],
};

MockClient fakeServer({bool failSync = false, List<http.Request>? seen}) {
  return MockClient((request) async {
    seen?.add(request);
    if (request.method == 'POST' && request.url.path == '/api/devices') {
      return http.Response(jsonEncode({'deviceId': 'dev-1', 'token': 'tok-1'}), 201);
    }
    if (request.headers['Authorization'] != 'Bearer tok-1') {
      return http.Response('{"error":"unauthenticated"}', 401);
    }
    if (request.method == 'GET' && request.url.path == '/api/sync') {
      if (failSync) return http.Response('down', 503);
      return http.Response(jsonEncode(serverSync), 200);
    }
    return http.Response('{"ok":true}', 200);
  });
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('guard-sync-');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('registers once, stores credentials, and syncs with the bearer token', () async {
    final seen = <http.Request>[];
    final api = ApiClient(baseUrl: 'https://guard.test', client: fakeServer(seen: seen));
    final service = SyncService(api: api, store: SyncStore(dir), platform: 'android', tz: 'Europe/London', appVersion: '0.1.0');

    final payload = await service.sync();
    expect(payload, isNotNull);
    expect(payload!.instruments.single['symbol'], 'XAUUSD');
    expect(seen.map((r) => '${r.method} ${r.url.path}'), ['POST /api/devices', 'GET /api/sync']);

    // A second service over the same store must not register again.
    final api2 = ApiClient(baseUrl: 'https://guard.test', client: fakeServer(seen: seen));
    await SyncService(api: api2, store: SyncStore(dir), platform: 'android', tz: 'Europe/London', appVersion: '0.1.0').sync();
    expect(seen.where((r) => r.url.path == '/api/devices').length, 1);
    expect((await SyncStore(dir).credentials())?.deviceId, 'dev-1');
  });

  test('a failed sync returns the last good payload from the store', () async {
    final store = SyncStore(dir);
    await store.saveCredentials(deviceId: 'dev-1', token: 'tok-1');
    await store.save(SyncPayload.fromJson(serverSync, fetchedAt: DateTime.utc(2026, 10, 1, 5)));

    final api = ApiClient(baseUrl: 'https://guard.test', client: fakeServer(failSync: true));
    final payload = await SyncService(api: api, store: store, platform: 'ios', tz: 'UTC', appVersion: '0.1.0').sync();

    expect(payload, isNotNull);
    expect(payload!.fetchedAtUtc, DateTime.utc(2026, 10, 1, 5));
  });

  test('the store survives a torn write', () async {
    await File('${dir.path}/sync.json').writeAsString('{"serverTimeUtc": "2026-');
    expect(await SyncStore(dir).latest(), isNull);
  });

  test('the device engine computes windows from a synced payload', () {
    final state = GuardState(payload: SyncPayload.fromJson(serverSync));
    final windows = state.windows;

    expect(windows.length, 1);
    expect(windows.single.instrument, 'XAUUSD');
    expect(windows.single.opensAtUtc, '2026-10-01T08:55:00Z');
    expect(windows.single.closesAtUtc, '2026-10-01T09:05:00Z');
    expect(state.titleFor(windows.single.reasons.single), 'CPI Flash Estimate y/y');
  });
}
