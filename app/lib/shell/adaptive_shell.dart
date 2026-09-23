import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import '../screens/journal_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/windows_screen.dart';
import '../theme/tokens.dart';

/// The hub is designed in and built later. Its nav slot exists from day one so it
/// never looks bolted on, but it stays dark until the guard has users.
const bool kHubEnabled = false;

enum GuardTab {
  home('Home', Icons.shield_outlined, Icons.shield),
  windows('Windows', Icons.schedule_outlined, Icons.schedule),
  journal('Journal', Icons.notes_outlined, Icons.notes),
  settings('Settings', Icons.tune_outlined, Icons.tune),
  profile('Profile', Icons.person_outline, Icons.person);

  const GuardTab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  static List<GuardTab> get visible =>
      values.where((t) => t != GuardTab.profile || kHubEnabled).toList();
}

/// One shell, three compositions: bottom bar under 600 dp, a compact rail to
/// 840 dp, an extended rail above. The screens are the same widgets throughout.
class AdaptiveShell extends StatefulWidget {
  const AdaptiveShell({super.key});

  @override
  State<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends State<AdaptiveShell> {
  GuardTab _tab = GuardTab.home;

  Widget _screen(GuardTab tab) => switch (tab) {
        GuardTab.home => const HomeScreen(),
        GuardTab.windows => const WindowsScreen(),
        GuardTab.journal => const JournalScreen(),
        GuardTab.settings => const SettingsScreen(),
        GuardTab.profile => const ProfileScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final tabs = GuardTab.visible;
    final index = tabs.indexOf(_tab);

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final body = SafeArea(child: _screen(_tab));

      if (width < Tokens.compactMax) {
        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => _tab = tabs[i]),
            destinations: [
              for (final t in tabs)
                NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selectedIcon), label: t.label),
            ],
          ),
        );
      }

      final extended = width >= Tokens.mediumMax;
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 200,
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => _tab = tabs[i]),
            labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            destinations: [
              for (final t in tabs)
                NavigationRailDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selectedIcon), label: Text(t.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    });
  }
}
