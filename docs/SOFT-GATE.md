# Soft gate

Pre-build deliverable 3. The gate is the product. Everything here works with the
network off.

## Behaviour, all platforms

State machine per gated app:

```
idle ──window opens──► armed ──gated app comes to front──► shown
shown ──Stay out──► armed          shown ──View──► viewing (60 s) ──► shown if still open
any ──window closes──► idle
```

Gate content: countdown to window end, event names, instrument, the line "We never
touch your trades", Stay out as the primary action, Hold to view only as the
secondary (on iOS, View for 60 seconds). Source strip at the bottom. No ads, ever.

Journal: each shown gate writes one entry, outcome stayed-out or viewed. The user can
later change it to traded-anyway by hand. Warn only mode never shows the gate. Hard
block (Pro) is the same gate with no view option; on iOS it's the shield without the
secondary button.

## Android

Trigger. An exact alarm at opens_at starts GateService, a foreground service of
type specialUse with the notification "Restricted window open, watching for MT5".
The service polls UsageStatsManager.queryEvents over the last two seconds, once a
second, and on the way into an armed state (window open, or a view's minute up) it
checks who is in front right now, so a trader already sitting in MT5 gets the
gate. On a gated package coming to the front it launches the gate Activity over
the trading app. That launch is allowed from a service only when "display over
other apps" is granted; without it the service posts a full-screen-intent
notification instead, which the OS turns into the gate on a locked or idle screen
and a heads-up otherwise. At closes_at the service stops itself.

If SCHEDULE_EXACT_ALARM is denied, the fallback is an inexact alarm with a
ten-minute window, and Android 12+ refuses a foreground-service start from an
inexact alarm. The receiver catches that and posts a loud notification asking the
user to open the app, which re-arms the schedule from the foreground. The banner
on Home already says exact alarms are off. A permission flip cancels every exact
alarm, so the boot receiver also listens for that broadcast and re-arms.

Permissions in onboarding, each with one plain screen explaining why:
PACKAGE_USAGE_STATS (special access page), SYSTEM_ALERT_WINDOW, SCHEDULE_EXACT_ALARM
(Alarms and reminders page), USE_FULL_SCREEN_INTENT (Manage full screen intents
page), and the battery optimisation page. Play declarations: specialUse foreground
service with description and demo video, full-screen intent, overlay.

Default gated packages: net.metaquotes.metatrader5, net.metaquotes.metatrader4. The
user can add cTrader, TradingView or a broker app from the installed-apps list.
Split screen counts as foreground. Tablet is identical.

## Windows

The tray app registers at login (user can turn it off). Two hooks, both installed
once and cheap when idle: a WMI __InstanceCreationEvent subscription on Win32_Process
for terminal64.exe, terminal.exe and ctrader.exe, and SetWinEventHook on
EVENT_SYSTEM_FOREGROUND filtered by the foreground window's process name.

During a window, a gated process launching or gaining focus shows the gate: a
borderless topmost window sized to the monitor holding the MT5 window
(MonitorFromWindow), taking focus once. Stay out minimises MT5 (ShowWindow
SW_MINIMIZE) and closes the gate. Hold to view hides the gate for 60 seconds. Outside
windows the hook callbacks return immediately.

Nothing inside MT5. No injection, no reading its windows or memory, process name
only. Multi-monitor: the gate goes on MT5's monitor, not the primary. Several MT5
instances: gate on whichever gained focus.

## iOS and iPadOS

Onboarding: AuthorizationCenter.shared.requestAuthorization(for: .individual), then
FamilyActivityPicker to choose the trading app or apps. The selection is stored as
ApplicationTokens in the app group container shared with the extensions. We never
learn which apps they are.

Scheduling: for each window, a DeviceActivitySchedule from opens_at to closes_at is
registered with DeviceActivityCenter. There's a cap of 20 active schedules, so the app
registers the next 20 windows and rolls forward on each sync. The
DeviceActivityMonitor extension sets ManagedSettingsStore.shield.applications to the
tokens in intervalDidStart and clears it in intervalDidEnd. This runs with the app
killed.

The card: the ShieldConfiguration extension returns the title (event and instrument),
subtitle (window end time plus "We never touch your trades"), icon, primary "Stay
out", secondary "View for 60 seconds". The ShieldAction extension handles taps:
primary closes the shield; secondary removes the token from the shield store,
registers a 60-second DeviceActivity interval whose end re-applies the shield, then
returns. Both extensions can write to the app group, so the journal entry is written
from the card.

Limits: no live countdown on the card, no custom layout, no hold gesture. The
Family Controls distribution entitlement is needed on the app and all three
extensions. Development builds work without it.

A sync that lands inside a window (or its lead time) shields at once from the app
and registers a schedule long enough for the OS to accept, so on a short remainder
the lift can be up to fifteen minutes late; a shield that never lifts was the
alternative. Re-registering only touches windows that changed: stopping an
activity never fires intervalDidEnd, so a blanket stop would strand the shield.

Two more limits found in the build (D14). DeviceActivity refuses an interval
under fifteen minutes, so a five-and-five window is monitored from fifteen
minutes before it closes: the shield can arrive early, never late, and the card
still names the true window. And an extension can't run a sixty-second timer, so
"View for 60 seconds" is five usage-threshold events registered with the window
(60, 120, 180, 240, 300 seconds of use of the gated apps); each one that fires
re-applies the shield, which gives five views per window. The app's code for all
of this is in `app/ios/Runner/ScreenTimeGate.swift` and the three folders under
`app/ios/`; the Xcode target setup is in `app/ios/SCREEN-TIME-SETUP.md`.

## macOS

Tray app via the same tray plugin as Windows, login item via launch_at_startup.
NSWorkspace's didLaunchApplicationNotification and didActivateApplicationNotification,
filtered by bundle id, plus a one-second check of the frontmost app so a trader
already in MT5 at window open gets the gate. The gate is the Flutter window raised
to screen-saver level on the trading app's screen; Stay out hides the trading app;
lowering restores the window's old frame and hides it. Screen Time isn't available
to third-party Mac apps.
