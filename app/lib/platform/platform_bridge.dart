import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A trading app the user can gate. `id` is the package name on Android, the
/// process name on Windows, the bundle id on macOS, and an opaque token on iOS.
/// Ids never leave the device.
class GateableApp {
  const GateableApp({required this.id, required this.label, required this.installed});

  final String id;
  final String label;
  final bool installed;
}

/// The permissions the gate and the ladder need. Not every platform has every one.
enum GuardPermission {
  notifications,
  screenTime,
  usageStats,
  overlay,
  exactAlarm,
  fullScreenIntent,
  batteryUnrestricted;

  String get label => switch (this) {
        notifications => 'Notifications',
        screenTime => 'Screen Time',
        usageStats => 'Usage access',
        overlay => 'Display over other apps',
        exactAlarm => 'Alarms and reminders',
        fullScreenIntent => 'Full screen alerts',
        batteryUnrestricted => 'Unrestricted battery',
      };

  String get why => switch (this) {
        notifications => 'The alert ladder is delivered as notifications.',
        screenTime => 'Lets the guard shield the apps you pick during a window. Apple keeps which apps they are.',
        usageStats => 'Lets the guard notice when MT5 comes to the front during a window.',
        overlay => 'Lets the gate cover MT5 during a window.',
        exactAlarm => 'Starts the guard exactly when a window opens, even if the app is closed.',
        fullScreenIntent => 'Makes the T-1 and open alerts impossible to miss.',
        batteryUnrestricted => 'Stops the phone maker\'s battery manager from delaying alerts.',
      };
}

/// A window handed to the platform gate. Times are UTC epoch milliseconds so
/// the native side never parses a string.
class GateWindowSpec {
  const GateWindowSpec({
    required this.windowId,
    required this.opensAtMs,
    required this.closesAtMs,
    required this.instrument,
    required this.events,
  });

  final String windowId;
  final int opensAtMs;
  final int closesAtMs;
  final String instrument;
  final String events;

  Map<String, Object> toMap() => {
        'windowId': windowId,
        'opensAtMs': opensAtMs,
        'closesAtMs': closesAtMs,
        'instrument': instrument,
        'events': events,
      };
}

/// An outcome the gate recorded while the app wasn't running.
class GateOutcome {
  const GateOutcome({required this.windowId, required this.outcome, required this.atUtc});

  final String windowId;
  final String outcome;
  final DateTime atUtc;
}

/// The desktop watcher saw a gated app come to the front during a window.
class GateTrigger {
  const GateTrigger({required this.windowId, required this.handle});

  final String windowId;

  /// Native window handle of the trading app, opaque to Dart.
  final int handle;
}

/// What the app asks of the OS. One implementation per platform behind a method
/// channel, plus a fake for tests and for platforms where a piece doesn't apply.
abstract class PlatformBridge {
  /// Which permissions this platform has at all.
  Set<GuardPermission> get supportedPermissions;

  /// Whether this platform can enforce a gate at all (Android and Windows).
  bool get hasGate;

  /// Desktop only: the gate is a Flutter screen, so the native side reports
  /// triggers and Dart drives the window. Android shows its own activity and
  /// never emits here.
  Stream<GateTrigger> get gateTriggers;

  Future<void> raiseGate(int handle);
  Future<void> lowerGate();
  Future<void> stayOut(int handle);
  Future<void> setViewingUntil(DateTime untilUtc);

  Future<List<GateableApp>> listApps();

  /// iOS: the OS owns the list. Apple's picker chooses, we hold opaque tokens.
  bool get usesSystemPicker;

  /// Opens the OS picker. True when the user confirmed a selection.
  Future<bool> pickApps();

  Future<Map<GuardPermission, bool>> permissionStatus();

  /// Opens the OS page for the permission. Returns when the user comes back.
  Future<void> requestPermission(GuardPermission permission);

  /// Replace the platform gate's schedule. Returns how many windows it holds.
  Future<int> scheduleGateWindows({
    required List<GateWindowSpec> windows,
    required List<String> gatedAppIds,
    required String protection,
  });

