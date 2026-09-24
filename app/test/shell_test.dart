import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guard_app/main.dart';
import 'package:guard_app/state/guard_state.dart';

Future<void> pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(GuardApp(state: GuardState(onboarded: true)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('phone width uses a bottom navigation bar', (tester) async {
    await pumpAt(tester, const Size(390, 844));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('NEXT WINDOW'), findsOneWidget);
  });

  testWidgets('tablet width uses a compact rail', (tester) async {
    await pumpAt(tester, const Size(768, 1024));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('desktop width uses an extended rail', (tester) async {
    await pumpAt(tester, const Size(1280, 800));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
  });

  testWidgets('the hub profile slot is hidden from navigation', (tester) async {
    await pumpAt(tester, const Size(390, 844));
    expect(find.text('Profile'), findsNothing);
    expect(find.text('Journal'), findsOneWidget);
  });

  testWidgets('the engine drives the home screen over sample data', (tester) async {
    await pumpAt(tester, const Size(390, 844));
    // EUR CPI at 09:00 opens 08:55 windows on both EURUSD and gold. Ties sort by
    // symbol, so the card shows EURUSD and gold's window is in the list below.
    expect(find.text('EURUSD'), findsOneWidget);
    expect(find.textContaining('XAUUSD'), findsWidgets);
    expect(find.textContaining('CPI Flash Estimate'), findsWidgets);
    // Chicago PMI is medium impact and must not open a window.
    expect(find.textContaining('Chicago PMI'), findsNothing);
  });
}
