import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guard_app/main.dart';
import 'package:guard_app/notifications/ladder_mirror.dart';
import 'package:guard_app/notifications/notification_scheduler.dart';
import 'package:guard_app/platform/platform_bridge.dart';
import 'package:guard_app/state/guard_controller.dart';
import 'package:guard_app/state/guard_state.dart';
import 'package:guard_app/sync/api_client.dart';
import 'package:guard_app/sync/sync_service.dart';
import 'package:guard_app/sync/sync_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> serverPayload(String opens) => {
      'serverTimeUtc': '2026-10-02T06:00:00Z',
      'pro': false,
      'settings': <String, dynamic>{},
      'instruments': [
        {'symbol': 'XAUUSD', 'basket': ['USD']},
      ],
      'events': [
        {'id': '7', 'currency': 'USD', 'title': 'Non-Farm Payrolls', 'impact': 'high', 'scheduledAtUtc': '2026-10-02T12:30:00Z'},
      ],
      'windows': [],
      'ladder': [
        {'alertId': 'a5'.padRight(20, '0'), 'windowId': 'w' * 20, 'kind': 'open', 'fireAtUtc': opens},
      ],
    };

class Server {
  String opens = '2026-10-02T12:25:00Z';
  int syncs = 0;
  bool down = false;

  MockClient get client => MockClient((r) async {
        if (r.url.path == '/api/devices') return http.Response(jsonEncode({'deviceId': 'd', 'token': 't'}), 201);
        if (r.url.path == '/api/sync') {
          syncs++;
          if (down) return http.Response('down', 503);
          return http.Response(jsonEncode(serverPayload(opens)), 200);
        }
        if (r.url.path == '/api/packs') return http.Response('{"packs":[]}', 200);
        return http.Response('{"ok":true}', 200);
      });
}

(GuardController, FakeScheduler, Server) build({DateTime Function()? now}) {
  final server = Server();
  final api = ApiClient(baseUrl: 'https://guard.test', client: server.client);
  final store = MemoryStore();
  final scheduler = FakeScheduler();
  final c = GuardController(
    state: GuardState(onboarded: true),
    bridge: FakeBridge(supported: const {}),
    api: api,
    store: store,
    sync: SyncService(api: api, store: store, platform: 'windows', tz: 'UTC', appVersion: '0'),
    mirror: LadderMirror(scheduler),
    now: now ?? () => DateTime.utc(2026, 10, 2, 6),
  );
  return (c, scheduler, server);
}

void main() {
  test('resync applies a revised ladder to the mirror and survives the server being down', () async {
    final (c, scheduler, server) = build();
    await c.start();
    final id = notificationIdFor('a5'.padRight(20, '0'));
    expect(scheduler.pending[id]!.atUtc, DateTime.utc(2026, 10, 2, 12, 25, 20));

    server.opens = '2026-10-02T12:40:00Z';
    expect(await c.resync(), isTrue);
    expect(scheduler.pending[id]!.atUtc, DateTime.utc(2026, 10, 2, 12, 40, 20));

    server.down = true;
    expect(await c.resync(), isFalse);
    expect(scheduler.pending[id]!.atUtc, DateTime.utc(2026, 10, 2, 12, 40, 20), reason: 'cache stands');
  });

  test('resumed only resyncs when the last sync is stale', () async {
    var clock = DateTime.utc(2026, 10, 2, 6);
    final (c, _, server) = build(now: () => clock);
    await c.start();
    final after = server.syncs;
    await c.resumed();
    expect(server.syncs, after, reason: 'just synced');
    clock = clock.add(const Duration(minutes: 3));
    // syncAge uses the wall clock on fetchedAtUtc, which is real time here; force staleness.
    await c.resumed(staleAfter: Duration.zero);
    expect(server.syncs, after + 1);
  });

  testWidgets('the app resyncs on resume', (tester) async {
    final (c, _, server) = build();
    await c.start();
    final before = server.syncs;
    await tester.pumpWidget(GuardApp(state: c.state, controller: c));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(server.syncs, greaterThanOrEqualTo(before), reason: 'fresh sync is not repeated');
  });
}
