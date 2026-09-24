import 'package:flutter_test/flutter_test.dart';
import 'package:guard_app/state/guard_state.dart';
import 'package:guard_app/sync/sync_payload.dart';
import 'package:rule_engine/rule_engine.dart';

void main() {
  test('device windows carry the server user id, so ids match the server and the journal links', () {
    final json = {
      'serverTimeUtc': '2026-10-02T06:00:00Z',
      'userId': '42',
      'pro': false,
      'settings': <String, dynamic>{},
      'instruments': [
        {'symbol': 'XAUUSD', 'basket': ['USD']},
      ],
      'events': [
        {'id': '7', 'currency': 'USD', 'title': 'NFP', 'impact': 'high', 'scheduledAtUtc': '2026-10-02T12:30:00Z'},
      ],
      'windows': [],
      'ladder': [],
    };
    final state = GuardState(onboarded: true)..update(SyncPayload.fromJson(json));
    final server = RuleEngine((_) => throw StateError('no packs')).computeWindows({
      'userId': '42',
      'settings': {'mode': 'conservative', 'windowBeforeMin': 5, 'windowAfterMin': 5},
      'instruments': json['instruments'],
      'events': json['events'],
    });
    expect(state.windows.single.windowId, server.windows.single.windowId);

    final anonymous = GuardState(onboarded: true)..update(SyncPayload.fromJson({...json}..remove('userId')));
    expect(anonymous.windows.single.windowId, isNot(server.windows.single.windowId), reason: 'falls back to the device id before the first sync');
  });
}
