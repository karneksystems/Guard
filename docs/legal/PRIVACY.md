# Privacy policy (draft for review)

Effective: on publication. Operator: Stanchion Systems Ltd, United Kingdom.
Contact: to be set before launch.

## What the app is

A news-window guard for traders. It tells you when a high-impact economic
release is coming and, if you ask it to, covers your trading app during the
restricted window. It never logs in to a trading account, never sends a trade
instruction, and has no code path that could.

## What stays on your device

- Which apps you chose to gate. On Android and Windows that is a package or
  process name; on iPhone and iPad it is an opaque Screen Time token that not
  even we can read. This never leaves the device.
- Your daily-loss entries, minimum-days countdown and reminder settings.
- Your journal (stayed out, viewed, traded anyway) and the last synced calendar.

## What the server holds

- A random device id and a bearer token, so the app can sync. No email unless
  you give one to link devices.
- Your settings: rule mode, protection mode, window minutes, chosen firm and
  account type, digest time, time zone.
- Your instruments and their currency baskets.
- A push token for your device, so the alert ladder can reach you.
- Journal outcomes, if you recorded any: a window id, an outcome word and a
  time. Never which app was gated.
- Whether Pro is active and until when, from the store's receipt.

We hold no account numbers, no firm logins, no passwords, no trade data, no
screenshots, no contacts, no location.

## Who else sees data

- The calendar vendor supplies events to our server; your data does not go to
  them.
- Apple, Google and Microsoft deliver push notifications and, for Pro, handle
  payment. Push payloads carry an alert id and words about a window; nothing
  personal.
- Hosting: our server runs on infrastructure we operate or rent. Data is in
  transit over TLS and at rest on that server.

We do not sell data and do not run third-party analytics or tracking SDKs. If
the free tier shows ads, they are shown without sharing your data with the ad
network beyond what its SDK collects, and never on the gate or an alert. This
section will be updated with the network's name before ads are switched on.

## Retention and deletion

Delete the app and the device data is gone. Ask us to delete your server record
and it is removed within 30 days, journal included. Calendar events are not
personal data and are kept as a rolling window.

## Your rights

Under UK GDPR you can ask for a copy of your server record, correct it, or have
it deleted, at the contact above. We do not make automated decisions about you.
Reminders and gates are things you configured.

## Changes

Material changes are shown in the app before they take effect.
