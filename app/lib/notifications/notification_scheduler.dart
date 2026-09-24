import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// One scheduled local notification. `id` is derived from the alert id so the
/// same rung always maps to the same OS notification.
class ScheduledNotification {
  const ScheduledNotification({
    required this.id,
    required this.alertId,
    required this.title,
    required this.body,
    required this.atUtc,
    required this.channel,
  });

  final int id;
  final String alertId;
  final String title;
  final String body;
  final DateTime atUtc;
  final String channel;
}

/// What the mirror needs from the OS. Real implementation below; the fake is
/// what tests use, and what platforms without a notification plugin fall back to.
abstract class NotificationScheduler {
  Future<void> initialise();
  Future<void> schedule(ScheduledNotification n);
  Future<void> cancel(int id);
  Future<List<int>> pendingIds();
}

/// Alert ids are 20 hex characters; the first 7 give a stable 28-bit int id,
/// which is what the OS APIs take.
int notificationIdFor(String alertId) => int.parse(alertId.substring(0, 7), radix: 16);

class FakeScheduler implements NotificationScheduler {
  final Map<int, ScheduledNotification> pending = {};
  final List<int> cancelled = [];

  @override
  Future<void> initialise() async {}

  @override
  Future<void> schedule(ScheduledNotification n) async => pending[n.id] = n;

  @override
  Future<void> cancel(int id) async {
    if (pending.remove(id) != null) cancelled.add(id);
  }

  @override
  Future<List<int>> pendingIds() async => pending.keys.toList();
}

/// flutter_local_notifications on Android, iOS, macOS and Windows. Windows
/// toasts are scheduled through the OS scheduler, so they fire with the app
/// closed too; the tray app keeps it running anyway for the gate.
class LocalNotificationScheduler implements NotificationScheduler {
  LocalNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static bool get supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows);

  /// Fixed so Windows can route toast activation back to this app across
  /// installs. Change it and every user's pending toasts orphan.
  static const windowsGuid = 'c2f7a1e4-5b8d-4c3a-9e6f-1d2b3c4d5e6f';

  @override
  Future<void> initialise() async {
    if (_ready || !supported) return;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const windows = WindowsInitializationSettings(
      appName: 'Guard',
      appUserModelId: 'Stanchion.Guard',
      guid: windowsGuid,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: darwin, macOS: darwin, windows: windows),
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'ladder_urgent',
        'Window opening',
        description: 'One minute and open alerts. Repeats until dismissed.',
        importance: Importance.max,
      ));
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'ladder',
        'Window ladder',
        description: '60, 15 and 5 minute warnings, and the all clear.',
        importance: Importance.high,
      ));
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'digest',
        'Night-before digest',
        description: "Tomorrow's windows.",
        importance: Importance.defaultImportance,
      ));
    }
    _ready = true;
  }

  @override
  Future<void> schedule(ScheduledNotification n) async {
    if (!supported) return;
    await initialise();
    final urgent = n.channel == 'ladder_urgent';
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        n.channel,
        urgent ? 'Window opening' : 'Window ladder',
        importance: urgent ? Importance.max : Importance.high,
        priority: urgent ? Priority.max : Priority.high,
        category: urgent ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
        fullScreenIntent: urgent,
        ongoing: false,
        tag: n.alertId,
        // PUSH-ARCHITECTURE: T-1 and open repeat alarm-style until dismissed.
        // FLAG_INSISTENT (0x4) loops the sound; the alarm stream gets it past
        // the media volume. The OS caps nothing, so the words say "dismiss".
        additionalFlags: urgent ? Int32List.fromList(const [4]) : null,
        audioAttributesUsage: urgent ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
      ),
      iOS: DarwinNotificationDetails(
        interruptionLevel: n.channel == 'ladder' && n.title.contains('60 min')
            ? InterruptionLevel.active
            : InterruptionLevel.timeSensitive,
        threadIdentifier: n.alertId.substring(0, 7),
      ),
      macOS: const DarwinNotificationDetails(interruptionLevel: InterruptionLevel.timeSensitive),
      windows: WindowsNotificationDetails(
        // Alarms stay on screen until dismissed; the rest use the default toast.
        scenario: urgent ? WindowsNotificationScenario.alarm : null,
      ),
    );
    await _plugin.zonedSchedule(
      id: n.id,
      title: n.title,
      body: n.body,
      scheduledDate: tz.TZDateTime.from(n.atUtc.toUtc(), tz.UTC),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: n.alertId,
    );
  }

  @override
  Future<void> cancel(int id) async {
    if (!supported) return;
    await _plugin.cancel(id: id);
  }

  @override
  Future<List<int>> pendingIds() async {
    if (!supported) return const [];
    final pending = await _plugin.pendingNotificationRequests();
    return pending.map((p) => p.id).toList();
  }
}
