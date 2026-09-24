import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Tray icon, close-to-tray, and start at login for Windows and macOS. The app
/// has to be running for the gate to work, so closing the window hides it.
class DesktopShell with TrayListener, WindowListener {
  static bool get isDesktop => !kIsWeb && (Platform.isWindows || Platform.isMacOS);

  Future<void> init({required String appName, required String appVersion}) async {
    if (!isDesktop) return;
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    await trayManager.setIcon(Platform.isWindows ? 'assets/tray/guard.ico' : 'assets/tray/guard.png');
    await trayManager.setToolTip(appName);
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'open', label: 'Open $appName'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quit'),
    ]));
    trayManager.addListener(this);

    try {
      launchAtStartup.setup(appName: appName, appPath: Platform.resolvedExecutable);
      if (!await launchAtStartup.isEnabled()) await launchAtStartup.enable();
    } on Exception {
      // Not fatal; the settings screen can offer it again.
    }
  }

  Future<void> show() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onWindowClose() async {
    // Hide, don't quit: the gate needs the process alive.
    await windowManager.hide();
  }

  @override
  void onTrayIconMouseDown() => show();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'open':
        await show();
      case 'quit':
        await windowManager.setPreventClose(false);
        await windowManager.close();
    }
  }
}
