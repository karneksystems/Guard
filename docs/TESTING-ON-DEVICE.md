# Testing on a device, without a computer

Every push to main builds a debug APK and a debug Windows folder and keeps
them for fourteen days under the run's Artifacts.

## Android phone or tablet

1. On the phone, open github.com/karneksystems/guard, Actions, the latest
   green `ci` run, Artifacts, `guard-android-debug`. Download and unzip
   (Files app handles it), then open `app-debug.apk`. Allow installs from
   Chrome or Files when asked.
2. Open the app. Walk through the six onboarding steps. Grant every
   permission on the permissions screen: notifications, usage access, display
   over other apps, alarms, full-screen alerts, battery unrestricted.
3. There is no backend in this build, so Home runs on the sample calendar:
   windows on 1 and 2 October 2026. To try the gate now, Settings, at the
   bottom, "Start a 2-minute test window" (debug builds only). It arms a
   window on your gated apps opening in one minute. Wait for the one-minute
   and open alerts, then open MetaTrader 5 (or whichever app you gated): the
   gate should cover it. Stay out, or hold to view for three seconds. The
   entry appears in Journal.
4. Try it once more with the app swiped away from recents before the window
   opens. That is the case that matters, and the one Samsung and Xiaomi
   sometimes break: if nothing fires, check Battery, Unrestricted, and the
   maker's own autostart list.

## Windows PC

1. Actions, the latest `native` run, Artifacts, `guard-windows-debug`.
   Unzip anywhere and run `guard_app.exe`. SmartScreen will object to an
   unsigned binary; More info, Run anyway. It is a debug build.
2. The app sits in the tray. Settings, Gated apps: MetaTrader 5 is
   `terminal64.exe`. Use the test window the same way; then bring MT5 to the
   front. The gate takes the monitor MT5 is on.
3. Toasts need the app to have run once so Windows knows its identity. If
   the first toast does not show, run the app once more and try again.

## iPhone

Through TestFlight, set up once with `docs/TESTFLIGHT.md`. The first builds
have the alerts and every screen but no gate until Apple approves the Screen
Time entitlement for distribution.

## What to write down

Device, OS version, which step failed, and a screenshot of Home's permission
banner if it is showing. That is enough to fix most things.
