import Flutter
import UIKit
import UserNotifications

#if canImport(FamilyControls)
import FamilyControls
import DeviceActivity
import ManagedSettings
import SwiftUI
#endif

/// The iOS side of guard/gate and guard/permissions. The gate itself is
/// Apple's Screen Time shield, applied by the GuardMonitor extension; this
/// class only authorises, lets the user pick apps, and registers schedules.
final class ScreenTimeGate {
    init(messenger: FlutterBinaryMessenger, controller: FlutterViewController?) {
        // The controller passed at engine init is not yet anyone's root view
        // controller (and never AppDelegate.window's under the scene lifecycle),
        // so the presenter is resolved at call time instead.
        FlutterMethodChannel(name: "guard/gate", binaryMessenger: messenger).setMethodCallHandler { [weak self] call, result in
            self?.handleGate(call, result)
        }
        FlutterMethodChannel(name: "guard/permissions", binaryMessenger: messenger).setMethodCallHandler { [weak self] call, result in
            self?.handlePermissions(call, result)
        }
    }

    // MARK: guard/gate

    private func handleGate(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        switch call.method {
        case "listApps":
            result([[
                "id": "screen-time",
                "label": "Apps chosen in Screen Time",
                "installed": GateShared.selectionData != nil,
            ]])
        case "pickApps":
            pickApps(result)
        case "scheduleWindows":
            let args = call.arguments as? [String: Any] ?? [:]
            let raw = args["windows"] as? [[String: Any]] ?? []
            let windows = raw.compactMap { w -> GateShared.Window? in
                guard let id = w["windowId"] as? String,
                      let opens = w["opensAtMs"] as? NSNumber,
                      let closes = w["closesAtMs"] as? NSNumber else { return nil }
                return GateShared.Window(
                    windowId: id,
                    opensAtMs: opens.int64Value,
                    closesAtMs: closes.int64Value,
                    instrument: w["instrument"] as? String ?? "",
                    events: w["events"] as? String ?? "")
            }
            GateShared.windows = windows
            GateShared.protection = args["protection"] as? String ?? "soft-gate"
            result(schedule(windows))
        case "drainJournal":
            result(GateShared.drainJournal().map { ["windowId": $0.windowId, "outcome": $0.outcome, "atMs": $0.atMs] })
        case "raiseGate", "lowerGate", "stayOut", "setViewingUntil":
            result(nil) // desktop only
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Registers the next twenty windows as DeviceActivity schedules. Warn
    /// only, no selection, or no authorisation means nothing is monitored.
    private func schedule(_ windows: [GateShared.Window]) -> Int {
        #if canImport(FamilyControls)
        guard #available(iOS 16.0, *) else { return 0 }
        let center = DeviceActivityCenter()
        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(GateShared.storeName))
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let wanted = Set(windows.filter { $0.closesAtMs > nowMs }.map { $0.windowId })

        // Stopping an activity never fires intervalDidEnd, so only the ones that
        // are no longer wanted go, and the active set and the shield follow.
        let monitored = Set(center.activities.map { $0.rawValue })
        let dropped = monitored.subtracting(wanted)
        if !dropped.isEmpty { center.stopMonitoring(dropped.map { DeviceActivityName($0) }) }
        let armed = GateShared.protection != "warn-only"
            && GateShared.selectionData != nil
            && AuthorizationCenter.shared.authorizationStatus == .approved
        if !armed {
            center.stopMonitoring()
            GateShared.activeWindowIds = []
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            return 0
        }
        var active = GateShared.activeWindowIds.filter { wanted.contains($0) }

        let upcoming = windows.filter { $0.closesAtMs > nowMs }.sorted { $0.opensAtMs < $1.opensAtMs }.prefix(20)
        var tokens = Set<ApplicationToken>()
        var categories = Set<ActivityCategoryToken>()
        if let data = GateShared.selectionData, let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            tokens = sel.applicationTokens
            categories = sel.categoryTokens
        }
        var count = 0
        for w in upcoming {
            if monitored.contains(w.windowId) {
                count += 1
                continue // already registered; leave it alone
            }
            let closes = Date(timeIntervalSince1970: TimeInterval(w.closesAtMs) / 1000)
            var opens = Date(timeIntervalSince1970: TimeInterval(w.opensAtMs) / 1000)
            if closes.timeIntervalSince(opens) < GateShared.minimumIntervalSeconds {
                opens = closes.addingTimeInterval(-GateShared.minimumIntervalSeconds)
            }
            var end = closes
            if opens < Date() {
                // Synced inside the window (or its lead time): shield now from the app,
                // and register a schedule long enough to be accepted so the extension
                // lifts it. On a short remainder the lift can be up to fifteen minutes
                // late, which beats a shield that never lifts.
                opens = Date().addingTimeInterval(5)
                if end.timeIntervalSince(opens) < GateShared.minimumIntervalSeconds {
                    end = opens.addingTimeInterval(GateShared.minimumIntervalSeconds)
                }
                if w.opensAtMs <= nowMs {
                    store.shield.applications = tokens.isEmpty ? nil : tokens
                    store.shield.applicationCategories = categories.isEmpty ? nil : ShieldSettings.ActivityCategoryPolicy.specific(categories)
                    if !active.contains(w.windowId) { active.append(w.windowId) }
                }
            }
            let cal = Calendar.current
            let comps: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
            let schedule = DeviceActivitySchedule(
                intervalStart: cal.dateComponents(comps, from: opens),
                intervalEnd: cal.dateComponents(comps, from: end),
                repeats: false)
            var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
            if GateShared.protection == "soft-gate", !tokens.isEmpty {
                for seconds in GateShared.viewEventSeconds {
                    events[DeviceActivityEvent.Name("view\(seconds)")] =
                        DeviceActivityEvent(applications: tokens, threshold: DateComponents(second: seconds))
                }
            }
            do {
                try center.startMonitoring(DeviceActivityName(w.windowId), during: schedule, events: events)
                count += 1
            } catch {
                // Cap reached or a bad interval: the ladder still fires; the gate doesn't.
            }
        }
        GateShared.activeWindowIds = active
        if active.isEmpty {
            store.shield.applications = nil
            store.shield.applicationCategories = nil
        }
        return count
        #else
        return 0
        #endif
    }

