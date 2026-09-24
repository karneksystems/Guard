/// What GET /api/sync returns. Kept as plain maps where the engine consumes
/// them, so the device engine gets exactly the shape the server engine saw.
class SyncPayload {
  SyncPayload({
    required this.serverTimeUtc,
    this.userId,
    this.calendarFetchedAtUtc,
    required this.pro,
    this.proUntil,
    required this.settings,
    required this.instruments,
    required this.events,
    required this.windows,
    required this.ladder,
    this.firmEventIds = const [],
    required this.fetchedAtUtc,
  });

  factory SyncPayload.fromJson(Map<String, dynamic> json, {DateTime? fetchedAt}) {
    final settings = (json['settings'] as Map<String, dynamic>?) ?? const {};
    return SyncPayload(
      serverTimeUtc: json['serverTimeUtc'] as String,
      userId: json['userId'] as String?,
      calendarFetchedAtUtc: json['calendarFetchedAt'] == null ? null : DateTime.tryParse(json['calendarFetchedAt'] as String)?.toUtc(),
      pro: json['pro'] == true,
      proUntil: json['proUntil'] == null ? null : DateTime.tryParse(json['proUntil'] as String)?.toUtc(),
      settings: {
        'mode': settings['mode'] ?? 'conservative',
        'protection': settings['protection'] ?? 'soft-gate',
        'windowBeforeMin': settings['window_before_min'] ?? 5,
        'windowAfterMin': settings['window_after_min'] ?? 5,
        'firmId': settings['firm_id'],
        'accountTypeId': settings['account_type_id'],
        'digestLocalTime': settings['digest_local_time'] ?? '20:00',
        'quietHours': (settings['quiet_hours'] as Map?)?.cast<String, dynamic>(),
      },
      instruments: (json['instruments'] as List? ?? const []).cast<Map<String, dynamic>>(),
      events: (json['events'] as List? ?? const []).cast<Map<String, dynamic>>(),
      windows: (json['windows'] as List? ?? const []).cast<Map<String, dynamic>>(),
      ladder: (json['ladder'] as List? ?? const []).cast<Map<String, dynamic>>(),
      firmEventIds: (json['firmEventIds'] as List? ?? const []).map((e) => e.toString()).toList(),
      fetchedAtUtc: (fetchedAt ?? DateTime.now()).toUtc(),
    );
  }

  final String serverTimeUtc;

  /// The server's user id. The device engine hashes window ids with it, so a
  /// window computed here has the same id as the server's and the journal
  /// links up. Null before the first sync.
  final String? userId;

  /// When the server last heard from the calendar vendor. Null before the first sync.
  final DateTime? calendarFetchedAtUtc;
  final bool pro;
  final DateTime? proUntil;
  final Map<String, dynamic> settings;
  final List<Map<String, dynamic>> instruments;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> windows;
  final List<Map<String, dynamic>> ladder;

  /// The firm's own restricted-event ids, matched server-side, so Firm match
  /// on the device selects the same events as the server.
  final List<String> firmEventIds;
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
          if (firmEventIds.isNotEmpty) 'firmEventIds': firmEventIds,
        },
      };

  Map<String, dynamic> toJson() => {
        'serverTimeUtc': serverTimeUtc,
        'userId': userId,
        'calendarFetchedAt': calendarFetchedAtUtc?.toIso8601String(),
        'pro': pro,
        'proUntil': proUntil?.toIso8601String(),
        'settings': {
          'mode': settings['mode'],
          'protection': settings['protection'],
          'window_before_min': settings['windowBeforeMin'],
          'window_after_min': settings['windowAfterMin'],
          'firm_id': settings['firmId'],
          'account_type_id': settings['accountTypeId'],
          'digest_local_time': settings['digestLocalTime'],
          'quiet_hours': settings['quietHours'],
        },
        'instruments': instruments,
        'events': events,
        'windows': windows,
        'ladder': ladder,
        'firmEventIds': firmEventIds,
        'fetchedAtUtc': fetchedAtUtc.toIso8601String(),
      };

  String titleFor(String eventId) {
    for (final e in events) {
      if (e['id'] == eventId) return e['title'] as String;
    }
    return 'Event';
  }
}
