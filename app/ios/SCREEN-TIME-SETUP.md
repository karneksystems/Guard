# iOS Screen Time gate: the Xcode steps

No longer needed for builds: `scripts/screen_time.rb` adds the three extension
targets on the build machine (the native CI job and the TestFlight workflow
both run it), so the gate compiles without a Mac. The manual steps below stay
for anyone who wants the targets in their own Xcode.

Bundle ids: the App IDs registered on 23 Sep 2026 with Family Controls
(Development) are `com.stanchion.wideberth` plus `.monitor`, `.shieldconfig`
and `.shieldaction` (D13). The project still carries the placeholder
`com.stanchion.guardApp`. Either set the Runner bundle id to the registered one
and name the extensions to match, or register four new App IDs under the final
product name first. The team-level entitlement covers either.

1. Open `ios/Runner.xcworkspace`. Select the Runner project, Signing and
   Capabilities on the Runner target: add App Groups with
   `group.com.stanchion.guard`, and Family Controls. `Runner/Runner.entitlements`
   already lists both plus time-sensitive notifications.
2. File, New, Target, three times:
   - Device Activity Monitor Extension, product name `GuardMonitor`.
   - Shield Configuration Extension, product name `GuardShield`.
   - Shield Action Extension, product name `GuardShieldAction`.
   Do not activate the schemes when asked. Delete the template Swift file Xcode
   generates in each and instead add the files from `ios/GuardMonitor/`,
   `ios/GuardShield/` and `ios/GuardShieldAction/` to the matching target. Point
   each target's Info.plist and entitlements build settings at the files in its
   folder.
3. Add `ios/Shared/GateShared.swift` to all three extension targets (it is
   already in Runner). Target membership, tick the box.
4. On each extension target: App Groups `group.com.stanchion.guard`, Family
   Controls, deployment target iOS 16.0.
5. Build on a device. The simulator cannot run Screen Time extensions.

What to expect on a development build: authorisation prompt on the permissions
screen, Apple's picker from Settings, Gated apps, the shield at window open
(up to fifteen minutes before close on a short window, the DeviceActivity
minimum), Stay out closes it, View for 60 seconds lifts it and the monitor puts
it back after a minute of use. Journal entries drain into the app on next open.

Distribution needs Apple's answer on the team-level Family Controls request
submitted 23 Sep 2026. Until then TestFlight builds with the distribution
entitlement will be refused at upload.
