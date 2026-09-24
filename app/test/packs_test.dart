import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guard_app/billing/billing.dart';
import 'package:guard_app/main.dart';
import 'package:guard_app/packs/pack_cache.dart';
import 'package:guard_app/platform/platform_bridge.dart';
import 'package:guard_app/screens/paywall_screen.dart';
import 'package:guard_app/state/guard_controller.dart';
import 'package:guard_app/state/guard_state.dart';
import 'package:guard_app/sync/api_client.dart';
import 'package:guard_app/sync/sync_service.dart';
import 'package:guard_app/sync/sync_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> pack({String version = '2026.09.01', bool verified = true, int minutes = 10}) => {
      'schemaVersion': 1,
      'firmId': 'acme',
      'firmName': 'Acme Funding',
      'packVersion': version,
      'sourceUrl': 'https://acme.example/rules',
      'sourceFetchedAt': verified ? '2026-09-01T00:00:00Z' : null,
      'lastVerified': verified ? '2026-09-01' : null,
      'verifiedBy': verified ? 'js' : null,
      'needsReverify': !verified,
      'investorPasswordAllowed': 'unknown',
      'accountTypes': [
        {
          'id': 'funded',
          'label': 'Funded',
          'phase': 'funded',
          'newsRule': {
            'applies': true,
            'windowBeforeMin': minutes,
            'windowAfterMin': minutes,
            'eventSet': 'calendar-high-impact',
            'affectedInstruments': 'event-currency',
            'restrictedActions': ['open', 'close'],
            'slTpTriggerCounts': true,
            'consequence': 'breach',
          },
        },
      ],
      'changelog': [
        {'packVersion': '2026.09.01', 'date': '2026-09-01', 'change': 'First verified read.'},
        if (version == '2026.10.01') {'packVersion': '2026.10.01', 'date': '2026-10-01', 'change': 'Window widened to 10 minutes.'},
      ],
    };

class Server {
  Server({this.pro = false, this.packVersion = '2026.09.01', this.packMinutes = 10});

  bool pro;
  String packVersion;
  int packMinutes;
  String mode = 'conservative';
  String? firmId;
  String? accountTypeId;
  final List<http.Request> seen = [];

  Map<String, dynamic> get sync => {
        'serverTimeUtc': '2026-10-01T06:00:00Z',
        'pro': pro,
        'proUntil': pro ? '2026-11-01T00:00:00Z' : null,
        'settings': {'mode': mode, 'protection': 'soft-gate', 'window_before_min': 5, 'window_after_min': 5, 'firm_id': firmId, 'account_type_id': accountTypeId, 'digest_local_time': '20:00'},
        'instruments': [
          {'symbol': 'XAUUSD', 'basket': ['USD', 'EUR', 'GBP']},
        ],
        'events': [
          {'id': '1', 'currency': 'EUR', 'title': 'CPI Flash Estimate y/y', 'impact': 'high', 'scheduledAtUtc': '2026-10-01T09:00:00Z', 'tentative': false, 'source': 'fake', 'fetchedAt': '2026-09-30T20:00:00Z'},
        ],
        'windows': [],
        'ladder': [],
      };

  MockClient get client => MockClient((request) async {
        seen.add(request);
        final path = request.url.path;
        if (request.method == 'POST' && path == '/api/devices') {
          return http.Response(jsonEncode({'deviceId': 'dev-1', 'token': 'tok-1'}), 201);
        }
        if (path == '/api/packs') {
          final p = pack(version: packVersion, minutes: packMinutes);
          return http.Response(jsonEncode({'packs': [
            {'firmId': 'acme', 'firmName': p['firmName'], 'packVersion': p['packVersion'], 'needsReverify': p['needsReverify'], 'lastVerified': p['lastVerified'], 'accountTypes': [
              {'id': 'funded', 'label': 'Funded', 'phase': 'funded'},
            ]},
          ]}), 200);
        }
        if (path == '/api/packs/acme') return http.Response(jsonEncode(pack(version: packVersion, minutes: packMinutes)), 200);
        if (request.headers['Authorization'] != 'Bearer tok-1') return http.Response('{"error":"unauthenticated"}', 401);
        if (request.method == 'GET' && path == '/api/sync') return http.Response(jsonEncode(sync), 200);
        if (request.method == 'PUT' && path == '/api/settings') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (pro) {
            mode = body['mode'] as String? ?? mode;
            firmId = body['firm_id'] as String? ?? firmId;
            accountTypeId = body['account_type_id'] as String? ?? accountTypeId;
          }
          return http.Response('{"ok":true}', 200);
        }
        if (request.method == 'POST' && path == '/api/entitlement') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['platform'] == 'fake' && body['receipt'] == 'fake:${body['plan']}') {
            pro = true;
            return http.Response('{"ok":true,"proUntil":"2026-11-01T00:00:00Z"}', 200);
          }
          return http.Response('{"ok":false,"proUntil":null}', 402);
        }
        return http.Response('{"ok":true}', 200);
      });
}

class Harness {
  Harness(this.server, {bool pro = false}) {
    store = MemoryStore();
    api = ApiClient(baseUrl: 'https://guard.test', client: server.client);
    state = GuardState(onboarded: true, now: () => DateTime.utc(2026, 10, 1, 6, 30));
    controller = GuardController(
      state: state,
      bridge: FakeBridge(supported: const {}),
      api: api,
      store: store,
      sync: SyncService(api: api, store: store, platform: 'android', tz: 'UTC', appVersion: '0.1.0'),
      billing: FakeBilling(),
      now: () => DateTime.utc(2026, 10, 1, 6, 30),
    );
  }

