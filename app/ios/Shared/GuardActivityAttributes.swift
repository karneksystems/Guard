import ActivityKit
import Foundation

/// The Lock Screen countdown. Shared by Runner, which starts and updates it,
/// and the GuardLiveActivity widget extension, which draws it.
///
/// Until push-to-start exists the app can only change the activity while it
/// runs, so the view does two things on its own: the countdowns are system
/// timers, and when the activity goes stale (staleDate is set to the next
/// boundary) the view moves to the next phase by itself. That covers the
/// most important change, amber to red when the window opens, with the app
/// closed.
@available(iOS 16.1, *)
struct GuardActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// upcoming (sky), soon (amber), live (red) or clear (sky).
        var phase: String
        var opensAt: Date
        var closesAt: Date
    }

    var windowId: String
    var instrument: String
    /// "US CPI 13:30", local time.
    var events: String
}

enum GuardActivityPhase: String {
    case upcoming, soon, live, clear

    /// What the phase becomes once its staleDate passes.
    var next: GuardActivityPhase {
        switch self {
        case .upcoming, .soon: return .live
        case .live, .clear: return .clear
        }
    }
}
