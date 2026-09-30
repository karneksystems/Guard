import 'package:flutter_test/flutter_test.dart';
import 'package:guard_app/state/covers.dart';
import 'package:guard_app/state/guard_state.dart';
import 'package:guard_app/ui/calendar.dart';
import 'package:guard_app/ui/words.dart';

void main() {
  test('short event names are the ones a trader says', () {
    expect(eventShort('EUR', 'CPI Flash Estimate y/y'), 'EUR CPI');
    expect(eventShort('USD', 'Non-Farm Employment Change'), 'NFP');
    expect(eventShort('GBP', 'BoE Official Bank Rate'), 'BoE Rate');
    expect(eventShort('USD', 'FOMC Statement'), 'FOMC');
    expect(eventShort('USD', 'Crude Oil Inventories'), 'Crude Oil Inventories');
  });

  test('markets are named, not coded, and times never use a dash', () {
    expect(marketName('XAUUSD'), 'Gold');
    expect(marketsLine(['XAUUSD', 'EURUSD']), 'gold, EUR');
    expect(marketsLine(['US30', 'US500']), 'US indices');
    final a = DateTime(2026, 10, 1, 8, 55);
    final b = DateTime(2026, 10, 1, 9, 5);
    expect(span(a, b), '8:55 to 9:05');
    expect(span(a, b), isNot(contains('–')));
    expect(countdown(const Duration(minutes: 4, seconds: 12)), '04:12');
    expect(countdown(const Duration(hours: 1, minutes: 4)), '1:04:00');
    expect(money('\$', 1880), '\$1,880');
  });

  test('day words are relative to the local day', () {
    final now = DateTime(2026, 10, 1, 8, 51);
    expect(dayWord(DateTime(2026, 10, 1, 23), now), 'Today');
    expect(dayWord(DateTime(2026, 10, 2, 1), now), 'Tomorrow');
    expect(dayWord(DateTime(2026, 10, 3, 9), now), 'Sat 3 Oct');
  });

  test('the calendar lists every impact on watched currencies and hides all but High by default', () {
    final state = GuardState(onboarded: true);
    final covers = coversFor(state);
    final entries = calendarFor(state, covers);
    // Sample: EUR CPI, BoE and NFP are high, Chicago PMI is medium.
    expect(entries.map((e) => e.impact).toSet(), containsAll(['high', 'medium']));
    expect(entries.firstWhere((e) => e.short == 'EUR CPI').cover, isNotNull);
    expect(entries.firstWhere((e) => e.short == 'USD PMI').cover, isNull);
    final day = entries.where((e) => e.at.toUtc().day == 1).toList();
    expect(ImpactFilter.hint(day, {'high'}), 'Showing High · 1 mid hidden');
    expect(ImpactFilter.hint(day, {'high', 'medium'}), isNull);
  });
}