  final Server server;
  late final MemoryStore store;
  late final ApiClient api;
  late final GuardState state;
  late final GuardController controller;
}

void main() {
  test('PackCache.put reports a version change with the newer changelog entries', () {
    final cache = PackCache();
    expect(cache.put(pack()), isNull);
    final changed = cache.put(pack(version: '2026.10.01'))!;
    expect(changed.from, '2026.09.01');
    expect(changed.to, '2026.10.01');
    expect(changed.changes.single['change'], 'Window widened to 10 minutes.');
    expect(cache.put(pack(version: '2026.10.01')), isNull);
    final back = PackCache.fromJson(cache.toJson());
    expect(back.packs['acme']!['packVersion'], '2026.10.01');
  });

  test('start syncs, caches the pack index, and Firm match on a Pro user runs the pack on the device', () async {
    final server = Server(pro: true)
      ..mode = 'firm-match'
      ..firmId = 'acme'
      ..accountTypeId = 'funded';
    final h = Harness(server);
    await h.controller.start();

    expect(h.state.pro, isTrue);
    expect(h.state.packs.index.keys, ['acme']);
    expect(h.state.packs.packs['acme']!['packVersion'], '2026.09.01');
    expect((await h.store.prefs())['packs'], isNotNull, reason: 'cached for offline');

    // Verified pack, 10 minutes each side: the window is 08:50 to 09:10, not 08:55 to 09:05.
    final w = h.state.windows.single;
    expect(w.opensAtUtc, '2026-10-01T08:50:00Z');
    expect(w.closesAtUtc, '2026-10-01T09:10:00Z');
    expect(w.verified, isTrue);
    expect(h.state.engineNotes, isEmpty);
  });

  test('a Free user asking for Firm match stays conservative and the note says why', () async {
    final server = Server(pro: false)
      ..mode = 'firm-match'
      ..firmId = 'acme'
      ..accountTypeId = 'funded';
    final h = Harness(server);
    await h.controller.start();
    final w = h.state.windows.single;
    expect(w.opensAtUtc, '2026-10-01T08:55:00Z');
    expect(h.state.engineNotes, ['Firm match needs Pro: using conservative']);
  });

  test('an unverified pack uses the larger of its window and the default, and the window is marked unverified', () async {
    final server = Server(pro: true, packMinutes: 2)
      ..mode = 'firm-match'
      ..firmId = 'acme'
      ..accountTypeId = 'funded';
    final h = Harness(server);
    await h.controller.start();
    // Flip the cached pack to unverified without a new version.
    final cache = PackCache(index: {...h.state.packs.index}, packs: {'acme': pack(verified: false, minutes: 2)});
    h.state.setPacks(cache);
    final w = h.state.windows.single;
    expect(w.opensAtUtc, '2026-10-01T08:55:00Z', reason: '2 min pack vs 5 min default: 5 wins');
    expect(w.verified, isFalse);
    expect(h.state.engineNotes, contains(startsWith('pack unverified')));
  });

  test('a new pack version on the next refresh raises the rules-changed flag', () async {
    final server = Server(pro: true)
      ..mode = 'firm-match'
      ..firmId = 'acme'
      ..accountTypeId = 'funded';
    final h = Harness(server);
    await h.controller.start();
    expect(h.state.rulesChanged, isNull);

    server.packVersion = '2026.10.01';
    await h.controller.refreshPacks();
    expect(h.state.rulesChanged!.to, '2026.10.01');
    expect(h.state.rulesChanged!.changes.single['change'], 'Window widened to 10 minutes.');
    h.state.clearRulesChanged();
    expect(h.state.rulesChanged, isNull);
  });

  test('selectFirm writes the settings in snake_case and fetches the pack', () async {
    final server = Server(pro: true);
    final h = Harness(server);
    await h.controller.start();
    await h.controller.selectFirm(firmId: 'acme', accountTypeId: 'funded');
    final put = server.seen.lastWhere((r) => r.method == 'PUT' && r.url.path == '/api/settings');
    expect(jsonDecode(put.body), {'mode': 'firm-match', 'firm_id': 'acme', 'account_type_id': 'funded'});
    expect(h.state.packs.packs['acme'], isNotNull);
    expect(h.state.windows.single.opensAtUtc, '2026-10-01T08:50:00Z');
  });

  testWidgets('the paywall buys through the store, the server verifies, and Pro switches on', (tester) async {
    final server = Server(pro: false);
    final h = Harness(server);
    await h.controller.start();
    expect(h.state.pro, isFalse);

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GuardApp(state: h.state, controller: h.controller, home: const PaywallScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('paywall-yearly')));
    await tester.pumpAndSettle();

    final ent = server.seen.singleWhere((r) => r.url.path == '/api/entitlement');
    expect(jsonDecode(ent.body), {'platform': 'fake', 'plan': 'yearly', 'receipt': 'fake:yearly'});
    expect(h.state.pro, isTrue);
  });

  test('a cancelled purchase never touches the server', () async {
    final server = Server(pro: false);
    final h = Harness(server);
    final c = GuardController(state: h.state, bridge: FakeBridge(supported: const {}), api: h.api, store: h.store, billing: FakeBilling(cancel: true));
    await h.controller.start();
    expect(await c.upgrade(Plan.monthly), isFalse);
    expect(server.seen.where((r) => r.url.path == '/api/entitlement'), isEmpty);
  });
}