    /// The view controller to present from, right now.
    private func presenter() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    /// Apple's picker. The selection is stored as tokens in the app group. We
    /// never see bundle ids.
    private func pickApps(_ result: @escaping FlutterResult) {
        #if canImport(FamilyControls)
        guard #available(iOS 16.0, *), let host = presenter() else { return result(false) }
        var selection = FamilyActivitySelection()
        if let data = GateShared.selectionData, let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selection = sel
        }
        let picker = PickerHost(selection: selection) { picked in
            if let picked = picked {
                GateShared.selectionData = try? JSONEncoder().encode(picked)
            }
            host.dismiss(animated: true) {
                result(picked != nil)
            }
        }
        let vc = UIHostingController(rootView: picker)
        vc.modalPresentationStyle = .formSheet
        host.present(vc, animated: true)
        #else
        result(false)
        #endif
    }

    // MARK: guard/permissions

    private func handlePermissions(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        switch call.method {
        case "status":
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                var status: [String: Bool] = [
                    "notifications": settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional,
                ]
                #if canImport(FamilyControls)
                if #available(iOS 16.0, *) {
                    status["screenTime"] = AuthorizationCenter.shared.authorizationStatus == .approved
                } else {
                    status["screenTime"] = false
                }
                #else
                status["screenTime"] = false
                #endif
                DispatchQueue.main.async { result(status) }
            }
        case "request":
            let name = (call.arguments as? [String: Any])?["name"] as? String
            switch name {
            case "notifications":
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive]) { _, _ in
                    DispatchQueue.main.async { result(nil) }
                }
            case "screenTime":
                #if canImport(FamilyControls)
                if #available(iOS 16.0, *) {
                    Task {
                        try? await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                        await MainActor.run { result(nil) }
                    }
                } else {
                    result(nil)
                }
                #else
                result(nil)
                #endif
            default:
                result(nil)
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

#if canImport(FamilyControls)
@available(iOS 16.0, *)
private struct PickerHost: View {
    @State var selection: FamilyActivitySelection
    let done: (FamilyActivitySelection?) -> Void

    var body: some View {
        NavigationView {
            FamilyActivityPicker(selection: $selection)
                .navigationTitle("Apps to gate")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { done(nil) } }
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { done(selection) } }
                }
        }
    }
}
#endif
