/// docs/FREE-PRO-FLAGS.md as code. One boolean from the server, pro_until, and
/// everything derives from it. The device keeps Pro for seven days past
/// pro_until when it can't reach the server, so an outage never drops a paying
/// user's presets mid-week.
class Flags {
  const Flags._(this.pro);

  final bool pro;

  static const free = Flags._(false);
  static const proFlags = Flags._(true);

  static const Duration grace = Duration(days: 7);
  static const Duration fresh = Duration(hours: 24);

  /// [serverPro] is the server's word as of [fetchedAt]. Fresh word wins; a
  /// stale one is trusted only while pro_until plus the grace hasn't passed.
  factory Flags.derive({
    required bool serverPro,
    required DateTime? proUntil,
    required DateTime? fetchedAt,
    required DateTime now,
  }) {
    if (fetchedAt != null && now.difference(fetchedAt) <= fresh) {
      return serverPro ? proFlags : free;
    }
    if (proUntil != null && now.isBefore(proUntil.add(grace))) return proFlags;
    return free;
  }

  bool get firmMatch => pro;
  int get instrumentsMax => pro ? 50 : 2;
  bool get customWindows => pro;
  bool get hardBlock => pro;
  int? get journalDays => pro ? null : 7;
  bool get journalStreak => pro;
  bool get ads => !pro;
  bool get rulesChangedFlag => pro;
  bool get changelog => pro;

  /// The window presets Pro can pick from, in minutes.
  static const List<int> windowPresets = [2, 3, 5, 10];
}
