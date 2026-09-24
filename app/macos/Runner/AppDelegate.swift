import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // The gate needs the process alive; closing the window hides it (DesktopShell).
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
