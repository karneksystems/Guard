import 'package:flutter/widgets.dart';
import 'package:rule_engine/rule_engine.dart';

import '../data/sample_data.dart';
import '../sync/sync_payload.dart';

/// What the screens read. Either a synced payload or, before the first sync and
/// in tests, the sample data. Windows are always computed on the device by the
/// engine, so the gate works with the network off.
class GuardState extends ChangeNotifier {
  GuardState({this._payload, this._userId = 'device'});

  SyncPayload? _payload;
  final String _userId;

  SyncPayload? get payload => _payload;
  bool get isSample => _payload == null;
  bool get pro => _payload?.pro ?? false;

  Map<String, dynamic> get settings => _payload?.settings ?? SampleData.settings;
  List<Map<String, dynamic>> get instruments => _payload?.instruments ?? SampleData.instruments;

  String titleFor(String eventId) => _payload?.titleFor(eventId) ?? SampleData.titleFor(eventId);

  /// Windows in time order, computed by the device engine.
  List<Window> get windows {
    final input = _payload?.engineInput(_userId) ?? SampleData.engineInput();
    final result = RuleEngine((_) => throw StateError('packs arrive with M8')).computeWindows(input);
    return [...result.windows]..sort((a, b) => a.opensAtUtc.compareTo(b.opensAtUtc));
  }

  Duration? get syncAge => _payload == null ? null : DateTime.now().toUtc().difference(_payload!.fetchedAtUtc);

  void update(SyncPayload payload) {
    _payload = payload;
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