  /// Outcomes recorded by the gate since the last drain. Clears them.
  Future<List<GateOutcome>> drainJournal();
}

/// Android and, later, Windows and macOS. iOS has no gate to grant permissions
/// for beyond notifications; the Screen Time authorisation is its own flow.
class MethodChannelBridge implements PlatformBridge {
  MethodChannelBridge({TargetPlatform? platform}) : _platform = platform ?? defaultTargetPlatform {
    _gate.setMethodCallHandler((call) async {
      if (call.method == 'gateTriggered') {
        final m = (call.arguments as Map).cast<Object?, Object?>();
        _triggers.add(GateTrigger(windowId: m['windowId'] as String, handle: (m['handle'] as num).toInt()));
      }
      return null;
    });
  }

  static const _gate = MethodChannel('guard/gate');
  static const _permissions = MethodChannel('guard/permissions');

  final TargetPlatform _platform;
  final _triggers = StreamController<GateTrigger>.broadcast();

  @override
  Stream<GateTrigger> get gateTriggers => _triggers.stream;

  Future<void> _gateCall(String method, [Map<String, Object?>? args]) async {
    try {
      await _gate.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // Not on this platform.
    }
  }

  @override
  Future<void> raiseGate(int handle) => _gateCall('raiseGate', {'handle': handle});

  @override
  Future<void> lowerGate() => _gateCall('lowerGate');

  @override
  Future<void> stayOut(int handle) => _gateCall('stayOut', {'handle': handle});

  @override
  Future<void> setViewingUntil(DateTime untilUtc) =>
      _gateCall('setViewingUntil', {'untilMs': untilUtc.toUtc().millisecondsSinceEpoch});

  @override
  Set<GuardPermission> get supportedPermissions => switch (_platform) {
        TargetPlatform.android => GuardPermission.values.toSet(),
        TargetPlatform.iOS => {GuardPermission.notifications, GuardPermission.screenTime},
        TargetPlatform.windows || TargetPlatform.macOS => {GuardPermission.notifications},
        _ => const {},
      };

  /// Desktop and iOS have no native side for these channels yet; treat a missing
  /// implementation as "nothing to gate, nothing to grant" rather than a crash.
  @override
  Future<List<GateableApp>> listApps() async {
    try {
      final raw = await _gate.invokeListMethod<Map<Object?, Object?>>('listApps') ?? const [];
      return raw
          .map((m) => GateableApp(
                id: m['id'] as String,
                label: m['label'] as String,
                installed: m['installed'] == true,
              ))
          .toList();
    } on MissingPluginException {
      return const [GateableApp(id: 'net.metaquotes.metatrader5', label: 'MetaTrader 5', installed: false)];
    }
  }

  @override
  Future<Map<GuardPermission, bool>> permissionStatus() async {
    try {
      final raw = await _permissions.invokeMapMethod<String, bool>('status') ?? const {};
      return {for (final p in supportedPermissions) p: raw[p.name] ?? false};
    } on MissingPluginException {
      return {for (final p in supportedPermissions) p: true};
    }
  }

  @override
  Future<void> requestPermission(GuardPermission permission) async {
    try {
      await _permissions.invokeMethod<void>('request', {'name': permission.name});
    } on MissingPluginException {
      // Nothing to open on this platform yet.
    }
  }

  @override
  bool get hasGate => switch (_platform) {
        TargetPlatform.android || TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.iOS => true,
        _ => false,
      };

  @override
  bool get usesSystemPicker => _platform == TargetPlatform.iOS;

