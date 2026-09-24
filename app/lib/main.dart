import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'billing/billing.dart';
import 'desktop/desktop_shell.dart';
import 'gate/desktop_gate.dart';
import 'notifications/ladder_mirror.dart';
import 'notifications/notification_scheduler.dart';
import 'notifications/push_registrar.dart';
import 'notifications/reminders.dart';
import 'onboarding/onboarding_flow.dart';
import 'platform/platform_bridge.dart';
import 'shell/adaptive_shell.dart';
import 'state/guard_controller.dart';
import 'state/guard_state.dart';
import 'sync/api_client.dart';
import 'sync/sync_service.dart';
import 'sync/sync_store.dart';
import 'theme/tokens.dart';

/// Backend base URL, e.g. --dart-define=GUARD_API=https://guard.example.com.
/// Empty means no backend: the app runs on sample data.
const String kApiBaseUrl = String.fromEnvironment('GUARD_API');
const String kAppVersion = '0.1.0';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = GuardState();
  final store = SyncStore(await getApplicationSupportDirectory());
  final api = kApiBaseUrl.isEmpty ? null : ApiClient(baseUrl: kApiBaseUrl);
  final scheduler = LocalNotificationScheduler.supported ? LocalNotificationScheduler() : FakeScheduler();
  final controller = GuardController(
    state: state,
    bridge: MethodChannelBridge(),
    api: api,
    store: store,
    sync: api == null
        ? null
        : SyncService(
            api: api,
            store: store,
            platform: defaultTargetPlatform.name.toLowerCase(),
            tz: DateTime.now().timeZoneName,
            appVersion: kAppVersion,
          ),
    mirror: LadderMirror(scheduler),
    reminders: ReminderPlanner(scheduler),
    // Firebase registration replaces this once the project's config files exist.
    push: FakeRegistrar(),
    // Store billing replaces this with the store accounts; the backend rejects
    // fake receipts unless GUARD_RECEIPT_VERIFIER=fake.
    billing: FakeBilling(),
  );
  final navigatorKey = GlobalKey<NavigatorState>();
  if (DesktopShell.isDesktop) {
    await DesktopShell().init(appName: 'Guard', appVersion: kAppVersion);
    DesktopGate(controller: controller, navigatorKey: navigatorKey).start();
  }
  runApp(GuardApp(state: state, controller: controller, navigatorKey: navigatorKey));
  unawaited(controller.start());
}

class GuardApp extends StatefulWidget {
  const GuardApp({super.key, this.state, this.controller, this.navigatorKey, this.home});

  final GuardState? state;
  final GuardController? controller;
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Tests swap the root for a single screen.
  final Widget? home;

  @override
  State<GuardApp> createState() => _GuardAppState();
}

class _GuardAppState extends State<GuardApp> {
  late final GuardState _state = widget.state ?? GuardState(onboarded: true);
  late final GuardController _controller =
      widget.controller ?? GuardController(state: _state, bridge: FakeBridge(supported: const {}));

  @override
  Widget build(BuildContext context) {
    return ControllerScope(
      controller: _controller,
      child: GuardScope(
        state: _state,
        child: MaterialApp(
          navigatorKey: widget.navigatorKey,
          title: 'Guard',
          debugShowCheckedModeBanner: false,
          theme: GuardTheme.light(),
          darkTheme: GuardTheme.dark(),
          themeMode: ThemeMode.system,
          home: widget.home ?? const _Root(),
        ),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    return GuardScope.of(context).onboarded ? const AdaptiveShell() : const OnboardingFlow();
  }
}
