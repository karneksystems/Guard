import ActivityKit
import SwiftUI
import WidgetKit

/// The Lock Screen countdown and its Dynamic Island. Colours follow
/// app/lib/theme/tokens.dart: navy ground, sky while news is an hour out,
/// amber in the last five minutes, red while the window is open.
@main
struct GuardLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        GuardLiveActivity()
    }
}

private enum Palette {
    static let navy = Color(red: 0x08 / 255, green: 0x30 / 255, blue: 0x6B / 255)
    static let sky = Color(red: 0x5B / 255, green: 0xC8 / 255, blue: 0xF5 / 255)
    static let amber = Color(red: 0xF5 / 255, green: 0xA5 / 255, blue: 0x24 / 255)
    static let red = Color(red: 0xE5 / 255, green: 0x48 / 255, blue: 0x4D / 255)
    static let muted = Color(red: 0xA9 / 255, green: 0xBC / 255, blue: 0xD3 / 255)
}

/// What the view shows once staleness is taken into account.
private struct Shown {
    let phase: GuardActivityPhase
    let opens: Date
    let closes: Date

    init(_ state: GuardActivityAttributes.ContentState, stale: Bool) {
        let phase = GuardActivityPhase(rawValue: state.phase) ?? .upcoming
        self.phase = stale ? phase.next : phase
        opens = state.opensAt
        closes = state.closesAt
    }

    var colour: Color {
        switch phase {
        case .upcoming, .clear: return Palette.sky
        case .soon: return Palette.amber
        case .live: return Palette.red
        }
    }

    var symbol: String {
        switch phase {
        case .live: return "exclamationmark.shield.fill"
        case .clear: return "checkmark.shield.fill"
        default: return "shield.lefthalf.filled"
        }
    }

    var label: String {
        switch phase {
        case .upcoming, .soon: return "News window opens in"
        case .live: return "Stay out. Trading reopens at \(Shown.hhmm(closes))"
        case .clear: return "All clear, trading has reopened"
        }
    }

    /// The span the system timer counts down, or nil when there's nothing to count.
    var countdown: ClosedRange<Date>? {
        switch phase {
        // The hour before a window, then the window itself. The system counts;
        // the app doesn't need to run.
        case .upcoming, .soon: return opens.addingTimeInterval(-3600)...opens
        case .live: return min(opens, closes)...closes
        case .clear: return nil
        }
    }

    static func hhmm(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }
}

struct GuardLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GuardActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, shown: Shown(context.state, stale: context.isStale))
                .activityBackgroundTint(Palette.navy)
                .activitySystemActionForegroundColor(Palette.sky)
        } dynamicIsland: { context in
            let shown = Shown(context.state, stale: context.isStale)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: shown.symbol).foregroundStyle(shown.colour).font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let span = shown.countdown {
                        Text(timerInterval: span, countsDown: true)
                            .monospacedDigit()
                            .foregroundStyle(shown.colour)
                            .frame(maxWidth: 72)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.events).font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.attributes.instrument). \(shown.label)")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: shown.symbol).foregroundStyle(shown.colour)
            } compactTrailing: {
                if let span = shown.countdown {
                    Text(timerInterval: span, countsDown: true)
                        .monospacedDigit()
                        .foregroundStyle(shown.colour)
                        .frame(maxWidth: 44)
                }
            } minimal: {
                Image(systemName: shown.symbol).foregroundStyle(shown.colour)
            }
            .keylineTint(shown.colour)
        }
    }
}

private struct LockScreenView: View {
    let attributes: GuardActivityAttributes
    let shown: Shown

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: shown.symbol)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(shown.colour)
                VStack(alignment: .leading, spacing: 2) {
                    Text(attributes.events)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(attributes.instrument). \(shown.label)")
                        .font(.subheadline)
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if let span = shown.countdown {
                    Text(timerInterval: span, countsDown: true)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(shown.colour)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 96, alignment: .trailing)
                }
            }
            if let span = shown.countdown {
                ProgressView(timerInterval: span, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(shown.colour)
            }
        }
        .padding(16)
    }
}
