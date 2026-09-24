import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var gate: GateWatcher?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    gate = GateWatcher(messenger: flutterViewController.engine.binaryMessenger, host: self)

    super.awakeFromNib()
  }
}
