import '../ui/words.dart';

/// What each alert says. docs/redesign/grok-final/COPY.md, Notifications:
/// local times, the same event name on every rung, no jargon.
/// backend/app/Push/RungMessage.php says the same for server pushes.
class RungWords {
  const RungWords(this.title, this.body, this.channel);

  final String title;
  final String body;

  /// ladder_urgent for t-1 and open, ladder for the rest.
  final String channel;

  /// [eventTitles] are short names ("EUR CPI"); [opensHhmm] and [closesHhmm]
  /// are local clock times ("8:55").
  static RungWords forRung({
    required String kind,
    required String instrument,
    required List<String> eventTitles,
    required String opensHhmm,
    required String closesHhmm,
  }) {
    final events = eventTitles.isEmpty ? 'High impact news' : eventTitles.take(2).join(', ');
    final market = marketName(instrument);
    final spoken = market == 'Gold' || market == 'Silver' || market == 'Oil' ? market.toLowerCase() : market;
    final channel = (kind == 't-1' || kind == 'open') ? 'ladder_urgent' : 'ladder';
    return switch (kind) {
      't-60' => RungWords('$market cover in 60 min', '$events. Stay flat from $opensHhmm to $closesHhmm.', channel),
      't-15' => RungWords('$market cover in 15 min', '$events. Be flat by $opensHhmm.', channel),
      't-5' => RungWords('$market cover in 5 min', '$events. Close or hold. Cover starts at $opensHhmm.', channel),
      't-1' => RungWords('One minute · $spoken', '$events. Hands off until $closesHhmm.', channel),
      'open' => RungWords('Cover is on · $spoken', '$events. Stay out until $closesHhmm.', channel),
      'end' => RungWords("You're clear · $spoken", 'Cover ended. Trade at your own pace.', channel),
      _ => RungWords(market, events, channel),
    };
  }
}
