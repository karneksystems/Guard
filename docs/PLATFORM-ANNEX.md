# Wideberth, platform annex

Companion to `TOTAL-BRIEF-Prop-News-Guard.md`, which wins on product. This file is the
short version of what each OS allows for the two locked behaviours, Soft gate and
push. The long versions are `SOFT-GATE.md` and `PUSH-ARCHITECTURE.md`. 23 Sep 2026.

## Locked (from the total brief)

- Phone, tablet and desktop all in scope. Shared codebase preferred.
- Soft gate is the default protection mode. Same behaviour on every device.
- Push is required on every surface. Server-scheduled ladder: T-60, T-15, T-5, T-1,
  open, end. Local-only reminders are not accepted as the primary mechanism.
- MVP track: Android phone and tablet Soft gate plus push, then Windows desktop Soft
  gate plus push, then iOS and iPad push with Soft gate as far as allowed, then packs,
  then stores.
- Never touches a trade. Never logs into an account. Never runs on a terminal.

## Devices

| Surface | Soft gate | Push channel | Track |
|---|---|---|---|
| Android phone and tablet | Full. UsageStats foreground detection, overlay, short-lived service | FCM high priority, full-screen intent, alarm repeat | MVP 1 |
| Windows desktop | Full. MT5 launch and focus hooks, topmost gate on MT5's monitor | Notification centre toasts over the app's socket, WNS once on the Store | MVP 2 |
| iPhone and iPad | Screen Time shield, Apple's card, "View for 60 seconds" | APNs Time Sensitive | MVP 3 |
| macOS | NSWorkspace activation, own panel | APNs for Mac, socket fallback | Post-launch |

## Soft gate, what each OS allows

Android. Foreground app via UsageStatsManager with the PACKAGE_USAGE_STATS special
access, granted once in Settings. An exact alarm at window open starts a foreground
service of type specialUse that polls once a second and stops at window end. Gate is
a SYSTEM_ALERT_WINDOW overlay. MT5 is net.metaquotes.metatrader5, MT4 is
net.metaquotes.metatrader4. Do not use AccessibilityService (D5). Play needs a
declaration for the specialUse service (description plus a demo video), for
USE_FULL_SCREEN_INTENT, and for the overlay. Samsung, Xiaomi and OnePlus battery
managers can still delay the alarm; onboarding sends the user to the battery page
and the home screen shows a banner until it's done.

Windows. MT5 is terminal64.exe, MT4 is terminal.exe. Launch via a WMI process-start
subscription, focus via SetWinEventHook on EVENT_SYSTEM_FOREGROUND. Gate is a
topmost, full-screen window on the monitor MT5 is on. Own tray app (D4). Nothing
inside MT5, no injection, process name only.

iOS and iPadOS. No API reports another app launching or gaining focus. The one legal
route is the Screen Time stack: FamilyControls with individual authorisation,
ManagedSettings shields, DeviceActivity schedules. The user picks MT5 in Apple's
picker (the token is opaque, we never learn the bundle id). A DeviceActivityMonitor
extension applies the shield at window open and lifts it at window end, and it runs
with the app killed. The card is Apple's template: title, subtitle, icon, one or two
buttons. Hold-to-view isn't possible, so the secondary button is "View for 60
seconds" (D7). Needs the Family Controls distribution entitlement on the app and
each of its three extensions. Request text is in `APPLE-ENTITLEMENT-REQUEST.md`.
File it this week.

macOS. NSWorkspace didLaunchApplicationNotification and
didActivateApplicationNotification give launch and focus for MetaTrader 5.app. Gate
is a floating panel. The app runs as a menu-bar agent and login item. Screen Time
shields aren't available to third-party Mac apps.

## Push, what each OS allows

The ladder is scheduled on the server against the calendar and the user's basket.
Each rung carries an alert id. Every device mirrors the ladder as OS-scheduled local
notifications with the same ids (D1). Remote is primary because it reacts to
calendar revisions and rule edits. Local is the safety net because delivery isn't
guaranteed anywhere.

iOS. APNs with interruption level time-sensitive, which needs the
com.apple.developer.usernotifications.time-sensitive entitlement. Breaks through
Focus when the user allows it. Critical Alerts need a separate Apple approval that
trading apps don't get. Not planned.

Android. FCM high-priority data message wakes the app from Doze. Full-screen intent
needs USE_FULL_SCREEN_INTENT, which on Android 14 and later is granted by default
only to alarm and calling apps; everyone else sends the user to the "Manage full
screen intents" page via ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT and checks
NotificationManager.canUseFullScreenIntent. Exact alarms for the mirror need
SCHEDULE_EXACT_ALARM, also user-granted on 14 and later, with a setWindow fallback.

Windows. Tray app holds a socket to the backend, raises toasts through the
notification centre with a registered AUMID, and registers scheduled toasts for the
mirror so rungs fire even if the app is closed. WNS raw push is added when the MSIX
has Store identity (D11).

macOS. APNs works for signed, notarised Mac apps that have launched once. Socket
fallback identical to Windows.

## Cost lines to price before build

- Calendar API licence. See `CALENDAR-VENDORS.md`. The only line that scales badly.
- Push: APNs, FCM and WNS are free. The scheduler and its database are yours.
- Apple Developer Programme, Google Play, Microsoft Partner Center, and the
  code-signing certificate already held for MTBridge.

## Open

- Trademark search for Wideberth and Keepclear (UKIPO, EUIPO, USPTO, classes 9, 36,
  42). Buy wideberth.app and widebirth.app together; the misspelling is common.
- Family Controls entitlement request date.
- Calendar vendor quotes.
