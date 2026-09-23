# Push architecture

Pre-build deliverable 4. Ladder, scheduling, providers, local mirror, quiet hours,
failure modes. Decision D1 applies: push is primary, local is the safety net.

## Ladder

Rungs per window: T-60, T-15, T-5, T-1, open, end. Six pushes per window, fewer when
windows merge. Night-before digest at 20:00 local by default, user-settable, listing
tomorrow's windows.

alert_id is the first 20 hex characters of sha1(user_id, window_id, rung,
opens_at_utc). The same id is the rung's primary key on the server, rides in the push
payload (and as apns-collapse-id on iOS), and names the local mirror notification. A
rescheduled event gets new ids and the old ones are cancelled.

## Scheduling

Reconcile runs on: settings change, instrument change, pack change, event.changed,
device registered, and a nightly sweep at 00:30 UTC covering the next 48 hours. Each
rung is a Horizon delayed job. Jobs are idempotent: on fire, re-read the rung, skip
if cancelled or already sent, send, then mark sent with the provider's message id.

Precision matters on T-1 and open. Rungs go on a dedicated queue with its own
workers polled every second, never shared with slow jobs. Target: a rung leaves the
server within two seconds of fire_at.

## Providers

iOS. APNs over HTTP/2 with token auth (.p8 key). Interruption level time-sensitive on
T-15, T-5, T-1, open and end. Active on T-60 and the digest. Sound on every ladder
rung. Needs the time-sensitive entitlement.

Android. FCM HTTP v1, priority high, data-only messages so the app builds the
notification and controls channels and the full-screen intent. Channels: ladder_urgent
(T-1 and open; full-screen intent when canUseFullScreenIntent is true; alarm-style
repeat until dismissed, capped at 60 seconds), ladder (T-60, T-15, T-5, end; heads-up
with sound), digest (default importance).

Windows. The tray app keeps a WebSocket to the backend with a heartbeat. A rung
arrives as a JSON frame and the app raises a toast through the notification centre
with two actions, "Open Wideberth" and "Snooze 1 min". When the MSIX ships with
Store identity, WNS raw push is added as a second channel carrying the same alert
id, and the app dedupes.

macOS. APNs for Mac in the notarised build. WebSocket fallback identical to Windows.

## Local mirror

On every sync the device receives the next 48 hours of rungs and schedules each as a
local notification at fire_at plus 20 seconds, named with the same alert id. When a
push arrives for an id, the app cancels the pending local for it. Where cancellation
isn't reachable in time (an iOS notification service extension can't always touch the
pending queue), the local fires 20 seconds later as a repeat. For an alarm-style
product that's acceptable, and it's what the brief asks for on Android anyway. Local
notifications use UTC instants, so a timezone change doesn't move them. The digest is
local-only, no server push, because it isn't time-critical.

Windows and macOS register scheduled toasts the same way, so a rung fires even if the
app was closed after the last sync.

## Quiet hours and Do Not Disturb

Default: no quiet hours. If an event is in the user's basket they asked for it,
overnight JPY and AUD prints included.

Optional quiet hours: when enabled, only T-5, T-1 and open fire inside the quiet
range. The digest never fires inside it.

iOS: time-sensitive breaks through Focus only when the user allows it in Settings. We
never request Critical Alerts. Android: we never bypass DND; ladder_urgent is
importance high, not DND-bypassing. Desktop: Focus Assist and Focus decide, we mark
toasts high priority and leave it.

Home shows a persistent banner whenever notifications are off, permission is denied,
full-screen intent isn't granted, exact alarms aren't allowed, or battery
optimisation is on. That banner is the honest version of "we can't wake you".

## Failure modes

| Failure | Effect | Handling |
|---|---|---|
| Token invalid, app uninstalled | Push rejected | Prune token, set notif_state invalid, re-register on next launch |
| APNs or FCM 429 or 5xx | Delay | Retry with backoff up to 90 seconds, then stop. Mirror fires |
| Device offline | Provider holds the push | Mirror fires on time. Late push is dropped if the window has closed |
| Event time revised | Ladder wrong | Cancel old ids, create new, silent push (content-available, FCM data) triggers a re-mirror |
| Device timezone change | None on timing | UTC instants. UI relabels |
| Android app force-stopped by the user | Nothing runs until relaunch | Onboarding explains. Nothing else can be done |
| OEM battery manager | Alarms delayed | Onboarding opens the battery page. Banner until granted |
| Desktop app not running | No live toast | Scheduled toasts from the last sync still fire. App resyncs on launch |
| Backend down | No push | Mirror covers 48 hours. Home shows last-sync age |
| Calendar vendor down | Stale events | Keep serving the last good feed. Home shows the feed age. Alert ops at 30 minutes stale |
