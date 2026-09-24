import ManagedSettings
import Foundation

/// Button taps on the card. Stay out closes the shield and writes the journal.
/// View lifts the shield for that app; the GuardMonitor extension re-applies
/// it after sixty seconds of use through the pre-registered usage events.
final class GuardShieldAction: ShieldActionDelegate {
    private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(GateShared.storeName))

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let windowId = GateShared.currentWindow()?.windowId ?? "unknown"
        switch action {
        case .primaryButtonPressed:
            GateShared.appendJournal(windowId: windowId, outcome: "stayed-out")
            completionHandler(.close)
        case .secondaryButtonPressed:
            if GateShared.protection == "hard-block" {
                completionHandler(.close)
                return
            }
            GateShared.appendJournal(windowId: windowId, outcome: "viewed")
            var apps = store.shield.applications ?? []
            apps.remove(application)
            store.shield.applications = apps.isEmpty ? nil : apps
            // .defer makes the system re-read the store and drop the card; .none would
            // leave the card up with the token already gone.
            completionHandler(.defer)
        @unknown default:
            completionHandler(.close)
        }
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let windowId = GateShared.currentWindow()?.windowId ?? "unknown"
        switch action {
        case .primaryButtonPressed:
            GateShared.appendJournal(windowId: windowId, outcome: "stayed-out")
            completionHandler(.close)
        case .secondaryButtonPressed:
            if GateShared.protection == "hard-block" {
                completionHandler(.close)
                return
            }
            GateShared.appendJournal(windowId: windowId, outcome: "viewed")
            store.shield.applicationCategories = nil
            completionHandler(.defer)
        @unknown default:
            completionHandler(.close)
        }
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }
}
