import 'package:rule_engine/rule_engine.dart';

import '../features/tracker.dart';
import '../ui/words.dart';
import 'notification_scheduler.dart';

/// Ids at or above this are reminders, not ladder rungs. The ladder mirror
/// leaves them alone and this planner never touches anything below.
const int kReminderIdBase = 0x10000000;

/// Ids at or above this belong to the debug test window; nobody else cancels them.
const int kTestIdBase = 0x20000000;

const int _digestBase = kReminderIdBase + 1000;
const int _weekendId = kReminderIdBase + 1;
const int _inactivityId = kReminderIdBase + 2;

/// Free-tier reminders as local notifications: the night-before digest, the
/// weekend hold warning, the inactivity reminder. All device-only by design
/// (PUSH-ARCHITECTURE: the digest isn't time-critical, so no server push).
class ReminderPlanner {
  ReminderPlanner(this.scheduler, {Duration? utcOffset}) : _offset = utcOffset;

  final NotificationScheduler scheduler;
  final Duration? _offset;

  /// Local wall time as a UTC-flagged DateTime, so the arithmetic is plain.
  /// With no injected offset the platform's zone decides, per date, so a DST
  /// change between now and the reminder does not shift it by an hour.
  DateTime local(DateTime utc) {
    final o = _offset;
    if (o != null) return utc.toUtc().add(o);
    final l = utc.toLocal();
    return DateTime.utc(l.year, l.month, l.day, l.hour, l.minute, l.second);
  }

  DateTime toUtc(DateTime localAsUtc) {
    final o = _offset;
    if (o != null) return localAsUtc.subtract(o);
    return DateTime(localAsUtc.year, localAsUtc.month, localAsUtc.day, localAsUtc.hour, localAsUtc.minute, localAsUtc.second).toUtc();
  }

  List<ScheduledNotification> plan({
    required List<Window> windows,
    required String Function(String eventId) titleFor,
    required String digestLocalTime,
    required Tracker tracker,
    required DateTime now,
  }) {
    final out = <ScheduledNotification>[];
    final nowUtc = now.toUtc();

    // Digest: one per local day that has windows, at digest time the evening before.
    final parts = digestLocalTime.split(':');
    final dh = int.tryParse(parts.first) ?? 20;
    final dm = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final byDay = <String, List<Window>>{};
    for (final w in windows) {
      final day = Tracker.dateKey(local(DateTime.parse(w.opensAtUtc)));
      byDay.putIfAbsent(day, () => []).add(w);
    }
    final days = byDay.keys.toList()..sort();
    var n = 0;
    for (final day in tracker.tomorrowNews ? days : const <String>[]) {
      final eve = DateTime.parse(day).subtract(const Duration(days: 1));
      final fireLocal = DateTime.utc(eve.year, eve.month, eve.day, dh, dm);
      final fireUtc = toUtc(fireLocal);
      if (!fireUtc.isAfter(nowUtc)) continue;
      final ws = byDay[day]!..sort((a, b) => a.opensAtUtc.compareTo(b.opensAtUtc));
      // One cover per time and event, however many markets it touches.
      final covers = <String, List<Window>>{};
      for (final w in ws) {
        covers.putIfAbsent('${w.opensAtUtc}|${w.reasons.join(',')}', () => []).add(w);
      }
      final first = covers.values.first;
      final markets = first.map((w) => marketName(w.instrument)).toSet().join(', ');
      final names = <String>{for (final w in first) ...w.reasons.map(titleFor)}.join(', ');
      final more = covers.length - 1;
      final firstLocal = local(DateTime.parse(first.first.opensAtUtc));
      out.add(ScheduledNotification(
        id: _digestBase + n++,
        alertId: 'digest:$day',
        title: 'Tomorrow: ${covers.length} high impact ${covers.length == 1 ? 'window' : 'windows'}',
        body: "Tomorrow's news is ready. $markets · $names at ${_hhmm(firstLocal)}${more > 0 ? ', then $more more' : ''}. Cover is on.",
        atUtc: fireUtc,
        channel: 'digest',
      ));
      if (n >= 14) break;
    }

    // Weekend hold: Friday 20:30 UTC, half an hour before the New York close in
    // summer and ninety minutes before it in winter. Early beats late here.
    if (tracker.weekendWarning) {
      var friday = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, 20, 30);
      while (friday.weekday != DateTime.friday || !friday.isAfter(nowUtc)) {
        friday = friday.add(const Duration(days: 1));
      }
      out.add(ScheduledNotification(
        id: _weekendId,
        alertId: 'weekend:${Tracker.dateKey(friday)}',
        title: 'Weekend hold',
        body: 'Markets close soon. Be flat over the weekend unless your firm allows holding.',
        atUtc: friday,
        channel: 'digest',
      ));
    }

    // Inactivity: three days before the firm's limit, at 09:00 local.
    final last = tracker.lastActivityDate;
    if (tracker.inactivityDays > 3 && last != null) {
      final warnDay = DateTime.parse(last).add(Duration(days: tracker.inactivityDays - 3));
      final fireUtc = toUtc(DateTime.utc(warnDay.year, warnDay.month, warnDay.day, 9));
      if (fireUtc.isAfter(nowUtc)) {
        out.add(ScheduledNotification(
          id: _inactivityId,
          alertId: 'inactivity:$last',
          title: 'No trade in ${tracker.inactivityDays - 3} days',
          body: 'Some firms close accounts idle for ${tracker.inactivityDays}. Log a trade or check your rules.',
          atUtc: fireUtc,
          channel: 'digest',
        ));
      }
    }

    return out;
  }

  /// Bring the OS schedule in line. Only touches ids in the reminder range.
  Future<({int scheduled, int cancelled})> reconcile({
    required List<Window> windows,
    required String Function(String eventId) titleFor,
    required String digestLocalTime,
    required Tracker tracker,
    DateTime? now,
  }) async {
    final wanted = {
      for (final n in plan(
        windows: windows,
        titleFor: titleFor,
        digestLocalTime: digestLocalTime,
        tracker: tracker,
        now: now ?? DateTime.now().toUtc(),
      ))
        n.id: n,
    };
    var cancelled = 0;
    for (final id in await scheduler.pendingIds()) {
      if (id < kReminderIdBase || id >= kTestIdBase || wanted.containsKey(id)) continue;
      await scheduler.cancel(id);
      cancelled++;
    }
    for (final n in wanted.values) {
      await scheduler.schedule(n);
    }
    return (scheduled: wanted.length, cancelled: cancelled);
  }

  static String _hhmm(DateTime t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
}
