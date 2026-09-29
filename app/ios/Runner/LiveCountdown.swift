import ActivityKit
import Flutter
import Foundation

/// Starts, updates and ends the Lock Screen countdown for Dart, over the
/// guard/live channel. One activity at a time: a new window replaces the old
/// one. Everything is a no-op unless the build embeds the GuardLiveActivity
/// extension (Info.plist GuardLiveActivity) and the phone is on iOS 16.2+.
final class LiveCountdown {
    private let channel: FlutterMethodChannel

    static var enabled: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "GuardLiveActivity") as? String) == "YES"
    }

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "guard/live", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "available":
            if #available(iOS 16.2, *) {
                result(Self.enabled && ActivityAuthorizationInfo().areActivitiesEnabled)
            } else {
                result(false)
            }
        case "sync":
            guard Self.enabled, #available(iOS 16.2, *), let args = call.arguments as? [String: Any] else {
                result(false)
                return
            }
            Task {
                let shown = await Self.sync(args)
                await MainActor.run { result(shown) }
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    @available(iOS 16.2, *)
    private static func sync(_ args: [String: Any]) async -> Bool {
        let phase = GuardActivityPhase(rawValue: args["phase"] as? String ?? "clear") ?? .clear
        let running = Activity<GuardActivityAttributes>.activities

        guard phase != .clear,
              let windowId = args["windowId"] as? String,
              let opensMs = args["opensAtMs"] as? Int,
              let closesMs = args["closesAtMs"] as? Int
        else {
            // All clear: show it for a few minutes, then let it go.
            for activity in running {
                var state = activity.content.state
                state.phase = GuardActivityPhase.clear.rawValue
                await activity.end(
                    ActivityContent(state: state, staleDate: nil),
                    dismissalPolicy: .after(Date().addingTimeInterval(5 * 60)))
            }
            return false
        }

        let opens = Date(timeIntervalSince1970: TimeInterval(opensMs) / 1000)
        let closes = Date(timeIntervalSince1970: TimeInterval(closesMs) / 1000)
        let state = GuardActivityAttributes.ContentState(phase: phase.rawValue, opensAt: opens, closesAt: closes)
        // Stale at the next boundary, so the view can move on without the app.
        let content = ActivityContent(state: state, staleDate: phase == .live ? closes : opens)

        if let same = running.first(where: { $0.attributes.windowId == windowId }) {
            await same.update(content)
            return true
        }
        for other in running {
            await other.end(nil, dismissalPolicy: .immediate)
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        let attributes = GuardActivityAttributes(
            windowId: windowId,
            instrument: args["instrument"] as? String ?? "",
            events: args["events"] as? String ?? "High impact news")
        do {
            _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
            return true
        } catch {
            return false
        }
    }
}
