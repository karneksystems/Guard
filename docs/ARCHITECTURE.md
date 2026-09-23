# Architecture

Pre-build deliverable 1 from the total brief, Part C. Working name Wideberth.

## Shape

One Flutter app with four targets: Android, iOS and iPadOS, Windows, macOS. One
Laravel backend. Native code in exactly four places, where Flutter can't reach: the
Android gate service (Kotlin), the Windows gate hooks (C++ plugin), the iOS Screen
Time extensions (Swift app-extension targets in the same Xcode project), and a small
macOS activation watcher (Swift). Everything else, the rule engine included, is Dart
and shared.

```
Calendar vendor ──► Backend: calendar sync ──► events
                                                 │
App ◄──────────► Backend API (auth, settings, packs, event feed, devices, ladder)
                                                 │
                    Backend: ladder scheduler ──► APNs / FCM / socket / WNS ──► devices
                                                                                  │
                                              device: local mirror fires if push misses
                                              device: gate module watches MT5 during windows
```

## App

Flutter 3.38 on Dart 3.13. Riverpod for state, Drift over SQLite for the local store, go_router for
navigation. Layout is adaptive by width class: compact under 600 dp, medium 600 to
840, expanded above. The tablet home and the desktop home are the same screens
composed differently, not a stretched phone layout.

The local store holds settings, instruments and baskets, the next 14 days of events
and computed windows, the ladder for the next 48 hours, and journal entries. The app
works offline for anything already synced. The gate never needs the network.

Native modules:

- Android gate service, Kotlin. Exact alarm at window open starts a foreground
  service of type specialUse that polls UsageStatsManager once a second, shows the
  overlay when a gated package comes to the front, and stops at window end. No
  always-on service. Detail in `SOFT-GATE.md`.
- Windows gate plugin, C++. WMI process-start subscription for terminal64.exe and
  terminal.exe, SetWinEventHook for foreground changes, and a topmost full-screen
  Flutter window on the monitor MT5 is on. Tray icon via tray_manager, windows via
  window_manager.
- iOS Screen Time, Swift. Three extensions: DeviceActivityMonitor,
  ShieldConfiguration, ShieldAction. The main app requests individual authorisation
  and presents FamilyActivityPicker.
- macOS, Swift. NSWorkspace notifications and a floating panel.

Notifications: firebase_messaging for FCM and APNs registration,
flutter_local_notifications for the mobile mirror, a C++ shim over WinRT
ToastNotificationManager for Windows with a registered AUMID, UNUserNotificationCenter
on macOS.

Design tokens come from `DESIGN-CONCEPTS-Grok.md`: Poppins display, Inter body, metal
accent #AE9558, champagne hairlines, flat metal buttons, no greens anywhere including
status chips. Tokens live in one Dart file and nowhere else.

## Backend

Laravel 13 on PHP 8.4 with Octane. Postgres for data, Redis for queues and cache,
Horizon for workers and delayed jobs. Hosted beside Karnek's existing infrastructure.
It's small: a calendar mirror, a rule-pack index, a device registry and a scheduler.

Services:

- Calendar sync. Pulls the vendor feed every 15 minutes for the next 14 days, and
  every 60 seconds inside the two hours around any high-impact event, because vendors
  revise times. Normalises into the events table, diffs against the previous pull,
  emits event.changed for anything whose time, impact or currency moved.
- Rule packs. JSON files in the repo, validated in CI against the schema, published
  to object storage with a signed version index. The app fetches the index daily and
  packs on demand. Detail in `RULE-ENGINE.md`.
- Ladder scheduler. On any change to a user's basket, window default or mode, on
  event.changed, and on a nightly sweep, recompute that user's windows for the next
  48 hours and reconcile the ladder: create missing rungs, cancel rungs whose event
  moved, leave the rest. Each rung is a delayed Horizon job keyed by alert id. Detail
  in `PUSH-ARCHITECTURE.md`.
- Device registry. Device id, platform, push token, validity, timezone, app version,
  notification permission state, last seen. Prunes tokens the providers reject.
- Pro entitlement. Apple and Google receipts validated server-side, one flag per
  user with an expiry. Desktop Pro comes from the same account. No separate desktop
  billing at launch.

REST over HTTPS with short-lived JWTs. Accounts are anonymous and device-bound by
default, with optional email sign-in to link devices. No trading credentials exist
anywhere in the system. There is no column for them and no endpoint that accepts one.

## Data model, core tables

```
users        id, email?, pro_until?, tz, created_at
devices      id, user_id, platform, push_token?, token_valid, tz, app_version, notif_state, last_seen
instruments  id, user_id, symbol, basket_currencies[]
settings     user_id, mode, protection, window_before_min, window_after_min, quiet_hours?, digest_local_time
events       id, vendor_id, currency, title, impact, scheduled_at_utc, revised_from_utc?, source, fetched_at
windows      id, user_id, instrument_id, opens_at_utc, closes_at_utc, reasons[] (event ids), verified
rungs        alert_id, user_id, window_id, kind, fire_at_utc, state, provider_msg_id?
journal      id, user_id, window_id, device_id, outcome, at_utc
profiles     user_id, handle?, avatar?, visibility          (hub skeleton, dark at launch)
firm_packs_index  firm_id, version, url, sha256
```

Packs are files, not rows. Gated app identifiers (package names, process names,
Apple tokens) live on the device only.

## Time

Everything stored and computed in UTC. Displayed in device local time. Settings hold
an optional broker server offset with a DST rule so the event list can show a second
line in MT5 chart time, because that's the clock the trader is looking at. If the
device timezone and the account timezone differ by more than an hour, Home shows a
warning. The mirror schedules on UTC instants (time-interval triggers on iOS,
RTC_WAKEUP alarms on Android), so a device timezone change doesn't move a rung.

## Distribution

Android: Play, with declarations for the specialUse foreground service (description
and demo video), USE_FULL_SCREEN_INTENT, SYSTEM_ALERT_WINDOW and PACKAGE_USAGE_STATS.
iOS: App Store, after the Family Controls entitlement is granted for the app and each
of the three extensions. Windows: MSIX signed with the existing certificate, sideload
from the product site first, Microsoft Store when WNS is wanted. macOS: notarised
DMG first, Mac App Store later.

## Privacy

The device knows which app the user chose to gate, as a package or process name on
Android and Windows and as an opaque token on iOS. None of that goes to the backend.
The backend sees instruments, settings, device tokens and any journal outcome the
user chose to record. No account numbers, no firm logins, no trade data, no
screenshots. The privacy policy says exactly this.

## Running cost lines

- Calendar vendor. See `CALENDAR-VENDORS.md`.
- Push. APNs, FCM and WNS are free.
- Backend. One small VM plus managed Postgres and Redis, or a slot on Karnek's hosts.
- Stores. Apple Developer Programme yearly, Google Play one-off, Microsoft Partner
  Center one-off. Code-signing certificate already held.
