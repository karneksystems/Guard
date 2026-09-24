/// The same words the backend uses (backend/app/Push/RungMessage.php), so a
/// mirrored notification reads identically to the push it stands in for.
class RungWords {
  const RungWords(this.title, this.body, this.channel);

  final String title;
  final String body;

  /// ladder_urgent for t-1 and open, ladder for the rest.
  final String channel;

  static RungWords forRung({
    required String kind,
    required String instrument,
    required List<String> eventTitles,
    required String opensHhmm,
    required String closesHhmm,
  }) {
    final events = eventTitles.isEmpty ? 'a high-impact release' : eventTitles.take(2).join(', ');
    final channel = (kind == 't-1' || kind == 'open') ? 'ladder_urgent' : 'ladder';
    return switch (kind) {
      't-60' => RungWords('$instrument window in 60 min', '$events. Restricted $opensHhmm to $closesHhmm UTC.', channel),
      't-15' => RungWords('$instrument window in 15 min', '$events. Flat by $opensHhmm UTC.', channel),
      't-5' => RungWords('$instrument window in 5 min', '$events. Close or hold. Gate at $opensHhmm UTC.', channel),
      't-1' => RungWords('One minute: $instrument', '$events. Hands off until $closesHhmm UTC.', channel),
      'open' => RungWords('Restricted: $instrument', '$events. Stay out until $closesHhmm UTC.', channel),
      'end' => RungWords('Clear: $instrument', 'Window closed. Trade at your own pace.', channel),
      _ => RungWords(instrument, events, channel),
    };
  }
}
