import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guard_app/features/flags.dart';
import 'package:guard_app/notifications/ladder_mirror.dart';
import 'package:guard_app/notifications/notification_scheduler.dart';
import 'package:guard_app/packs/pack_cache.dart';
import 'package:guard_app/platform/platform_bridge.dart';
import 'package:guard_app/state/guard_controller.dart';
import 'package:guard_app/state/guard_state.dart';
import 'package:guard_app/sync/api_client.dart';
import 'package:guard_app/sync/sync_payload.dart';
import 'package:guard_app/sync/sync_service.dart';
import 'package:guard_app/sync/sync_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

SyncPayload payload({String opens = '2026-10-02T12:25:00Z', Map<String, dynamic> settings = const {}}) => SyncPayload.fromJson({
      'serverTimeUtc': '2026-10-02T06:00:00Z',
      'pro': false,
      'settings': <String, dynamic>{...settings},
      'instruments': [
        {'symbol': 'XAUUSD', 'basket': ['USD']},
      ],
      'events': [
        {'id': '7', 'currency': 'USD', 'title': 'NFP', 'impact': 'high', 'scheduledAtUtc': '2026-10-02T12:30:00Z'},
      ],
      'windows': [
        {'windowId': 'w' * 20, 'instrument': 'XAUUSD', 'opensAtUtc': opens, 'closesAtUtc': '2026-10-02T12:35:00Z', 'reasons': ['7'], 'verified': true},
      ],
      'ladder': [
        {'alertId': 'a5'.padRight(20, '0'), 'windowId': 'w' * 20, 'kind': 'open', 'fireAtUtc': opens},
      ],
    });

