// Renders the app's main screens to PNGs with the real fonts, for design
// reviews (docs/REDESIGN-BRIEF-Grok.md). Not part of the test suite:
//
//   flutter test tool/screenshots_test.dart --update-goldens
//
// Output lands in tool/shots/ (ignored); copy to docs/redesign/shots/ to publish. Clock pinned to 08:51 UTC on 1 Oct 2026, four
// minutes before the sample XAUUSD window for EUR CPI opens.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guard_app/features/tracker.dart';
import 'package:guard_app/gate/gate_screen.dart';
import 'package:guard_app/main.dart';
import 'package:guard_app/onboarding/onboarding_flow.dart';
import 'package:guard_app/platform/platform_bridge.dart';
import 'package:guard_app/screens/digest_screen.dart';
import 'package:guard_app/screens/journal_screen.dart';
import 'package:guard_app/screens/paywall_screen.dart';
import 'package:guard_app/screens/settings_screen.dart';
import 'package:guard_app/screens/tracker_screen.dart';
import 'package:guard_app/screens/windows_screen.dart';
import 'package:guard_app/state/guard_controller.dart';
import 'package:guard_app/state/guard_state.dart';

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  final clock = DateTime.utc(2026, 10, 1, 8, 51);

  setUpAll(() async {
    await _font('Poppins', ['Regular', 'Medium', 'SemiBold', 'Bold'].map((w) => 'assets/fonts/Poppins-$w.ttf').toList());
    await _font('Inter', ['assets/fonts/Inter-Variable.ttf']);
    final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
    await _font('MaterialIcons', ['$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    await _font('Roboto', ['$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf']);
  });

  (GuardState, GuardController) world({bool onboarded = true}) {
    final state = GuardState(onboarded: onboarded, now: () => clock);
    final controller = GuardController(state: state, bridge: FakeBridge(), now: () => clock);
    state.setTracker(Tracker(
      currency: '\$',
      dailyLossLimit: 2500,
      minTradingDays: 4,
      startDate: '2026-09-28',
      entries: const [
        PnlEntry(date: '2026-09-29', amount: 340),
        PnlEntry(date: '2026-09-30', amount: -180),
        PnlEntry(date: '2026-10-01', amount: -620),
      ],
    ));
    state.addJournal([
      GateOutcome(windowId: 'w1', outcome: 'stayed-out', atUtc: DateTime.utc(2026, 9, 30, 12, 31)),
      GateOutcome(windowId: 'w2', outcome: 'viewed', atUtc: DateTime.utc(2026, 9, 29, 8, 57)),
    ]);
    return (state, controller);
  }

  Future<void> shot(WidgetTester tester, String name, Widget? home, {bool dark = true, bool onboarded = true, Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final (state, controller) = world(onboarded: onboarded);
    await tester.pumpWidget(GuardApp(state: state, controller: controller, home: home));
    await tester.pump(const Duration(seconds: 1));
    await expectLater(find.byType(GuardApp), matchesGoldenFile('shots/$name.png'));
  }

  Widget scaffold(Widget body) => Scaffold(body: SafeArea(child: body));

  testWidgets('home dark', (t) => shot(t, '01-home-dark', null));
  testWidgets('home light', (t) => shot(t, '02-home-light', null, dark: false));
  testWidgets('gate', (t) => shot(t, '03-gate-desktop-and-android', GateScreen(
        instrument: 'XAUUSD',
        events: 'CPI Flash Estimate y/y 09:00',
        closesAtUtc: DateTime.utc(2026, 10, 1, 9, 5),
        hardBlock: false,
        now: () => DateTime.utc(2026, 10, 1, 8, 58, 30),
        onStayOut: () {},
        onView: () {},
        onExpired: () {},
      )));
  testWidgets('windows', (t) => shot(t, '04-windows', scaffold(const WindowsScreen())));
  testWidgets('digest', (t) => shot(t, '05-digest', DigestScreen(now: DateTime.utc(2026, 9, 30, 19))));
  testWidgets('journal', (t) => shot(t, '06-journal', scaffold(const JournalScreen())));
  testWidgets('tracker', (t) => shot(t, '07-tracker', const TrackerScreen()));
  testWidgets('settings', (t) => shot(t, '08-settings', scaffold(const SettingsScreen())));
  testWidgets('paywall', (t) => shot(t, '09-paywall', const PaywallScreen()));
  testWidgets('onboarding', (t) => shot(t, '10-onboarding-step1', const OnboardingFlow(), onboarded: false));
  testWidgets('tablet home', (t) => shot(t, '11-home-tablet', null, size: const Size(1180, 820)));
}
