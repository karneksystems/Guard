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
  usageStats,
  overlay,
  exactAlarm,
  fullScreenIntent,
  batteryUnrestricted;

  String get label => switch (this) {
        notifications => 'Notifications',
        usageStats => 'Usage access',
        overlay => 'Display over other apps',
        exactAlarm => 'Alarms and reminders',
        fullScreenIntent => 'Full screen alerts',
        batteryUnrestricted => 'Unrestricted battery',
      };

  String get why => switch (this) {
        notifications => 'The alert ladder is delivered as notifications.',
        usageStats => 'Lets the guard notice when MT5 comes to the front during a window.',
        overlay => 'Lets the gate cover MT5 during a window.',
        exactAlarm => 'Starts the guard exactly when a window opens, even if the app is closed.',
        fullScreenIntent => 'Makes the T-1 and open alerts impossible to miss.',
        batteryUnrestricted => 'Stops the phone maker\'s battery manager from delaying alerts.',
      };
}

/// What the app asks of the OS. One implementation per platform behind a method
/// channel, plus a fake for tests and for platforms where a piece doesn't apply.
abstract class PlatformBridge {
  /// Which permissions this platform has at all.
  Set<GuardPermission> get supportedPermissions;

  Future<List<GateableApp>> listApps();

  Future<Map<GuardPermission, bool>> permissionStatus();

  /// Opens the OS page for the permission. Returns when the user comes back.
  Future<void> requestPermission(GuardPermission permission);
}

/// Android and, later, Windows and macOS. iOS has no gate to grant permissions
/// for beyond notifications; the Screen Time authorisation is its own flow.
class MethodChannelBridge implements PlatformBridge {
  MethodChannelBridge({TargetPlatform? platform}) : _platform = platform ?? defaultTargetPlatform;

  static const _gate = MethodChannel('guard/gate');
  static const _permissions = MethodChannel('guard/permissions');

  final TargetPlatform _platform;

  @override
  Set<GuardPermission> get supportedPermissions => switch (_platform) {
        TargetPlatform.android => GuardPermission.values.toSet(),
        TargetPlatform.iOS => {GuardPermission.notifications},
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

  final Map<GuardPermission, bool> _granted;
  final List<GateableApp> _apps;
  final List<GuardPermission> requested = [];

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
}
