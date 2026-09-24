import Cocoa
import FlutterMacOS

/// The macOS half of the Soft gate. NSWorkspace tells us when an app activates
/// or launches; if it's a gated bundle id inside an open window, Dart shows the
/// gate screen and this raises the window over it. Stay out hides the trading
/// app. Nothing else touches it. Screen Time isn't available to third-party
/// Mac apps, so this is the whole gate (docs/SOFT-GATE.md, macOS).
final class GateWatcher {
    private struct Window {
        let id: String
        let opensAtMs: Int64
        let closesAtMs: Int64
    }

    private let channel: FlutterMethodChannel
    private weak var host: NSWindow?
    private var windows: [Window] = []
    private var gated: Set<String> = ["net.metaquotes.metatrader5"]
    private var protection = "soft-gate"
    private var viewingUntilMs: Int64 = 0
    private var lastShownMs: Int64 = 0
    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?
    private var savedFrame: NSRect?
    private var armed = false

    private static let known: [(id: String, label: String)] = [
        ("net.metaquotes.metatrader5", "MetaTrader 5"),
        ("net.metaquotes.metatrader4", "MetaTrader 4"),
        ("com.spotware.ctrader", "cTrader"),
        ("com.tradingview.tradingviewapp.desktop", "TradingView"),
    ]

    init(messenger: FlutterBinaryMessenger, host: NSWindow) {
        self.host = host
        channel = FlutterMethodChannel(name: "guard/gate", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didLaunchApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                self?.consider(app)
            })
        }
        // The trader may already be in MT5 when a window opens or a view runs out:
        // a one-second check of the frontmost app covers what notifications miss.
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let canAct = self.openWindow(at: Self.nowMs()) != nil && Self.nowMs() >= self.viewingUntilMs
            if canAct && !self.armed, let front = NSWorkspace.shared.frontmostApplication {
                self.consider(front)
            }
            self.armed = canAct
        }
    }

    deinit {
        timer?.invalidate()
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }

    private func openWindow(at now: Int64) -> Window? {
        guard protection != "warn-only" else { return nil }
        return windows.first { now >= $0.opensAtMs && now < $0.closesAtMs }
    }

    private static func nowMs() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

    private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "listApps":
            result(Self.known.map { app -> [String: Any] in
                [
                    "id": app.id,
                    "label": app.label,
                    "installed": NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.id) != nil,
                ]
            })
        case "scheduleWindows":
            let raw = args["windows"] as? [[String: Any]] ?? []
            windows = raw.compactMap { w in
                guard let id = w["windowId"] as? String, let o = w["opensAtMs"] as? NSNumber, let c = w["closesAtMs"] as? NSNumber else { return nil }
                return Window(id: id, opensAtMs: o.int64Value, closesAtMs: c.int64Value)
            }
            let incoming = Set((args["gatedPackages"] as? [String] ?? []).map { $0.lowercased() })
            if !incoming.isEmpty { gated = incoming } // an empty list never ungates everything by accident
            protection = args["protection"] as? String ?? "soft-gate"
            result(windows.count)
        case "setViewingUntil":
            viewingUntilMs = (args["untilMs"] as? NSNumber)?.int64Value ?? 0
            result(nil)
        case "raiseGate":
            raiseGate(pid: (args["handle"] as? NSNumber)?.int32Value)
            result(nil)
        case "lowerGate":
            lowerGate()
            result(nil)
        case "stayOut":
            if let pid = (args["handle"] as? NSNumber)?.int32Value, let app = NSRunningApplication(processIdentifier: pid) {
                app.hide()
            }
            lowerGate()
            result(nil)
        case "drainJournal":
            result([]) // the gate is a Flutter screen; Dart records outcomes
        case "pickApps":
            result(false)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func consider(_ app: NSRunningApplication) {
        guard let bundle = app.bundleIdentifier?.lowercased(), gated.contains(bundle) else { return }
        let now = Self.nowMs()
        if now < viewingUntilMs || now - lastShownMs < 1500 { return }
        guard let open = openWindow(at: now) else { return }
        lastShownMs = now
        channel.invokeMethod("gateTriggered", arguments: [
            "windowId": open.id,
            "handle": Int(app.processIdentifier),
            "process": bundle,
        ])
    }

    private func raiseGate(pid: Int32?) {
        guard let host = host else { return }
        if savedFrame == nil { savedFrame = host.frame }
        // The trading app's screen, if we can find it; the main screen otherwise.
        // Quartz window bounds are top-left origin on the primary display, so the
        // flip uses the primary screen's height for every candidate, and the
        // window's centre rather than a corner that can sit just off-screen.
        var screen = NSScreen.main
        if let pid = pid,
           let primary = NSScreen.screens.first,
           let info = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]])?
               .first(where: { ($0[kCGWindowOwnerPID as String] as? Int32) == pid }),
           let dict = info[kCGWindowBounds as String] as? NSDictionary,
           let bounds = CGRect(dictionaryRepresentation: dict) {
            let centre = NSPoint(x: bounds.midX, y: primary.frame.maxY - bounds.midY)
            screen = NSScreen.screens.first { NSPointInRect(centre, $0.frame) } ?? screen
        }
        if let frame = screen?.frame {
            host.setFrame(frame, display: true)
        }
        host.level = .screenSaver
        host.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        host.makeKeyAndOrderFront(nil)
        if #available(macOS 14.0, *) {
            // Sonoma ignores a bare activate unless the current app yields.
            if let front = NSWorkspace.shared.frontmostApplication, front != NSRunningApplication.current {
                NSRunningApplication.current.activate(from: front, options: [.activateIgnoringOtherApps])
            } else {
                NSApp.activate()
            }
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Back to the tray: the window lives hidden, at its old size, not in the Dock.
    private func lowerGate() {
        guard let host = host else { return }
        host.level = .normal
        host.collectionBehavior = []
        if let frame = savedFrame {
            host.setFrame(frame, display: false)
            savedFrame = nil
        }
        host.orderOut(nil)
    }
}
