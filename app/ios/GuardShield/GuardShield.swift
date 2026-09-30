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

    /// docs/redesign/grok-final/COPY.md, iPhone Screen Time shield. Apple draws
    /// the card; we set colours, one icon, two lines and two buttons.
    private func card() -> ShieldConfiguration {
        let window = GateShared.currentWindow()
        // "Gold · EUR CPI", written by the app in the trader's words.
        let what = (window?.events.isEmpty == false) ? window!.events : "High impact news"
        let fmt = DateFormatter()
        fmt.dateFormat = "H:mm"
        let until = window
            .map { Date(timeIntervalSince1970: TimeInterval($0.closesAtMs) / 1000) }
            .map { " until \(fmt.string(from: $0))" } ?? ""
        let hard = GateShared.protection == "hard-block"

        // app/lib/theme/tokens.dart: brandDeep, sky, amber, ink text.
        let navy = UIColor(red: 0x08 / 255, green: 0x30 / 255, blue: 0x6B / 255, alpha: 1)
        let sky = UIColor(red: 0x5B / 255, green: 0xC8 / 255, blue: 0xF5 / 255, alpha: 1)
        let amber = UIColor(red: 0xF5 / 255, green: 0xA5 / 255, blue: 0x24 / 255, alpha: 1)
        let ink = UIColor(red: 0xED / 255, green: 0xF2 / 255, blue: 0xF8 / 255, alpha: 1)
        let icon = UIImage(systemName: "shield.lefthalf.filled")?
            .withTintColor(sky, renderingMode: .alwaysOriginal)

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: navy,
            icon: icon,
            title: ShieldConfiguration.Label(text: "Stay out of your trading app", color: ink),
            subtitle: ShieldConfiguration.Label(text: "\(what)\(until). We never touch your trades.", color: sky),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Stay out", color: navy),
            primaryButtonBackgroundColor: amber,
            // A shield button is a tap, not a hold, so on iPhone it says what it does.
            secondaryButtonLabel: hard ? nil : ShieldConfiguration.Label(text: "Look for 60 seconds", color: sky))
    }
}
