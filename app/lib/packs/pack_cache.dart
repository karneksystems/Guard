/// Firm packs on the device. The index (every firm, its version, verified or
/// not) is small and always cached. Full packs are fetched for the firm the user
/// picked, so the engine can run Firm match offline. A version change on the
/// user's pack raises the rules-changed flag (Pro, docs/FREE-PRO-FLAGS.md).
class PackIndexEntry {
  const PackIndexEntry({
    required this.firmId,
    required this.firmName,
    required this.packVersion,
    required this.needsReverify,
    required this.lastVerified,
    required this.accountTypes,
  });

  final String firmId;
  final String firmName;
  final String packVersion;
  final bool needsReverify;
  final String? lastVerified;

  /// (id, label, phase)
  final List<({String id, String label, String phase})> accountTypes;

  factory PackIndexEntry.fromJson(Map<String, dynamic> j) => PackIndexEntry(
        firmId: j['firmId'] as String,
        firmName: j['firmName'] as String,
        packVersion: j['packVersion'] as String,
        needsReverify: j['needsReverify'] == true,
        lastVerified: j['lastVerified'] as String?,
        accountTypes: [
          for (final a in (j['accountTypes'] as List? ?? const []).cast<Map<String, dynamic>>())
            (id: a['id'] as String, label: a['label'] as String, phase: a['phase'] as String? ?? 'funded'),
        ],
      );

  Map<String, dynamic> toJson() => {
        'firmId': firmId,
        'firmName': firmName,
        'packVersion': packVersion,
        'needsReverify': needsReverify,
        'lastVerified': lastVerified,
        'accountTypes': [for (final a in accountTypes) {'id': a.id, 'label': a.label, 'phase': a.phase}],
      };
}

/// What changed when the user's pack moved to a new version.
class RulesChanged {
  const RulesChanged({required this.firmId, required this.from, required this.to, required this.changes});

  final String firmId;
  final String from;
  final String to;

  /// Changelog entries newer than [from], newest first.
  final List<Map<String, dynamic>> changes;
}

class PackCache {
  PackCache({Map<String, PackIndexEntry>? index, Map<String, Map<String, dynamic>>? packs})
      : index = index ?? {},
        packs = packs ?? {};

  final Map<String, PackIndexEntry> index;
  final Map<String, Map<String, dynamic>> packs;

  bool get isEmpty => index.isEmpty && packs.isEmpty;

  Map<String, dynamic> toJson() => {
        'index': {for (final e in index.entries) e.key: e.value.toJson()},
        'packs': packs,
      };

  factory PackCache.fromJson(Map<String, dynamic> j) => PackCache(
        index: {
          for (final e in ((j['index'] as Map?) ?? const {}).entries)
            e.key as String: PackIndexEntry.fromJson((e.value as Map).cast<String, dynamic>()),
        },
        packs: {
          for (final e in ((j['packs'] as Map?) ?? const {}).entries) e.key as String: (e.value as Map).cast<String, dynamic>(),
        },
      );

  /// Store a freshly fetched pack. Returns the change when a cached version was replaced.
  RulesChanged? put(Map<String, dynamic> pack) {
    final id = pack['firmId'] as String;
    final old = packs[id];
    packs[id] = pack;
    final from = old?['packVersion'] as String?;
    final to = pack['packVersion'] as String;
    if (from == null || from == to) return null;
    final log = (pack['changelog'] as List? ?? const []).cast<Map<String, dynamic>>();
    final changes = log.where((c) => (c['packVersion'] as String).compareTo(from) > 0).toList()
      ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return RulesChanged(firmId: id, from: from, to: to, changes: changes);
  }
}
