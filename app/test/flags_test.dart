import 'package:flutter_test/flutter_test.dart';
import 'package:guard_app/features/flags.dart';

void main() {
  final now = DateTime.utc(2026, 10, 1, 12);

  test('a fresh server answer is the truth either way', () {
    expect(Flags.derive(serverPro: true, proUntil: null, fetchedAt: now.subtract(const Duration(hours: 1)), now: now).pro, isTrue);
    expect(Flags.derive(serverPro: false, proUntil: now.add(const Duration(days: 30)), fetchedAt: now.subtract(const Duration(hours: 1)), now: now).pro, isFalse);
  });

  test('a stale answer keeps Pro for seven days past pro_until, then drops it', () {
    final stale = now.subtract(const Duration(days: 3));
    expect(Flags.derive(serverPro: true, proUntil: now.subtract(const Duration(days: 6)), fetchedAt: stale, now: now).pro, isTrue);
    expect(Flags.derive(serverPro: true, proUntil: now.subtract(const Duration(days: 8)), fetchedAt: stale, now: now).pro, isFalse);
    expect(Flags.derive(serverPro: true, proUntil: null, fetchedAt: stale, now: now).pro, isFalse);
  });

  test('the table', () {
    expect(Flags.free.instrumentsMax, 2);
    expect(Flags.free.journalDays, 7);
    expect(Flags.free.firmMatch, isFalse);
    expect(Flags.free.hardBlock, isFalse);
    expect(Flags.free.ads, isTrue);
    expect(Flags.proFlags.instrumentsMax, 50);
    expect(Flags.proFlags.journalDays, isNull);
    expect(Flags.proFlags.customWindows, isTrue);
    expect(Flags.proFlags.ads, isFalse);
    expect(Flags.windowPresets, [2, 3, 5, 10]);
  });
}
