import 'dart:async';

import 'package:flutter/material.dart';

import '../platform/platform_bridge.dart';
import '../state/guard_controller.dart';
import 'gate_screen.dart';

/// Desktop Soft gate, Dart side. The native watcher says a gated app came to the
/// front; this raises the app window over it and shows GateScreen. Stay out
/// minimises the trading app; hold-to-view lifts the gate for sixty seconds.
class DesktopGate {
  DesktopGate({
    required this.controller,
    required this.navigatorKey,
    this.viewGrace = const Duration(seconds: 60),
    this.now,
  });

  final GuardController controller;
  final GlobalKey<NavigatorState> navigatorKey;
  final Duration viewGrace;
  final DateTime Function()? now;

  StreamSubscription<GateTrigger>? _sub;
  DateTime? _viewingUntil;
  String? _showingWindowId;

  bool get showing => _showingWindowId != null;

  void start() {
    _sub ??= controller.bridge.gateTriggers.listen(handle);
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  DateTime get _now => (now ?? DateTime.now)().toUtc();

  Future<void> handle(GateTrigger t) async {
    final state = controller.state;
    final protection = state.settings['protection'] as String? ?? 'soft-gate';
    if (protection == 'warn-only') return;
    if (_viewingUntil != null && _now.isBefore(_viewingUntil!)) return;
    if (_showingWindowId != null) return;

    final windows = state.windows.where((w) => w.windowId == t.windowId);
    if (windows.isEmpty) return;
    final w = windows.first;
    final closes = DateTime.parse(w.closesAtUtc).toUtc();
    if (!_now.isBefore(closes)) return;

    _showingWindowId = w.windowId;
    await controller.bridge.raiseGate(t.handle);

    final nav = navigatorKey.currentState;
    if (nav == null) {
      _showingWindowId = null;
      return;
    }
    await nav.push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => GateScreen(
        instrument: w.instrument,
        events: w.reasons.map(state.titleFor).join(', '),
        closesAtUtc: closes,
        hardBlock: protection == 'hard-block',
        now: now,
        onStayOut: () => _finish(w.windowId, 'stayed-out', () => controller.bridge.stayOut(t.handle)),
        onView: () => _finish(w.windowId, 'viewed', () async {
          _viewingUntil = _now.add(viewGrace);
          await controller.bridge.setViewingUntil(_viewingUntil!);
          await controller.bridge.lowerGate();
        }),
        onExpired: () => _finish(w.windowId, null, controller.bridge.lowerGate),
      ),
    ));
  }

  Future<void> _finish(String windowId, String? outcome, Future<void> Function() action) async {
    // Stay out, hold-to-view and expiry can race each other: first one wins.
    if (_showingWindowId != windowId) return;
    _showingWindowId = null;
    final at = _now;
    navigatorKey.currentState?.pop();
    await action();
    if (outcome != null) {
      // The POST inside must never hold the gate; the journal is local first.
      unawaited(controller.recordOutcome(windowId, outcome, at));
    }
  }
}
