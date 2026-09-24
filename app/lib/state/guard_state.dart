import 'package:flutter/widgets.dart';
import 'package:rule_engine/rule_engine.dart';

import '../data/sample_data.dart';
import '../features/flags.dart';
import '../features/tracker.dart';
import '../packs/pack_cache.dart';
import '../platform/platform_bridge.dart';
import '../sync/sync_payload.dart';

/// What the screens read. Either a synced payload or, before the first sync and
/// in tests, the sample data. Windows are always computed on the device by the
/// engine, so the gate works with the network off.
class GuardState extends ChangeNotifier {
  GuardState({this._payload, this._userId = 'device', this._onboarded = false, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  SyncPayload? _payload;
  final DateTime Function() _now;
  final String _userId;
  bool _onboarded;

  Map<String, dynamic>? _localSettings;
  List<Map<String, dynamic>>? _localInstruments;
  List<String> _gatedAppIds = const ['net.metaquotes.metatrader5'];
  Map<GuardPermission, bool> _permissions = const {};
  final List<GateOutcome> _journal = [];
  Tracker _tracker = const Tracker();
  PackCache _packs = PackCache();
  RulesChanged? _rulesChanged;
  List<String> _engineNotes = const [];

  SyncPayload? get payload => _payload;
  bool get isSample => _payload == null;
  /// docs/FREE-PRO-FLAGS.md: fresh server word wins, stale word gets a grace.
  Flags get flags {
    final p = _payload;
    if (p == null) return Flags.free;
    return Flags.derive(serverPro: p.pro, proUntil: p.proUntil, fetchedAt: p.fetchedAtUtc, now: _now().toUtc());
  }

  bool get pro => flags.pro;

  PackCache get packs => _packs;
  RulesChanged? get rulesChanged => _rulesChanged;

  /// What the engine said about the last computation ("using the calendar, not
  /// the firm's list", "pack unverified", ...).
  List<String> get engineNotes => _engineNotes;

  /// The pack behind Firm match, when the mode is on and the pack is cached.
  Map<String, dynamic>? get activePack {
    if (settings['mode'] != 'firm-match') return null;
    final id = settings['firmId'] as String?;
    return id == null ? null : _packs.packs[id];
  }
  bool get onboarded => _onboarded;

  /// Local edits win over the last payload until the next sync replaces both.
  Map<String, dynamic> get settings => _localSettings ?? _payload?.settings ?? SampleData.settings;
  List<Map<String, dynamic>> get instruments =>
      _localInstruments ?? _payload?.instruments ?? SampleData.instruments;
  List<String> get gatedAppIds => _gatedAppIds;
  Map<GuardPermission, bool> get permissions => _permissions;

  /// Newest first.
  List<GateOutcome> get journal => List.unmodifiable(_journal);

  Tracker get tracker => _tracker;

  /// The source strip: where the event came from and when we last fetched it.
  String sourceFor(String eventId) {
    final p = _payload;
    if (p == null) return 'sample calendar';
    for (final e in p.events) {
      if (e['id'] != eventId) continue;
      final source = e['source'] as String? ?? 'calendar feed';
      final fetched = e['fetchedAt'] as String?;
      return fetched == null || fetched.length < 10 ? source : '$source · fetched ${fetched.substring(0, 10)}';
    }
    return 'calendar feed';
  }

  /// Permissions the platform supports that the user hasn't granted yet.
  List<GuardPermission> get missingPermissions =>
      _permissions.entries.where((e) => !e.value).map((e) => e.key).toList();

  String titleFor(String eventId) => _payload?.titleFor(eventId) ?? SampleData.titleFor(eventId);

  /// Windows in time order, computed by the device engine.
  List<Window> get windows {
    final base = _payload?.engineInput(_userId) ?? SampleData.engineInput();
    final input = {
      ...base,
      'settings': {
        'mode': settings['mode'],
        'windowBeforeMin': settings['windowBeforeMin'],
        'windowAfterMin': settings['windowAfterMin'],
      },
      'instruments': instruments,
    };
    input.remove('packId');
    input.remove('accountTypeId');
    final notes = <String>[];
    if (settings['mode'] == 'firm-match') {
      final pack = activePack;
      final account = settings['accountTypeId'] as String?;
      final hasAccount = pack != null &&
          account != null &&
          (pack['accountTypes'] as List).cast<Map<String, dynamic>>().any((a) => a['id'] == account);
      if (hasAccount && flags.firmMatch) {
        input['packId'] = settings['firmId'];
        input['accountTypeId'] = account;
      } else {
        input['settings'] = {...input['settings'] as Map<String, dynamic>, 'mode': 'conservative'};
        notes.add(!flags.firmMatch
            ? 'Firm match needs Pro: using conservative'
            : pack == null
                ? 'pack not downloaded yet: using conservative'
                : 'pick an account type: using conservative');
      }
    }
    final result = RuleEngine((id) => _packs.packs[id] ?? (throw StateError('no pack $id'))).computeWindows(input);
    _engineNotes = [...notes, ...result.notes];
    return [...result.windows]..sort((a, b) => a.opensAtUtc.compareTo(b.opensAtUtc));
  }

  Duration? get syncAge => _payload == null ? null : DateTime.now().toUtc().difference(_payload!.fetchedAtUtc);

  void update(SyncPayload payload) {
    _payload = payload;
    _localSettings = null;
    _localInstruments = null;
    notifyListeners();
  }

  void applySettings(Map<String, dynamic> patch) {
    _localSettings = {...settings, ...patch};
    notifyListeners();
  }

  void applyInstruments(List<Map<String, dynamic>> instruments) {
    _localInstruments = List.unmodifiable(instruments);
    notifyListeners();
  }

  void setGatedApps(List<String> ids) {
    _gatedAppIds = List.unmodifiable(ids);
    notifyListeners();
  }

  void setPermissions(Map<GuardPermission, bool> status) {
    _permissions = Map.unmodifiable(status);
    notifyListeners();
  }

  void markOnboarded() {
    _onboarded = true;
    notifyListeners();
  }

  void setPacks(PackCache packs, {RulesChanged? changed}) {
    _packs = packs;
    if (changed != null) _rulesChanged = changed;
    notifyListeners();
  }

  void clearRulesChanged() {
    _rulesChanged = null;
    notifyListeners();
  }

  void setTracker(Tracker t) {
    _tracker = t;
    notifyListeners();
  }

  /// Self-report: the latest entry for this window changes outcome in place.
  /// Returns the amended entry, or null when there was nothing to amend.
  GateOutcome? amendJournal(String windowId, String outcome) {
    final i = _journal.indexWhere((e) => e.windowId == windowId);
    if (i < 0) return null;
    final old = _journal[i];
    final amended = GateOutcome(windowId: old.windowId, outcome: outcome, atUtc: old.atUtc);
    _journal[i] = amended;
    notifyListeners();
    return amended;
  }

  void addJournal(Iterable<GateOutcome> outcomes) {
    if (outcomes.isEmpty) return;
    _journal.insertAll(0, outcomes);
    _journal.sort((a, b) => b.atUtc.compareTo(a.atUtc));
    if (_journal.length > 1000) _journal.removeRange(1000, _journal.length);
    notifyListeners();
  }

  /// Restore from the device store. Replaces what's in memory.
  void restoreJournal(Iterable<GateOutcome> outcomes) {
    _journal
      ..clear()
      ..addAll(outcomes)
      ..sort((a, b) => b.atUtc.compareTo(a.atUtc));
    notifyListeners();
  }

  /// Pro: consecutive local days, ending today or yesterday, on which a gate
  /// was shown and nothing was traded anyway. Zero when the last such day had
  /// a trade in the window, or there is no journal yet.
  int streak(DateTime nowLocal) {
    if (_journal.isEmpty) return 0;
    final byDay = <String, bool>{}; // day -> clean
    for (final e in _journal) {
      final day = Tracker.dateKey(e.atUtc.toLocal());
      byDay[day] = (byDay[day] ?? true) && e.outcome != 'traded-anyway';
    }
    var day = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    var key = Tracker.dateKey(day);
    if (!byDay.containsKey(key)) {
      day = day.subtract(const Duration(days: 1));
      key = Tracker.dateKey(day);
    }
    var n = 0;
    while (byDay[key] == true) {
      n++;
      day = day.subtract(const Duration(days: 1));
      key = Tracker.dateKey(day);
    }
    return n;
  }
}

class GuardScope extends InheritedNotifier<GuardState> {
  const GuardScope({super.key, required GuardState state, required super.child}) : super(notifier: state);

  static GuardState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GuardScope>();
    assert(scope != null, 'GuardScope missing above this widget');
    return scope!.notifier!;
  }
}
