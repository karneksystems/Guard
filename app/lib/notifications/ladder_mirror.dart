import '../sync/sync_payload.dart';
import 'notification_scheduler.dart';
import 'reminders.dart';
import 'rung_words.dart';

/// Decision D1: every server rung is mirrored as a local notification at
/// fire_at plus a grace period, deduped by alert id. When the push for an id
/// arrives, its mirror is cancelled. Where cancellation can't happen in time
/// the mirror fires as a repeat, which for an alarm-style product is fine.
class LadderMirror {
  LadderMirror(this.scheduler, {this.grace = const Duration(seconds: 20), Duration? utcOffset}) : _offset = utcOffset;

  final NotificationScheduler scheduler;
  final Duration grace;
  final Duration? _offset;

  /// Rungs that fire inside quiet hours regardless (PUSH-ARCHITECTURE).
  static const alwaysFire = {'t-5', 't-1', 'open'};

  /// Ids the user snoozed: kept across reconcile and pushArrived until they fire.
  final Map<int, DateTime> _snoozed = {};

  /// True when [fireAtUtc] falls in the local quiet range {start, end} (HH:mm).
  bool inQuietHours(Map<String, dynamic>? quiet, DateTime fireAtUtc) {
    if (quiet == null) return false;
    final start = _minutes(quiet['start'] as String?);
    final end = _minutes(quiet['end'] as String?);
    if (start == null || end == null || start == end) return false;
    final local = _offset == null ? fireAtUtc.toLocal() : fireAtUtc.toUtc().add(_offset);
    final m = local.hour * 60 + local.minute;
    return start < end ? (m >= start && m < end) : (m >= start || m < end);
  }

  static int? _minutes(String? hhmm) {
    if (hhmm == null) return null;
    final p = hhmm.split(':');
    final h = int.tryParse(p[0]);
    final i = p.length > 1 ? int.tryParse(p[1]) : 0;
    return h == null || i == null ? null : h * 60 + i;
  }

  /// Bring the OS schedule in line with the payload's ladder. Returns the
  /// number scheduled and cancelled, mostly for logs and tests.
  Future<({int scheduled, int cancelled})> reconcile(SyncPayload payload, {DateTime? now, Map<String, dynamic>? quietHours}) async {
    now ??= DateTime.now().toUtc();
    final windowsById = {for (final w in payload.windows) w['windowId'] as String: w};

    final wanted = <int, ScheduledNotification>{};
    for (final rung in payload.ladder) {
      final alertId = rung['alertId'] as String;
      final fireAt = DateTime.parse(rung['fireAtUtc'] as String).toUtc();
      // The mirror is due at fireAt plus grace; until then it is still wanted,
      // or a reconcile in that gap would cancel the safety net it exists for.
      if (fireAt.add(grace).isBefore(now)) continue;
      final kind = rung['kind'] as String;
      if (!alwaysFire.contains(kind) && inQuietHours(quietHours, fireAt)) continue;
      final window = windowsById[rung['windowId']];
      final instrument = window?['instrument'] as String? ?? 'your instrument';
      final reasons = (window?['reasons'] as List?)?.cast<String>() ?? const [];
      final words = RungWords.forRung(
        kind: rung['kind'] as String,
        instrument: instrument,
        eventTitles: reasons.map(payload.titleFor).toList(),
        opensHhmm: _hhmm(window?['opensAtUtc'] as String?),
        closesHhmm: _hhmm(window?['closesAtUtc'] as String?),
      );
      final id = notificationIdFor(alertId);
      wanted[id] = ScheduledNotification(
        id: id,
        alertId: alertId,
        title: words.title,
        body: words.body,
        atUtc: fireAt.add(grace),
        channel: words.channel,
      );
    }

    _snoozed.removeWhere((_, at) => at.isBefore(now!));
    var cancelled = 0;
    for (final id in await scheduler.pendingIds()) {
      if (id >= kReminderIdBase) continue; // reminders.dart owns that range
      if (_snoozed.containsKey(id)) continue;
      if (!wanted.containsKey(id)) {
        await scheduler.cancel(id);
        cancelled++;
      }
    }

    // Re-scheduling an existing id replaces it on every platform we use, so a
    // moved time is handled by the same call as a new rung.
    for (final n in wanted.values) {
      if (_snoozed.containsKey(n.id)) continue;
      await scheduler.schedule(n);
    }

    return (scheduled: wanted.length, cancelled: cancelled);
  }

  /// The push for this alert id arrived; its mirror isn't needed, unless the
  /// user snoozed it, in which case the snoozed copy is what they asked for.
  Future<void> pushArrived(String alertId) async {
    final id = notificationIdFor(alertId);
    if (_snoozed.containsKey(id)) return;
    await scheduler.cancel(id);
  }

  /// Snooze: the same words again in a minute, under the same id.
  Future<void> snooze(SyncPayload payload, String alertId, {DateTime? now}) async {
    now ??= DateTime.now().toUtc();
    final rung = payload.ladder.where((r) => r['alertId'] == alertId).firstOrNull;
    if (rung == null) return;
    final windowsById = {for (final w in payload.windows) w['windowId'] as String: w};
    final window = windowsById[rung['windowId']];
    final reasons = (window?['reasons'] as List?)?.cast<String>() ?? const [];
    final words = RungWords.forRung(
      kind: rung['kind'] as String,
      instrument: window?['instrument'] as String? ?? 'your instrument',
      eventTitles: reasons.map(payload.titleFor).toList(),
      opensHhmm: _hhmm(window?['opensAtUtc'] as String?),
      closesHhmm: _hhmm(window?['closesAtUtc'] as String?),
    );
    final id = notificationIdFor(alertId);
    final at = now.add(const Duration(minutes: 1));
    _snoozed[id] = at;
    await scheduler.schedule(ScheduledNotification(
      id: id,
      alertId: alertId,
      title: words.title,
      body: words.body,
      atUtc: at,
      channel: words.channel,
    ));
  }

  static String _hhmm(String? isoUtc) => isoUtc == null || isoUtc.length < 16 ? '' : isoUtc.substring(11, 16);
}
