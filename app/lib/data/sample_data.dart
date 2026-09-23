import 'package:rule_engine/rule_engine.dart';

/// Stand-in for the synced local store until M1's sync client lands. Same events
/// as backend/resources/fixtures/fake-calendar.json, so device and server agree.
abstract final class SampleData {
  static const String userId = 'sample';

  static const Map<String, dynamic> settings = {
    'mode': 'conservative',
    'windowBeforeMin': 5,
    'windowAfterMin': 5,
  };

  static const List<Map<String, dynamic>> instruments = [
    {'symbol': 'XAUUSD', 'basket': ['USD', 'EUR', 'GBP']},
    {'symbol': 'EURUSD'},
  ];

  static const List<Map<String, dynamic>> events = [
    {'id': 'cpi-eu-2026-10-01', 'currency': 'EUR', 'title': 'CPI Flash Estimate y/y', 'impact': 'high', 'scheduledAtUtc': '2026-10-01T09:00:00Z'},
    {'id': 'boe-2026-10-01', 'currency': 'GBP', 'title': 'BoE Official Bank Rate', 'impact': 'high', 'scheduledAtUtc': '2026-10-01T11:00:00Z'},
    {'id': 'pmi-2026-10-01', 'currency': 'USD', 'title': 'Chicago PMI', 'impact': 'medium', 'scheduledAtUtc': '2026-10-01T13:45:00Z'},
    {'id': 'nfp-2026-10-02', 'currency': 'USD', 'title': 'Non-Farm Employment Change', 'impact': 'high', 'scheduledAtUtc': '2026-10-02T12:30:00Z'},
    {'id': 'opec-2026-10-05', 'currency': 'USD', 'title': 'OPEC-JMMC Meetings', 'impact': 'high', 'scheduledAtUtc': '2026-10-05T00:00:00Z', 'tentative': true},
  ];

  static Map<String, dynamic> engineInput() => {
        'userId': userId,
        'settings': settings,
        'instruments': instruments,
        'events': events,
      };

  static String titleFor(String eventId) =>
      events.firstWhere((e) => e['id'] == eventId, orElse: () => const {'title': 'Event'})['title'] as String;

  static WindowsResult windows() => RuleEngine((_) => throw StateError('no packs in sample data')).computeWindows(engineInput());
}
