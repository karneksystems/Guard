/// Where the trader stands against the next news window. One answer for the
/// in-app glow and the Lock Screen countdown, so they never disagree.
enum NewsPhase {
  /// Nothing within the lead time.
  clear,

  /// A window opens within the lead time. Amber.
  soon,

  /// A window is open. Red.
  live,
}

/// A window as the glow and the countdown see it. Times are UTC.
class NewsSpan {
  const NewsSpan({
    required this.windowId,
    required this.instrument,
    required this.events,
    required this.opens,
    required this.closes,
  });

  final String windowId;
  final String instrument;
  final String events;
  final DateTime opens;
  final DateTime closes;
}

class NewsNow {
  const NewsNow(this.phase, {this.span, this.nextChange});

  final NewsPhase phase;

  /// The window behind the phase. Null when clear.
  final NewsSpan? span;

  /// When the answer next changes, so callers can set one timer, not poll.
  final DateTime? nextChange;
}

/// Amber from [lead] before a window opens, red while it's open. A live window
/// beats a soon one; among live windows the one that closes last wins, so
/// "trading reopens at" is never too early.
NewsNow newsAt(Iterable<NewsSpan> spans, DateTime now, {Duration lead = const Duration(minutes: 5)}) {
  NewsSpan? live;
  NewsSpan? soon;
  DateTime? next;
  void consider(DateTime t) {
    if (t.isAfter(now) && (next == null || t.isBefore(next!))) next = t;
  }

  for (final s in spans) {
    final warnFrom = s.opens.subtract(lead);
    consider(warnFrom);
    consider(s.opens);
    consider(s.closes);
    if (!now.isBefore(s.opens) && now.isBefore(s.closes)) {
      if (live == null || s.closes.isAfter(live.closes)) live = s;
    } else if (!now.isBefore(warnFrom) && now.isBefore(s.opens)) {
      if (soon == null || s.opens.isBefore(soon.opens)) soon = s;
    }
  }
  if (live != null) return NewsNow(NewsPhase.live, span: live, nextChange: next);
  if (soon != null) return NewsNow(NewsPhase.soon, span: soon, nextChange: next);
  return NewsNow(NewsPhase.clear, nextChange: next);
}
