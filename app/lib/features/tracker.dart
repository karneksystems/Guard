/// The manual trackers from the free tier: daily-loss room, minimum trading
/// days, inactivity, weekend hold. All user-entered, all on the device. Nothing
/// here reads an account; the user types their P&L and we do the arithmetic.
class PnlEntry {
  const PnlEntry({required this.date, required this.amount, this.note});

  /// Local calendar date, YYYY-MM-DD.
  final String date;

  /// Positive is profit, negative is loss, in the account's currency.
  final double amount;
  final String? note;

  Map<String, dynamic> toJson() => {'date': date, 'amount': amount, if (note != null) 'note': note};

  factory PnlEntry.fromJson(Map<String, dynamic> j) => PnlEntry(
        date: j['date'] as String,
        amount: (j['amount'] as num).toDouble(),
        note: j['note'] as String?,
      );
}

class Tracker {
  const Tracker({
    this.currency = '\$',
    this.dailyLossLimit,
    this.entries = const [],
    this.minTradingDays = 0,
    this.startDate,
    this.inactivityDays = 30,
    this.weekendWarning = true,
  });

  final String currency;

  /// The firm's daily loss limit as a positive number. Null until the user sets it.
  final double? dailyLossLimit;

  /// Newest last. One or more per day.
  final List<PnlEntry> entries;

  /// Minimum trading days the firm wants. Zero means the countdown is off.
  final int minTradingDays;

  /// Local date the evaluation started, YYYY-MM-DD. Days before it don't count.
  final String? startDate;

  /// Days without a trade after which the firm may act. Zero switches the reminder off.
  final int inactivityDays;

  final bool weekendWarning;

  static String dateKey(DateTime local) =>
      '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';

  double pnlOn(String date) => entries.where((e) => e.date == date).fold(0.0, (s, e) => s + e.amount);

  /// How much of the daily limit is left today. Null when no limit is set.
  /// Profit doesn't add room: firms measure the loss from the day's start.
  double? roomLeft(String today) {
    final limit = dailyLossLimit;
    if (limit == null) return null;
    final pnl = pnlOn(today);
    final room = limit + (pnl < 0 ? pnl : 0);
    return room < 0 ? 0 : room;
  }

  /// Distinct dates with an entry on or after the start date.
  int tradedDays() {
    final start = startDate;
    return entries.map((e) => e.date).where((d) => start == null || d.compareTo(start) >= 0).toSet().length;
  }

  int get daysToGo => minTradingDays == 0 ? 0 : (minTradingDays - tradedDays()).clamp(0, minTradingDays);

  /// The most recent date with an entry, or the start date, or null.
  String? get lastActivityDate {
    if (entries.isEmpty) return startDate;
    var latest = entries.first.date;
    for (final e in entries) {
      if (e.date.compareTo(latest) > 0) latest = e.date;
    }
    return latest;
  }

  Tracker copyWith({
    String? currency,
    double? dailyLossLimit,
    bool clearDailyLossLimit = false,
    List<PnlEntry>? entries,
    int? minTradingDays,
    String? startDate,
    bool clearStartDate = false,
    int? inactivityDays,
    bool? weekendWarning,
  }) =>
      Tracker(
        currency: currency ?? this.currency,
        dailyLossLimit: clearDailyLossLimit ? null : (dailyLossLimit ?? this.dailyLossLimit),
        entries: entries ?? this.entries,
        minTradingDays: minTradingDays ?? this.minTradingDays,
        startDate: clearStartDate ? null : (startDate ?? this.startDate),
        inactivityDays: inactivityDays ?? this.inactivityDays,
        weekendWarning: weekendWarning ?? this.weekendWarning,
      );

  Tracker add(PnlEntry e) => copyWith(entries: [...entries, e]);

  /// Keeps the last 90 days so the prefs file stays small.
  Tracker prune(String today) {
    final cutoff = DateTime.parse(today).subtract(const Duration(days: 90));
    final keep = dateKey(cutoff);
    return copyWith(entries: entries.where((e) => e.date.compareTo(keep) >= 0).toList());
  }

  Map<String, dynamic> toJson() => {
        'currency': currency,
        'dailyLossLimit': dailyLossLimit,
        'entries': entries.map((e) => e.toJson()).toList(),
        'minTradingDays': minTradingDays,
        'startDate': startDate,
        'inactivityDays': inactivityDays,
        'weekendWarning': weekendWarning,
      };

  factory Tracker.fromJson(Map<String, dynamic> j) => Tracker(
        currency: j['currency'] as String? ?? '\$',
        dailyLossLimit: (j['dailyLossLimit'] as num?)?.toDouble(),
        entries: (j['entries'] as List? ?? const []).cast<Map<String, dynamic>>().map(PnlEntry.fromJson).toList(),
        minTradingDays: j['minTradingDays'] as int? ?? 0,
        startDate: j['startDate'] as String?,
        inactivityDays: j['inactivityDays'] as int? ?? 30,
        weekendWarning: j['weekendWarning'] as bool? ?? true,
      );
}
