/// What GET /api/sync returns. Kept as plain maps where the engine consumes
/// them, so the device engine gets exactly the shape the server engine saw.
class SyncPayload {
  SyncPayload({
    required this.serverTimeUtc,
    required this.pro,
    required this.settings,
    required this.instruments,
    required this.events,
    required this.windows,
    required this.ladder,
    required this.fetchedAtUtc,
  });

  factory SyncPayload.fromJson(Map<String, dynamic> json, {DateTime? fetchedAt}) {
    final settings = (json['settings'] as Map<String, dynamic>?) ?? const {};
    return SyncPayload(
      serverTimeUtc: json['serverTimeUtc'] as String,
      pro: json['pro'] == true,
      settings: {
        'mode': settings['mode'] ?? 'conservative',
        'protection': settings['protection'] ?? 'soft-gate',
        'windowBeforeMin': settings['window_before_min'] ?? 5,
        'windowAfterMin': settings['window_after_min'] ?? 5,
        'firmId': settings['firm_id'],
        'accountTypeId': settings['account_type_id'],
        'digestLocalTime': settings['digest_local_time'] ?? '20:00',
      },
      instruments: (json['instruments'] as List? ?? const []).cast<Map<String, dynamic>>(),
      events: (json['events'] as List? ?? const []).cast<Map<String, dynamic>>(),
      windows: (json['windows'] as List? ?? const []).cast<Map<String, dynamic>>(),
      ladder: (json['ladder'] as List? ?? const []).cast<Map<String, dynamic>>(),
      fetchedAtUtc: (fetchedAt ?? DateTime.now()).toUtc(),
    );
  }

  final String serverTimeUtc;
  final bool pro;
  final Map<String, dynamic> settings;
  final List<Map<String, dynamic>> instruments;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> windows;
  final List<Map<String, dynamic>> ladder;
  final DateTime fetchedAtUtc;

  /// The engine's input, built from this payload for the given user id.
  Map<String, dynamic> engineInput(String userId) => {
        'userId': userId,
        'settings': {
          'mode': settings['mode'],
          'windowBeforeMin': settings['windowBeforeMin'],
          'windowAfterMin': settings['windowAfterMin'],
        },
        'instruments': instruments,
        'events': events,
        if (settings['mode'] == 'firm-match' && settings['firmId'] != null) ...{
          'packId': settings['firmId'],
          'accountTypeId': settings['accountTypeId'],
        },
      };

  Map<String, dynamic> toJson() => {
        'serverTimeUtc': serverTimeUtc,
        'pro': pro,
        'settings': {
          'mode': settings['mode'],
          'protection': settings['protection'],
          'window_before_min': settings['windowBeforeMin'],
          'window_after_min': settings['windowAfterMin'],
          'firm_id': settings['firmId'],
          'account_type_id': settings['accountTypeId'],
          'digest_local_time': settings['digestLocalTime'],
        },
        'instruments': instruments,
        'events': events,
        'windows': windows,
        'ladder': ladder,
        'fetchedAtUtc': fetchedAtUtc.toIso8601String(),
      };

  String titleFor(String eventId) {
    for (final e in events) {
      if (e['id'] == eventId) return e['title'] as String;
    }
    return 'Event';
  }
}
