# Milestones

Pre-build deliverable 6. Order follows the total brief. Durations assume one senior
developer working with Claude Code full time, and they're honest, not optimistic.
Adding a second developer parallelises M4 and M5.

| # | Milestone | Exit criteria | Weeks |
|---|---|---|---|
| M0 | Pre-build | These docs signed off. Name cleared. Vendor quotes in. Family Controls request filed. | 1 |
| M1 | Skeleton | Flutter app builds on all four targets. Backend up with calendar sync from the chosen vendor. Rule engine passes the shared fixture set on device and server. Profile object and hidden hub nav slot exist. | 3 |
| M2 | Onboarding and settings | Six-step onboarding. Every setting editable afterwards. Permissions flow on Android complete with the banner logic. | 1 |
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
