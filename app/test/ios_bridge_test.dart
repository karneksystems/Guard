import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guard_app/platform/platform_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an iOS build without Screen Time has no gate and asks for notifications only', () async {
    final b = MethodChannelBridge(platform: TargetPlatform.iOS);
    await b.loadCapabilities(); // no native side here: treated as no Screen Time
    expect(b.hasGate, isFalse);
    expect(b.usesSystemPicker, isFalse);
    expect(b.supportedPermissions, {GuardPermission.notifications});
  });

  test('an iOS build with Screen Time has the gate, the system picker and the Screen Time permission', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('guard/gate'),
      (call) async => call.method == 'capabilities' ? {'screenTime': true} : null,
    );
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('guard/gate'), null));
    final b = MethodChannelBridge(platform: TargetPlatform.iOS);
    await b.loadCapabilities();
    expect(b.hasGate, isTrue);
    expect(b.usesSystemPicker, isTrue);
    expect(b.supportedPermissions, {GuardPermission.notifications, GuardPermission.screenTime});
  });

  test('desktop and Android gates do not depend on capabilities', () {
    expect(MethodChannelBridge(platform: TargetPlatform.android).usesSystemPicker, isFalse);
    expect(MethodChannelBridge(platform: TargetPlatform.macOS).hasGate, isTrue);
    expect(MethodChannelBridge(platform: TargetPlatform.linux).hasGate, isFalse);
  });

  test('pickApps and scheduleWindows go over guard/gate with the same shapes as Android', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('guard/gate'),
      (call) async {
        if (call.method == 'capabilities') return {'screenTime': true};
        calls.add(call);
        return switch (call.method) { 'pickApps' => true, 'scheduleWindows' => 1, _ => null };
      },
    );
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('guard/gate'), null));

    final b = MethodChannelBridge(platform: TargetPlatform.iOS);
    await b.loadCapabilities();
    expect(await b.pickApps(), isTrue);
    final n = await b.scheduleGateWindows(
      windows: const [GateWindowSpec(windowId: 'w1', opensAtMs: 1, closesAtMs: 2, instrument: 'XAUUSD', events: 'CPI')],
      gatedAppIds: const ['screen-time'],
      protection: 'soft-gate',
    );
    expect(n, 1);
    expect(calls.map((c) => c.method), ['pickApps', 'scheduleWindows']);
    final args = calls.last.arguments as Map;
    expect((args['windows'] as List).single, {'windowId': 'w1', 'opensAtMs': 1, 'closesAtMs': 2, 'instrument': 'XAUUSD', 'events': 'CPI'});
    expect(args['protection'], 'soft-gate');
  });

  test('a platform without the native side answers false and zero, never throws', () async {
    final b = MethodChannelBridge(platform: TargetPlatform.iOS);
    expect(await b.pickApps(), isFalse);
    expect(await b.scheduleGateWindows(windows: const [], gatedAppIds: const [], protection: 'soft-gate'), 0);
  });
}
