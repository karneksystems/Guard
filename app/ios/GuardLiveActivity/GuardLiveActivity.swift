import ActivityKit
import SwiftUI
import WidgetKit

/// The Lock Screen countdown and its Dynamic Island.
/// Boards: docs/redesign/grok-final/phone/lock-*.png and di-*.png. Copy:
/// COPY.md, Live Activity. Colours follow app/lib/theme/tokens.dart: ink
/// ground, sky an hour out and when clear, amber in the last five minutes,
/// red while the cover is on. System fonts on device; Poppins is in-app only.
@main
struct GuardLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        GuardLiveActivity()
    }
}

private enum Palette {
    static let ink = Color(red: 0x0C / 255, green: 0x14 / 255, blue: 0x22 / 255)
    static let brand = Color(red: 0x0B / 255, green: 0x5C / 255, blue: 0xAD / 255)
    static let sky = Color(red: 0x5B / 255, green: 0xC8 / 255, blue: 0xF5 / 255)
    static let amber = Color(red: 0xF5 / 255, green: 0xA5 / 255, blue: 0x24 / 255)
    static let red = Color(red: 0xE5 / 255, green: 0x48 / 255, blue: 0x4D / 255)
    static let text = Color(red: 0xED / 255, green: 0xF2 / 255, blue: 0xF8 / 255)
    static let muted = Color(red: 0x8B / 255, green: 0x9A / 255, blue: 0xAE / 255)
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

    /// "OPENS SOON".
    var kicker: String {
        switch phase {
        case .upcoming: return "IN 1 HOUR"
        case .soon: return "OPENS SOON"
        case .live: return "COVER ON"
        case .clear: return "ALL CLEAR"
        }
    }

    /// Dynamic Island compact word.
    var short: String {
        switch phase {
        case .upcoming: return "NEXT"
        case .soon: return "SOON"
        case .live: return "ON"
        case .clear: return "CLEAR"
        }
    }

    /// The line under the count. Carries the time as text too, so it still
    /// reads true if the app hasn't been open to move the phase on.
    func sub(_ what: String) -> String {
        switch phase {
        case .upcoming: return "\(what) · cover at \(Shown.hhmm(opens))"
        case .soon: return "\(what) · until cover starts"
        case .live: return "\(what) · until \(Shown.hhmm(closes))"
        case .clear: return "You're clear · trade at your pace"
        }
    }

    /// The span the system timer counts down, or nil when there's nothing to count.
    var countdown: ClosedRange<Date>? {
        switch phase {
        // The hour before a cover, then the cover itself. The system counts;
        // the app doesn't need to run.
        case .upcoming, .soon: return opens.addingTimeInterval(-3600)...opens
        case .live: return min(opens, closes)...closes
        case .clear: return nil
        }
    }

    static func hhmm(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "H:mm"
        return f.string(from: d)
    }
}

struct GuardLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GuardActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, shown: Shown(context.state, stale: context.isStale))
                .activityBackgroundTint(Palette.ink)
                .activitySystemActionForegroundColor(Palette.sky)
        } dynamicIsland: { context in
            let shown = Shown(context.state, stale: context.isStale)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(shown.kicker.capitalized)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(shown.colour)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Count(shown: shown, size: 22)
                        .frame(maxWidth: 80, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(shown.sub(context.attributes.events))
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                }
            } compactLeading: {
                Text(shown.short)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(shown.colour)
            } compactTrailing: {
                Count(shown: shown, size: 14)
                    .frame(maxWidth: 48)
            } minimal: {
                Image(systemName: "shield.lefthalf.filled").foregroundStyle(shown.colour)
            }
            .keylineTint(shown.colour)
        }
    }
}

/// The system timer in the phase colour, or "Clear".
private struct Count: View {
    let shown: Shown
    let size: CGFloat

    var body: some View {
        Group {
            if let span = shown.countdown {
                Text(timerInterval: span, countsDown: true)
            } else {
                Text("Clear")
            }
        }
        .font(.system(size: size, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(shown.colour)
        .multilineTextAlignment(.trailing)
    }
}

private struct LockScreenView: View {
    let attributes: GuardActivityAttributes
    let shown: Shown

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.sky)
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Palette.brand))
                Text("Guard")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.muted)
                Spacer()
                Text(shown.kicker)
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(shown.colour)
            }
            HStack(alignment: .center, spacing: 14) {
                Ring(shown: shown)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Count(shown: shown, size: 32)
                        .multilineTextAlignment(.leading)
                    Text(shown.sub(attributes.events))
                        .font(.subheadline)
                        .foregroundStyle(Palette.text.opacity(0.85))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16)
    }
}

/// A ring that empties with the system timer; a full sky ring when clear.
private struct Ring: View {
    let shown: Shown

    var body: some View {
        if let span = shown.countdown {
            ProgressView(timerInterval: span, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.circular)
            .tint(shown.colour)
        } else {
            Circle()
                .stroke(Palette.sky, lineWidth: 4)
                .padding(2)
        }
    }
}
