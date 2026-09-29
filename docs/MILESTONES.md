# Milestones

Pre-build deliverable 6. Order follows the total brief. Durations assume one senior
developer working with Claude Code full time, and they're honest, not optimistic.
Adding a second developer parallelises M4 and M5.

| # | Milestone | Exit criteria | Weeks |
|---|---|---|---|
| M0 | Pre-build | These docs signed off. Name cleared. Vendor quotes in. Family Controls request filed. | 1 |
| M1 | Skeleton | Flutter app builds on all four targets. Backend up with calendar sync from the chosen vendor. Rule engine passes the shared fixture set on device and server. Profile object and hidden hub nav slot exist. | 3 |
| M2 | Onboarding and settings | Three-step onboarding. Every setting editable afterwards. Permissions flow on Android complete with the banner logic. | 1 |
| M3 | Push and ladder | Server ladder with reconcile. APNs and FCM live. Local mirror on both. T-1 lands within 5 seconds of schedule on a test fleet of ten devices over a week of real events. | 2 |
| M4 | Android Soft gate | Gate shows on MT5 foreground during a window on phone and tablet, on Samsung, Pixel and Xiaomi test devices, with the app killed beforehand. Journal writes. | 2 |
| M5 | Windows tray app | Gate on MT5 launch and focus, on MT5's monitor. Toasts over the socket. Scheduled toasts fire with the app closed. MSIX signed and installing clean. | 3 |
| M6 | Free features | Digest, journal, weekend warning, daily-loss tracker, minimum-days countdown, inactivity reminder, source strip. On phone, tablet and Windows. | 2 |
| M7 | iOS gate | Shield applies and lifts on schedule with the app killed. View for 60 seconds works. Blocked on the entitlement, so it floats. | 2 |
| M8 | Pro | IAP and Play billing, receipt validation, flags. Five seed packs verified by a human with lastVerified set. Custom windows, hard block, journal history, ads off. | 2 |
| M9 | Stores | Play declarations and video. App Store review. Product site with the MSIX download. Privacy policy and terms live. Disclaimers in-app. | 2 |

Twenty weeks end to end for one person, and M7 can't start until Apple replies. If
the entitlement arrives late, ship Android and Windows first with iOS on push-only,
which the brief already allows.

Watch items: the Play declarations for the specialUse service and full-screen intent
are the most likely review bounce, so record the demo video during M4, not M9.

## Status, 24 September 2026

What CI proves is that it compiles and the logic holds under test. Nothing has run
on a device. "Built" below means that; "done" waits on a device pass.

| # | Built | Waiting on |
|---|---|---|
| M0 | Docs, packs, schema, fixtures, entitlement request filed | Name, vendor quotes, pack sources read |
| M1 | App on four targets, backend with fake vendor and Trading Economics adapter, both engines pass the ten fixtures, profile and hub slot | Vendor key |
| M2 | Three-step onboarding (29 Sep: what you trade, alerts and apps, you're set), every setting editable, Android permission flow and banner | Device pass |
| M3 | Server ladder with reconcile, APNs and FCM senders, local mirror, silent resync push, quiet hours | APNs key, Firebase project, the ten-device week |
| M4 | Exact alarm, specialUse service, native gate, journal drain | Samsung, Pixel, Xiaomi pass; Play video |
| M5 | Win32 watcher, tray, start at login, toasts with Open and Snooze, unsigned MSIX job | Signing certificate; the socket is D15 |
| M6 | Tracker, digest, weekend, inactivity, source strip, journal self-report | Device pass |
| M7 | All Swift written, app target compiles, D14 limits recorded; macOS NSWorkspace gate | Xcode extension targets, Apple's entitlement reply |
| M8 | Flags with grace, packs on device, Firm match offline, rules-changed flag, paywall, entitlement endpoint, firm-list import | Store accounts, the three verifiers and store SDKs, a human reading five packs, ads decision |
| M9 | Privacy, terms and Play declarations drafted; deploy runbook; device-testing runbook | Legal review, hosting, store listings, the video |

## Backlog, from Jamie's build request of 29 September 2026

Built on 29 September: the Guard icon in blue and sky, the restyled news cover
(Screen Time shield, Android and desktop gates), the edge glow inside Guard, the
Lock Screen countdown (behind its App ID, see LOCAL-REQUESTS.md) and the
three-step setup.

Still to build:

- **Edge glow over every app, Android.** A `TYPE_APPLICATION_OVERLAY` view with
  `FLAG_NOT_TOUCHABLE` and `FLAG_NOT_FOCUSABLE`, drawn only as a border, started by
  the gate service five minutes before a window and removed at close. It uses the
  "display over other apps" permission the gate already asks for, so no new
  permission. Amber, then red, same timings as the in-app glow.
- **Edge glow over every app, Windows and macOS.** One borderless, always-on-top,
  click-through window per monitor. Windows: `WS_EX_LAYERED | WS_EX_TRANSPARENT |
  WS_EX_TOPMOST | WS_EX_TOOLWINDOW`, per-pixel alpha, so clicks reach MT5 under it.
  macOS: an `NSWindow` at `.screenSaver` level with `ignoresMouseEvents`, joining all
  spaces. The tray app already runs, so it owns these windows.
- **iPhone can't do this.** iOS gives no app a way to draw over other apps. The
  Lock Screen countdown and the news cover are the iPhone's version.
- **Lock Screen countdown without opening the app.** Push-to-start (iOS 17.2) from
  the server at t-60, and push updates at t-5, open and close. Needs the backend
  deployed and the APNs key. Until then the countdown starts when Guard is opened
  or an alert is tapped within the hour before a window, and it turns red on its
  own when the window opens (staleDate), but the amber step at five minutes and the
  end only happen while Guard is open.
