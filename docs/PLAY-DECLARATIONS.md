# Google Play declarations (draft)

The three permissions Play reviews by hand, with the wording to use in the
console and the video to record. Record the video on the M4 build.

## Foreground service, type specialUse

Declared in the manifest with `PROPERTY_SPECIAL_USE_FGS_SUBTYPE`:
"news-window gate". Console text:

> During a user-scheduled restricted window (typically ten minutes around a
> high-impact economic release) the app runs a short foreground service that
> checks once a second whether a trading app the user chose has come to the
> front, and shows a full-screen reminder if it has. The service starts at the
> window's open time from an exact alarm and stops itself at the close time.
> It runs for the window's duration only, never continuously. No existing
> foreground service type describes a user-configured, time-boxed watch of a
> single app, which is why specialUse.

## Full-screen intent (USE_FULL_SCREEN_INTENT)

> The app's purpose is to stop a trader breaching a prop-firm rule by trading
> into a news window. The one-minute and window-open alerts are alarm-class:
> the user has asked to be interrupted at that moment, and a heads-up
> notification is easy to miss on a phone in a pocket. Full-screen intent is
> used only for those two rungs, capped at sixty seconds of alarm-style repeat,
> and the user can switch the alert down to a normal notification in Settings.

## Usage access (PACKAGE_USAGE_STATS)

> Used only inside a restricted window, by the foreground service above, to
> detect that the trading app the user selected has moved to the foreground.
> The app never reads usage history, never lists other apps' usage, and never
> sends any package name off the device. The setting is requested with an
> in-app explanation and the app works in warn-only mode without it.

## Display over other apps (SYSTEM_ALERT_WINDOW)

> The gate is shown as an overlay so it can cover the trading app during the
> window. It is touch-modal by design and has two buttons: Stay out, and hold
> to view for three seconds. It is never shown outside a window.

## Video

Ninety seconds, phone held in hand: onboarding permission screen, a scheduled
window arriving (use the fake calendar with an event two minutes out), the
notification ladder, MT5 opened during the window, the gate, Stay out, the
journal entry. Show Settings, Protection, Warn only, to demonstrate the app
works with the gate off.

## Data safety form

Collected: device id (app functionality), settings (app functionality), push
token (app functionality), journal outcomes (app functionality, optional).
Not collected: location, contacts, financial info, account credentials,
messages, photos, app activity of other apps beyond the foreground check that
never leaves the device. Encrypted in transit: yes. Deletion request: yes.
