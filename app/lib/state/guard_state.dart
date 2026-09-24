import 'package:flutter/widgets.dart';
import 'package:rule_engine/rule_engine.dart';

import '../data/sample_data.dart';
import '../platform/platform_bridge.dart';
import '../sync/sync_payload.dart';

/// What the screens read. Either a synced payload or, before the first sync and
/// in tests, the sample data. Windows are always computed on the device by the
/// engine, so the gate works with the network off.
class GuardState extends ChangeNotifier {
  GuardState({this._payload, this._userId = 'device', this._onboarded = false});

  SyncPayload? _payload;
  final String _userId;
  bool _onboarded;

  Map<String, dynamic>? _localSettings;
  List<Map<String, dynamic>>? _localInstruments;
  List<String> _gatedAppIds = const ['net.metaquotes.metatrader5'];
  Map<GuardPermission, bool> _permissions = const {};

  SyncPayload? get payload => _payload;
  bool get isSample => _payload == null;
  bool get pro => _payload?.pro ?? false;
  bool get onboarded => _onboarded;

  /// Local edits win over the last payload until the next sync replaces both.
  Map<String, dynamic> get settings => _localSettings ?? _payload?.settings ?? SampleData.settings;
  List<Map<String, dynamic>> get instruments =>
      _localInstruments ?? _payload?.instruments ?? SampleData.instruments;
  List<String> get gatedAppIds => _gatedAppIds;
  Map<GuardPermission, bool> get permissions => _permissions;

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
    // Firm match needs packs, which arrive with M8; until then compute conservatively.
    input.remove('packId');
    input.remove('accountTypeId');
    if (input['settings']['mode'] == 'firm-match') {
      input['settings'] = {...input['settings'] as Map<String, dynamic>, 'mode': 'conservative'};
    }
    final result = RuleEngine((_) => throw StateError('packs arrive with M8')).computeWindows(input);
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
}

class GuardScope extends InheritedNotifier<GuardState> {
  const GuardScope({super.key, required GuardState state, required super.child}) : super(notifier: state);

  static GuardState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GuardScope>();
    assert(scope != null, 'GuardScope missing above this widget');
    return scope!.notifier!;
  }
}