  @override
  Future<bool> pickApps() async {
    if (!usesSystemPicker) return false;
    try {
      return await _gate.invokeMethod<bool>('pickApps') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<int> scheduleGateWindows({
    required List<GateWindowSpec> windows,
    required List<String> gatedAppIds,
    required String protection,
  }) async {
    if (!hasGate) return 0;
    try {
      return await _gate.invokeMethod<int>('scheduleWindows', {
            'windows': windows.map((w) => w.toMap()).toList(),
            'gatedPackages': gatedAppIds,
            'protection': protection,
          }) ??
          0;
    } on MissingPluginException {
      return 0;
    }
  }

  @override
  Future<List<GateOutcome>> drainJournal() async {
    if (!hasGate) return const [];
    try {
      final raw = await _gate.invokeListMethod<Map<Object?, Object?>>('drainJournal') ?? const [];
      return raw
          .map((m) => GateOutcome(
                windowId: m['windowId'] as String,
                outcome: m['outcome'] as String,
                atUtc: DateTime.fromMillisecondsSinceEpoch((m['atMs'] as num).toInt(), isUtc: true),
              ))
          .toList();
    } on MissingPluginException {
      return const [];
    }
  }
}

/// Deterministic stand-in. Tests flip permissions; sample mode gets MT5 only.
class FakeBridge implements PlatformBridge {
  FakeBridge({
    Set<GuardPermission>? supported,
    Map<GuardPermission, bool>? granted,
    List<GateableApp>? apps,
  })  : supportedPermissions = supported ?? GuardPermission.values.toSet(),
        _granted = {...?granted},
        _apps = apps ??
            const [
              GateableApp(id: 'net.metaquotes.metatrader5', label: 'MetaTrader 5', installed: true),
              GateableApp(id: 'net.metaquotes.metatrader4', label: 'MetaTrader 4', installed: false),
              GateableApp(id: 'com.spotware.ct', label: 'cTrader', installed: false),
            ];

  @override
  final Set<GuardPermission> supportedPermissions;

  @override
  bool hasGate = true;

  @override
  bool usesSystemPicker = false;

  /// What pickApps returns, and how often it was asked.
  bool pickResult = true;
  int pickCalls = 0;

  @override
  Future<bool> pickApps() async {
    pickCalls++;
    return pickResult;
  }

  final Map<GuardPermission, bool> _granted;
  final List<GateableApp> _apps;
  final List<GuardPermission> requested = [];

  /// What the last scheduleGateWindows call handed over.
  List<GateWindowSpec> scheduledWindows = const [];
  List<String> scheduledGatedAppIds = const [];
  String scheduledProtection = '';
  int scheduleCalls = 0;

  /// Outcomes the next drainJournal returns.
  final List<GateOutcome> pendingOutcomes = [];

  final _triggers = StreamController<GateTrigger>.broadcast();
  final List<int> raised = [];
  int lowered = 0;
  final List<int> stayedOut = [];
  DateTime? viewingUntil;

  /// Tests call this to simulate the desktop watcher firing.
  void trigger(String windowId, {int handle = 4242}) =>
      _triggers.add(GateTrigger(windowId: windowId, handle: handle));

  @override
  Stream<GateTrigger> get gateTriggers => _triggers.stream;

  @override
  Future<void> raiseGate(int handle) async => raised.add(handle);

  @override
  Future<void> lowerGate() async => lowered++;

  @override
  Future<void> stayOut(int handle) async => stayedOut.add(handle);

  @override
  Future<void> setViewingUntil(DateTime untilUtc) async => viewingUntil = untilUtc;

  /// Tests call this to simulate the user granting on the OS page.
  void grant(GuardPermission p, [bool value = true]) => _granted[p] = value;

  @override
  Future<List<GateableApp>> listApps() async => _apps;

  @override
  Future<Map<GuardPermission, bool>> permissionStatus() async =>
      {for (final p in supportedPermissions) p: _granted[p] ?? false};

  @override
  Future<void> requestPermission(GuardPermission permission) async {
    requested.add(permission);
  }

  @override
  Future<int> scheduleGateWindows({
    required List<GateWindowSpec> windows,
    required List<String> gatedAppIds,
    required String protection,
  }) async {
    scheduledWindows = windows;
    scheduledGatedAppIds = gatedAppIds;
    scheduledProtection = protection;
    scheduleCalls++;
    return windows.length;
  }

  @override
  Future<List<GateOutcome>> drainJournal() async {
    final out = [...pendingOutcomes];
    pendingOutcomes.clear();
    return out;
  }
}
