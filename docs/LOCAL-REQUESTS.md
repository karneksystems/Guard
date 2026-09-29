# Local requests

Things only the account holder can do, written so a local Claude session can
do them with Jamie's OK and report back. Tick each one off here when it's done,
with the date, and tell the cloud session so it can run the build that needs it.

## Open

### 1. Apple Developer: App IDs for the news cover and the Lock Screen countdown

Asked for on 29 September 2026. Nothing here touches a trading account, and no
key or password needs to leave the Apple Developer site.

Where: developer.apple.com, Account, Certificates, Identifiers and Profiles,
Identifiers. Team: the one that owns `com.stanchion.guard`.

**a. The App Group.** Identifiers, the filter at the top right set to App
Groups, then the plus button. Description `Guard`, identifier
`group.com.stanchion.guard`. Skip this if it already exists.

**b. The main app.** Open `com.stanchion.guard` and tick:

- Family Controls (Distribution)
- App Groups, then Configure and choose `group.com.stanchion.guard`

Leave Push Notifications and Time Sensitive Notifications as they are. Save,
and accept the warning that profiles will be regenerated (CI makes new ones).

**c. Three Screen Time extensions.** For each, the plus button, App IDs, App,
explicit Bundle ID:

| Description | Bundle ID | Capabilities |
|---|---|---|
| Guard Monitor | `com.stanchion.guard.monitor` | Family Controls (Distribution), App Groups (`group.com.stanchion.guard`) |
| Guard Shield | `com.stanchion.guard.shieldconfig` | Family Controls (Distribution), App Groups (`group.com.stanchion.guard`) |
| Guard Shield Action | `com.stanchion.guard.shieldaction` | Family Controls (Distribution), App Groups (`group.com.stanchion.guard`) |

App Groups needs the Configure step on each one too, or the extensions can't
read the schedule the app writes.

**d. The Lock Screen countdown.** Same steps:

| Description | Bundle ID | Capabilities |
|---|---|---|
| Guard Live Activity | `com.stanchion.guard.liveactivity` | None |

Live Activities need no capability on the App ID; the app says it supports
them in its Info.plist.

**Done when** all five identifiers show in the list and the four Family
Controls ones show Family Controls (Distribution) and App Groups as enabled.

**Then** the cloud session runs the TestFlight workflow with both boxes
ticked, "Include the Screen Time gate" and "Include the Lock Screen
countdown". If only d is done, it ticks the countdown box alone.

If Family Controls (Distribution) can't be ticked on an extension ID, stop
and say so. That means Apple's approval covered the main app only, and the
fix is a second request naming the extension IDs, not a workaround.

## Done

Nothing yet.
