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
        let instrument = window?.instrument ?? "your instrument"
        let events = (window?.events.isEmpty == false) ? window!.events : "a high-impact release"
        let closes = window.map { Date(timeIntervalSince1970: TimeInterval($0.closesAtMs) / 1000) }
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        let until = closes.map { fmt.string(from: $0) } ?? "the window ends"
        let hard = GateShared.protection == "hard-block"

        let ink = UIColor(red: 0.09, green: 0.09, blue: 0.10, alpha: 1)
        let metal = UIColor(red: 0.62, green: 0.55, blue: 0.40, alpha: 1)

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: ink,
            icon: UIImage(systemName: "shield.lefthalf.filled"),
            title: ShieldConfiguration.Label(text: "Restricted: \(instrument)", color: .white),
            subtitle: ShieldConfiguration.Label(
                text: "\(events). Stay out until \(until). We never touch your trades.",
                color: UIColor(white: 0.85, alpha: 1)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Stay out", color: .white),
            primaryButtonBackgroundColor: metal,
            secondaryButtonLabel: hard ? nil : ShieldConfiguration.Label(text: "View for 60 seconds", color: UIColor(white: 0.85, alpha: 1)))
    }
}