void main() {
  final id = notificationIdFor('a5'.padRight(20, '0'));

  test('a reconcile inside the grace after fire time keeps the mirror', () async {
    final scheduler = FakeScheduler();
    final mirror = LadderMirror(scheduler);
    await mirror.reconcile(payload(), now: DateTime.utc(2026, 10, 2, 6));
    expect(scheduler.pending.containsKey(id), isTrue);
    await mirror.reconcile(payload(), now: DateTime.utc(2026, 10, 2, 12, 25, 10));
    expect(scheduler.pending.containsKey(id), isTrue, reason: 'ten seconds after fire, mirror still due');
    await mirror.reconcile(payload(), now: DateTime.utc(2026, 10, 2, 12, 25, 30));
    expect(scheduler.pending.containsKey(id), isFalse, reason: 'past fire plus grace');
  });

  test('a snoozed rung survives a reconcile and the push arriving', () async {
    final scheduler = FakeScheduler();
    final mirror = LadderMirror(scheduler);
    final now = DateTime.utc(2026, 10, 2, 12, 26);
    await mirror.reconcile(payload(), now: now);
    await mirror.snooze(payload(), 'a5'.padRight(20, '0'), now: now);
    expect(scheduler.pending[id]!.atUtc, DateTime.utc(2026, 10, 2, 12, 27));
    await mirror.reconcile(payload(), now: now.add(const Duration(seconds: 10)));
    expect(scheduler.pending[id]!.atUtc, DateTime.utc(2026, 10, 2, 12, 27), reason: 'reconcile leaves it');
    await mirror.pushArrived('a5'.padRight(20, '0'));
    expect(scheduler.pending.containsKey(id), isTrue, reason: 'the push does not cancel a snooze');
    await mirror.reconcile(payload(), now: DateTime.utc(2026, 10, 2, 12, 28));
    expect(scheduler.pending.containsKey(id), isFalse, reason: 'fired, gone');
  });

  test('a failed settings PUT stays pending across payloads and is retried on the next sync', () async {
    var settingsDown = true;
    final puts = <String>[];
    final client = MockClient((r) async {
      if (r.url.path == '/api/devices') return http.Response(jsonEncode({'deviceId': 'd', 'token': 't'}), 201);
      if (r.url.path == '/api/sync') return http.Response(jsonEncode(payload(settings: {'protection': 'soft-gate'}).toJson()), 200);
      if (r.url.path == '/api/settings') {
        puts.add(r.body);
        return settingsDown ? http.Response('down', 503) : http.Response('{"ok":true}', 200);
      }
      return http.Response('{"ok":true}', 200);
    });
    final api = ApiClient(baseUrl: 'https://guard.test', client: client);
    final store = MemoryStore();
    final c = GuardController(
      state: GuardState(onboarded: true),
      bridge: FakeBridge(supported: const {}),
      api: api,
      store: store,
      sync: SyncService(api: api, store: store, platform: 'android', tz: 'UTC', appVersion: '0'),
      now: () => DateTime.utc(2026, 10, 2, 6),
    );
    await c.start();
    await c.updateSettings({'protection': 'warn-only'});
    expect(c.state.settings['protection'], 'warn-only');
    expect(puts.length, 1);

    await c.applyPayload(payload(settings: {'protection': 'soft-gate'}));
    expect(c.state.settings['protection'], 'warn-only', reason: 'the edit stays on top until the server has it');

    settingsDown = false;
    await c.resync();
    expect(puts.length, 2, reason: 'retried');
    await c.applyPayload(payload(settings: {'protection': 'warn-only'}));
    expect(c.state.settings['protection'], 'warn-only');
  });

  test('a clock behind the last fetch gets no Pro', () {
    final fetched = DateTime.utc(2026, 10, 2, 6);
    expect(Flags.derive(serverPro: true, proUntil: DateTime.utc(2026, 11, 1), fetchedAt: fetched, now: fetched.add(const Duration(hours: 1))).pro, isTrue);
    expect(Flags.derive(serverPro: true, proUntil: DateTime.utc(2026, 11, 1), fetchedAt: fetched, now: fetched.subtract(const Duration(days: 1))).pro, isFalse);
  });

  test('an index that re-flags a pack as unverified widens the window without a version bump', () {
    final pack = {
      'firmId': 'acme', 'firmName': 'Acme', 'packVersion': '1', 'needsReverify': false, 'lastVerified': '2026-09-01',
      'accountTypes': [
        {'id': 'funded', 'label': 'Funded', 'phase': 'funded', 'newsRule': {'applies': true, 'windowBeforeMin': 2, 'windowAfterMin': 2, 'eventSet': 'calendar-high-impact', 'affectedInstruments': 'event-currency'}},
      ],
      'changelog': [],
    };
    final state = GuardState(onboarded: true, now: () => DateTime.utc(2026, 10, 2, 6));
    state.update(SyncPayload.fromJson({
      ...payload().toJson(),
      'pro': true,
      'settings': {'mode': 'firm-match', 'firm_id': 'acme', 'account_type_id': 'funded'},
    }, fetchedAt: DateTime.utc(2026, 10, 2, 6)));
    final verified = PackIndexEntry.fromJson({'firmId': 'acme', 'firmName': 'Acme', 'packVersion': '1', 'needsReverify': false, 'lastVerified': '2026-09-01', 'accountTypes': []});
    state.setPacks(PackCache(index: {'acme': verified}, packs: {'acme': pack}));
    expect(state.windows.single.opensAtUtc, '2026-10-02T12:28:00Z');
    expect(state.windows.single.verified, isTrue);

    final reflagged = PackIndexEntry.fromJson({'firmId': 'acme', 'firmName': 'Acme', 'packVersion': '1', 'needsReverify': true, 'lastVerified': null, 'accountTypes': []});
    state.setPacks(PackCache(index: {'acme': reflagged}, packs: {'acme': pack}));
    expect(state.windows.single.opensAtUtc, '2026-10-02T12:25:00Z', reason: 'larger of pack 2 and default 5');
    expect(state.windows.single.verified, isFalse);
  });
}
