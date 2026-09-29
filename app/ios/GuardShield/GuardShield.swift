import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The card. Apple's template: title, subtitle, icon, one or two buttons.
/// Same words as the Android and Windows gates. Hard block hides the second
/// button. Colours follow app/lib/theme/tokens.dart.
final class GuardShield: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        card()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        card()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        card()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        card()
    }

    private func card() -> ShieldConfiguration {
        let window = GateShared.currentWindow()
        let instrument = window?.instrument ?? "Your instrument"
        let events = (window?.events.isEmpty == false) ? window!.events : "High impact news"
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        let reopens = window
            .map { Date(timeIntervalSince1970: TimeInterval($0.closesAtMs) / 1000) }
            .map { "Trading reopens at \(fmt.string(from: $0))." } ?? "Trading reopens when the news window ends."
        let hard = GateShared.protection == "hard-block"

        // app/lib/theme/tokens.dart: brandDeep, sky, amber.
        let navy = UIColor(red: 0x08 / 255, green: 0x30 / 255, blue: 0x6B / 255, alpha: 1)
        let sky = UIColor(red: 0x5B / 255, green: 0xC8 / 255, blue: 0xF5 / 255, alpha: 1)
        let amber = UIColor(red: 0xF5 / 255, green: 0xA5 / 255, blue: 0x24 / 255, alpha: 1)
        let icon = UIImage(systemName: "exclamationmark.shield.fill")?
            .withTintColor(amber, renderingMode: .alwaysOriginal)

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: navy,
            icon: icon,
            title: ShieldConfiguration.Label(text: events, color: .white),
            subtitle: ShieldConfiguration.Label(
                text: "\(instrument) is in a news window. \(reopens) We never touch your trades.",
                color: sky),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Stay out", color: navy),
            primaryButtonBackgroundColor: amber,
            secondaryButtonLabel: hard ? nil : ShieldConfiguration.Label(text: "View for 60 seconds", color: sky))
    }
}
