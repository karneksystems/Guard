import '../sync/sync_payload.dart';
import 'notification_scheduler.dart';
import 'rung_words.dart';

/// Decision D1: every server rung is mirrored as a local notification at
/// fire_at plus a grace period, deduped by alert id. When the push for an id
/// arrives, its mirror is cancelled. Where cancellation can't happen in time
/// the mirror fires as a repeat, which for an alarm-style product is fine.
class LadderMirror {
  LadderMirror(this.scheduler, {this.grace = const Duration(seconds: 20)});

  final NotificationScheduler scheduler;
  final Duration grace;

  /// Bring the OS schedule in line with the payload's ladder. Returns the
  /// number scheduled and cancelled, mostly for logs and tests.
  Future<({int scheduled, int cancelled})> reconcile(SyncPayload payload, {DateTime? now}) async {
    now ??= DateTime.now().toUtc();
    final windowsById = {for (final w in payload.windows) w['windowId'] as String: w};

    final wanted = <int, ScheduledNotification>{};
    for (final rung in payload.ladder) {
      final alertId = rung['alertId'] as String;
      final fireAt = DateTime.parse(rung['fireAtUtc'] as String).toUtc();
      if (fireAt.isBefore(now)) continue;
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

    var cancelled = 0;
    for (final id in await scheduler.pendingIds()) {
      if (!wanted.containsKey(id)) {
        await scheduler.cancel(id);
        cancelled++;
      }
    }

    // Re-scheduling an existing id replaces it on every platform we use, so a
    // moved time is handled by the same call as a new rung.
    for (final n in wanted.values) {
      await scheduler.schedule(n);
    }

    return (scheduled: wanted.length, cancelled: cancelled);
  }

  /// The push for this alert id arrived; its mirror isn't needed.
  Future<void> pushArrived(String alertId) => scheduler.cancel(notificationIdFor(alertId));

  static String _hhmm(String? isoUtc) => isoUtc == null || isoUtc.length < 16 ? '' : isoUtc.substring(11, 16);
}
