import 'dart:async';

import 'package:flutter/widgets.dart';

import '../notifications/ladder_mirror.dart';
import '../notifications/push_registrar.dart';
import '../platform/platform_bridge.dart';
import '../sync/api_client.dart';
import '../sync/sync_payload.dart';
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
    this.mirror,
    this.push,
  });

  final GuardState state;
  final PlatformBridge bridge;
  final ApiClient? api;
  final LocalStore? store;
  final SyncService? sync;
  final LadderMirror? mirror;
  final PushRegistrar? push;

  StreamSubscription<Map<String, dynamic>>? _pushSub;

  Future<void> start() async {
    final prefs = await store?.prefs();
    if (prefs != null) {
      if (prefs['onboarded'] == true) state.markOnboarded();
      final gated = (prefs['gatedApps'] as List?)?.cast<String>();
      if (gated != null) state.setGatedApps(gated);
    }
    await refreshPermissions();
    await mirror?.scheduler.initialise();
    _pushSub ??= push?.messages.listen(_onPush);

    final cached = await store?.latest();
    if (cached != null) await applyPayload(cached);
    final fresh = await sync?.sync();
    if (fresh != null) await applyPayload(fresh);
    await registerPushToken();
    await drainGateJournal();
  }

  /// A new payload: state, the local mirror of its ladder, the platform gate.
  Future<void> applyPayload(SyncPayload payload) async {
    state.update(payload);
    await mirror?.reconcile(payload);
    await pushGateSchedule();
  }

  /// Hand the device engine's windows to the platform gate, with the gated app
  /// ids and the protection mode. Called after every payload and settings change.
  Future<int> pushGateSchedule() async {
    if (!bridge.hasGate) return 0;
    final windows = state.windows
        .map((w) => GateWindowSpec(
              windowId: w.windowId,
              opensAtMs: DateTime.parse(w.opensAtUtc).toUtc().millisecondsSinceEpoch,
              closesAtMs: DateTime.parse(w.closesAtUtc).toUtc().millisecondsSinceEpoch,
              instrument: w.instrument,
              events: w.reasons.map(state.titleFor).join(', '),
            ))
        .toList();
    return bridge.scheduleGateWindows(
      windows: windows,
      gatedAppIds: state.gatedAppIds,
      protection: state.settings['protection'] as String? ?? 'soft-gate',
    );
  }

  /// Outcomes the gate recorded while the app was closed: into state and up to
  /// the backend. The package name never travels; only window id and outcome.
  Future<void> drainGateJournal() async {
    final outcomes = await bridge.drainJournal();
    if (outcomes.isEmpty) return;
    state.addJournal(outcomes);
    for (final o in outcomes) {
      await _postOutcome(o);
    }
  }

  /// One outcome recorded right now, by the desktop gate or by the user.
  Future<void> recordOutcome(String windowId, String outcome, [DateTime? atUtc]) async {
    final o = GateOutcome(windowId: windowId, outcome: outcome, atUtc: (atUtc ?? DateTime.now()).toUtc());
    state.addJournal([o]);
    await _postOutcome(o);
  }

  Future<void> _postOutcome(GateOutcome o) async {
    final a = api;
    if (a == null || a.token == null) return;
    try {
      await a.postJournal(windowId: o.windowId, outcome: o.outcome, atUtc: o.atUtc);
    } on Exception {
      // Kept in state; a journal entry that misses the server is acceptable.
    }
  }

  Future<void> registerPushToken() async {
    final token = await push?.token();
    final a = api;
    if (token == null || a == null || a.token == null) return;
    try {
      await a.updateDevice(pushToken: token, notifState: state.permissions[GuardPermission.notifications] == false ? 'denied' : 'granted');
    } on Exception {
      // Next launch tries again.
    }
  }

  void _onPush(Map<String, dynamic> data) {
    final alertId = data['alertId'] as String?;
    if (alertId != null) {
      unawaited(mirror?.pushArrived(alertId) ?? Future.value());
    }
  }

  void dispose() {
    _pushSub?.cancel();
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
    await pushGateSchedule();
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
    await pushGateSchedule();
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
    await pushGateSchedule();
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
