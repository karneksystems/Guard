import 'package:flutter/widgets.dart';

import '../platform/platform_bridge.dart';
import '../sync/api_client.dart';
import '../sync/sync_service.dart';
import '../sync/sync_store.dart';
import 'guard_state.dart';

/// The one place screens write through. Applies a change locally first so the UI
/// never waits on the network, then pushes it to the backend when there is one.
/// A failed push is not surfaced as an error: the next sync reconciles.
class GuardController {
  GuardController({
    required this.state,
    required this.bridge,
    this.api,
    this.store,
    this.sync,
  });

  final GuardState state;
  final PlatformBridge bridge;
  final ApiClient? api;
  final LocalStore? store;
  final SyncService? sync;

  Future<void> start() async {
    final prefs = await store?.prefs();
    if (prefs != null) {
      if (prefs['onboarded'] == true) state.markOnboarded();
      final gated = (prefs['gatedApps'] as List?)?.cast<String>();
      if (gated != null) state.setGatedApps(gated);
    }
    await refreshPermissions();
    final cached = await store?.latest();
    if (cached != null) state.update(cached);
    final fresh = await sync?.sync();
    if (fresh != null) state.update(fresh);
  }

  Future<void> refreshPermissions() async {
    state.setPermissions(await bridge.permissionStatus());
  }

  Future<void> requestPermission(GuardPermission p) async {
    await bridge.requestPermission(p);
    await refreshPermissions();
  }

  Future<void> updateSettings(Map<String, dynamic> patch) async {
    state.applySettings(patch);
    final a = api;
    if (a == null || a.token == null) return;
    try {
      await a.putSettings(_toWire(patch));
    } on Exception {
      // The next sync reconciles. Home shows the sync age.
    }
  }

  Future<void> replaceInstruments(List<Map<String, dynamic>> instruments) async {
    state.applyInstruments(instruments);
    final a = api;
    if (a == null || a.token == null) return;
    try {
      await a.putInstruments(instruments);
    } on Exception {
      // As above.
    }
  }

  Future<void> setGatedApps(List<String> ids) async {
    state.setGatedApps(ids);
    await store?.savePrefs({'gatedApps': ids});
  }

  Future<void> finishOnboarding() async {
    state.markOnboarded();
    await store?.savePrefs({'onboarded': true});
  }

  /// Settings travel in snake_case on the wire (backend/routes/api.php).
  static Map<String, dynamic> _toWire(Map<String, dynamic> patch) => {
        if (patch.containsKey('mode')) 'mode': patch['mode'],
        if (patch.containsKey('protection')) 'protection': patch['protection'],
        if (patch.containsKey('windowBeforeMin')) 'window_before_min': patch['windowBeforeMin'],
        if (patch.containsKey('windowAfterMin')) 'window_after_min': patch['windowAfterMin'],
        if (patch.containsKey('firmId')) 'firm_id': patch['firmId'],
        if (patch.containsKey('accountTypeId')) 'account_type_id': patch['accountTypeId'],
        if (patch.containsKey('digestLocalTime')) 'digest_local_time': patch['digestLocalTime'],
      };
}

class ControllerScope extends InheritedWidget {
  const ControllerScope({super.key, required this.controller, required super.child});

  final GuardController controller;

  static GuardController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ControllerScope>();
    assert(scope != null, 'ControllerScope missing above this widget');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(ControllerScope oldWidget) => controller != oldWidget.controller;
}
