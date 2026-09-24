import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation

/// Applies the shield when a window's interval starts, lifts it when the last
/// open window ends, and re-applies it when a "view" usage threshold is hit.
/// Runs with the app killed. Never sees which apps the tokens are.
final class GuardMonitor: DeviceActivityMonitor {
    private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(GateShared.storeName))

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        var active = GateShared.activeWindowIds
        if !active.contains(activity.rawValue) { active.append(activity.rawValue) }
        GateShared.activeWindowIds = active
        applyShield()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        var active = GateShared.activeWindowIds
        active.removeAll { $0 == activity.rawValue }
        GateShared.activeWindowIds = active
        if active.isEmpty {
            store.shield.applications = nil
            store.shield.applicationCategories = nil
        }
    }

    /// A view's sixty seconds of use are up.
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        if GateShared.activeWindowIds.contains(activity.rawValue) {
            applyShield()
        }
    }

    private func applyShield() {
        guard let data = GateShared.selectionData,
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : ShieldSettings.ActivityCategoryPolicy.specific(selection.categoryTokens)
    }
}
