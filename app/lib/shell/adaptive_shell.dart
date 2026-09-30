import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'dart:async';

import '../notifications/notification_scheduler.dart';
import '../screens/digest_screen.dart';
import '../screens/home_screen.dart';
import '../screens/journal_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/windows_screen.dart';
import '../state/guard_controller.dart';
import '../theme/tokens.dart';
import '../ui/parts.dart';

/// The hub is designed in and built later. Its nav slot exists from day one so it
/// never looks bolted on, but it stays dark until the guard has users.
const bool kHubEnabled = false;

enum GuardTab {
  // Engineering names stay; the trader sees the labels (docs/redesign/grok-final).
  home('Home', 'nav-home'),
  windows('Today', 'nav-today'),
  journal('Log', 'nav-log'),
  settings('Settings', 'nav-settings'),
  profile('Profile', 'nav-home');

  const GuardTab(this.label, this.icon);

  final String label;

  /// The SVG in assets/icons, drawn in the current colour.
  final String icon;

  static List<GuardTab> get visible =>
      values.where((t) => t != GuardTab.profile || kHubEnabled).toList();
}

class _NavIcon extends StatelessWidget {
  const _NavIcon(this.tab, {required this.selected});

  final GuardTab tab;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Shade.of(context).accent : Shade.of(context).muted;
    return SvgPicture.asset('assets/icons/${tab.icon}.svg',
        width: 24, height: 24, colorFilter: ColorFilter.mode(color, BlendMode.srcIn));
  }
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
  StreamSubscription<NotificationTap>? _opens;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = ControllerScope.of(context);
    if (_opens == null) {
      _opens = c.opens.stream.listen(_open);
      final waiting = c.lastTap;
      if (waiting != null) WidgetsBinding.instance.addPostFrameCallback((_) => _open(waiting));
    }
  }

  @override
  void dispose() {
    _opens?.cancel();
    super.dispose();
  }

  /// A notification tap: rungs land on Today, the night before alert on Tomorrow's news.
  void _open(NotificationTap tap) {
    if (!mounted) return;
    ControllerScope.of(context).consumeTap();
    if (tap.isDigest) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DigestScreen()));
    } else if (tap.isRung) {
      setState(() => _tab = GuardTab.windows);
    } else {
      setState(() => _tab = GuardTab.home);
    }
  }

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
                NavigationDestination(icon: _NavIcon(t, selected: false), selectedIcon: _NavIcon(t, selected: true), label: t.label),
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
                NavigationRailDestination(icon: _NavIcon(t, selected: false), selectedIcon: _NavIcon(t, selected: true), label: Text(t.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    });
  }
}
