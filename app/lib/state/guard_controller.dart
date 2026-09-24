import 'dart:async';

import 'package:flutter/widgets.dart';

import '../billing/billing.dart';
import '../features/tracker.dart';
import '../packs/pack_cache.dart';
import '../notifications/ladder_mirror.dart';
import '../notifications/push_registrar.dart';
import '../notifications/reminders.dart';
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
    this.reminders,
    this.billing,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final GuardState state;
  final PlatformBridge bridge;
  final ApiClient? api;
  final LocalStore? store;
  final SyncService? sync;
  final LadderMirror? mirror;
  final PushRegistrar? push;
  final ReminderPlanner? reminders;
  final Billing? billing;
  final DateTime Function() _now;

  StreamSubscription<Map<String, dynamic>>? _pushSub;

  Future<void> start() async {
    final prefs = await store?.prefs();
    if (prefs != null) {
      if (prefs['onboarded'] == true) state.markOnboarded();
      final gated = (prefs['gatedApps'] as List?)?.cast<String>();
      if (gated != null) state.setGatedApps(gated);
      final tracker = prefs['tracker'] as Map<String, dynamic>?;
      if (tracker != null) state.setTracker(Tracker.fromJson(tracker));
      final packs = prefs['packs'] as Map<String, dynamic>?;
      if (packs != null) state.setPacks(PackCache.fromJson(packs));
      final journal = (prefs['journal'] as List?)?.cast<Map<String, dynamic>>();
      if (journal != null) {
        state.restoreJournal(journal.map((j) => GateOutcome(
              windowId: j['windowId'] as String,
              outcome: j['outcome'] as String,
              atUtc: DateTime.parse(j['atUtc'] as String).toUtc(),
            )));
      }
    }
    await refreshPermissions();
    await mirror?.scheduler.initialise();
    _pushSub ??= push?.messages.listen(_onPush);

    final cached = await store?.latest();
    if (cached != null) await applyPayload(cached);
    final fresh = await sync?.sync();
    if (fresh != null) await applyPayload(fresh);
    await refreshPacks();
    await registerPushToken();
    await drainGateJournal();
  }

  /// A new payload: state, the local mirror of its ladder, the platform gate.
  Future<void> applyPayload(SyncPayload payload) async {
    state.update(payload);
    await mirror?.reconcile(payload);
    await pushGateSchedule();
    await refreshReminders();
  }

  /// The pack index, plus the full pack for the user's firm. A version change on
  /// that pack raises the rules-changed flag. Network failure keeps the cache.
  Future<void> refreshPacks() async {
    final a = api;
    if (a == null) return;
    final cache = PackCache(index: {...state.packs.index}, packs: {...state.packs.packs});
    RulesChanged? changed;
    try {
      final rows = await a.listPacks();
      cache.index
        ..clear()
        ..addEntries(rows.map(PackIndexEntry.fromJson).map((e) => MapEntry(e.firmId, e)));
      final firmId = state.settings['firmId'] as String?;
      if (firmId != null && cache.index.containsKey(firmId)) {
        final cached = cache.packs[firmId];
        if (cached == null || cached['packVersion'] != cache.index[firmId]!.packVersion) {
          changed = cache.put(await a.getPack(firmId));
        }
      }
    } on Exception {
      return; // the cache stands
    }
    state.setPacks(cache, changed: changed);
    await store?.savePrefs({'packs': cache.toJson()});
    await pushGateSchedule();
    await refreshReminders();
  }

  /// Firm match: pick the firm and account type, fetch the pack, recompute.
  Future<void> selectFirm({required String firmId, required String accountTypeId}) async {
    await updateSettings({'mode': 'firm-match', 'firmId': firmId, 'accountTypeId': accountTypeId});
    await refreshPacks();
  }

  /// Buy or restore through the store, then let the server verify. Returns
  /// true when the server granted Pro.
  Future<bool> upgrade(Plan plan, {bool restore = false}) async {
    final b = billing;
    final a = api;
    if (b == null) return false;
    final purchases = restore ? await b.restore() : [?await b.buy(plan)];
    if (purchases.isEmpty) return false;
    if (a == null || a.token == null) return false;
    for (final p in purchases) {
      try {
        final until = await a.postEntitlement(platform: p.platform, plan: p.plan.name, receipt: p.receipt);
        if (until != null) {
          final fresh = await sync?.sync();
          if (fresh != null) await applyPayload(fresh);
          return state.pro;
        }
      } on Exception {
        // Try the next receipt; the store keeps the purchase either way.
      }
    }
    return false;
  }

  /// Digest, weekend and inactivity reminders follow the windows and the tracker.
  Future<void> refreshReminders() async {
    final r = reminders;
    if (r == null) return;
    await r.reconcile(
      windows: state.windows,
      titleFor: state.titleFor,
      digestLocalTime: state.settings['digestLocalTime'] as String? ?? '20:00',
      tracker: state.tracker,
      now: _now().toUtc(),
    );
  }

  /// The clock, injectable for tests.
  DateTime get now => _now();

  /// Local date today, the key the tracker files entries under.
  String get today => Tracker.dateKey(_now().toLocal());

  Future<void> updateTracker(Tracker t) async {
    final pruned = t.prune(today);
    state.setTracker(pruned);
    await store?.savePrefs({'tracker': pruned.toJson()});
    await refreshReminders();
  }

  Future<void> logPnl(double amount, {String? note}) =>
      updateTracker(state.tracker.add(PnlEntry(date: today, amount: amount, note: note)));

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
    await _saveJournal();
    for (final o in outcomes) {
      await _postOutcome(o);
    }
  }

  /// The journal lives on the device first (Pro keeps it all, Free shows a
  /// week); the backend copy is for the hub later.
  Future<void> _saveJournal() async {
    final keep = state.journal.take(1000);
    await store?.savePrefs({
      'journal': [
        for (final e in keep) {'windowId': e.windowId, 'outcome': e.outcome, 'atUtc': e.atUtc.toIso8601String()},
      ],
    });
  }

  /// One outcome recorded right now, by the desktop gate or by the user.
  Future<void> recordOutcome(String windowId, String outcome, [DateTime? atUtc]) async {
    final o = GateOutcome(windowId: windowId, outcome: outcome, atUtc: (atUtc ?? _now()).toUtc());
    state.addJournal([o]);
    await _saveJournal();
    await _postOutcome(o);
  }

  /// The user says a viewed gate became a trade. Amends the entry; the backend
  /// gets it as a fresh journal post with the same window id.
  Future<void> amendOutcome(String windowId, String outcome) async {
    final o = state.amendJournal(windowId, outcome);
    if (o == null) return;
    await _saveJournal();
    await _postOutcome(GateOutcome(windowId: windowId, outcome: outcome, atUtc: _now().toUtc()));
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
    if (patch.containsKey('digestLocalTime') || patch.containsKey('windowBeforeMin')) await refreshReminders();
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
    await refreshReminders();
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
