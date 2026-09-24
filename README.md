# guard

Prop-firm news guard for phone, tablet and desktop. Codename `guard`; the product
name is still open. It stops manual prop traders breaching accounts by trading into
restricted news windows. It never touches a trade, never logs into an account, and
never runs on a terminal.

Read `docs/TOTAL-BRIEF-Prop-News-Guard.md` first. It wins on product. `docs/INDEX.md`
lists the rest, and `docs/DECISIONS.md` says why things are the way they are.

## Layout

```
app/                    Flutter app: Android, iOS/iPadOS, Windows, macOS from one tree
backend/                Laravel API: calendar mirror, rule packs, device registry, ladder scheduler
packages/rule_engine    The rule engine in Dart (used by the app)
packages/rule-engine-php  The same engine in PHP (used by the backend)
packs/                  Firm rule packs, JSON, one per firm, all unverified until a human reads the source
schema/                 Pack JSON Schema and the validator CI runs
fixtures/rule-engine/   Ten shared cases both engines must pass, plus the Python reference that generated them
docs/                   Brief, architecture, specs, decisions
```

## Run the checks

```
python3 schema/validate_packs.py                       # packs against the schema
python3 fixtures/rule-engine/reference.py --check      # fixtures haven't drifted
cd packages/rule_engine && dart test                   # Dart engine
cd packages/rule-engine-php && composer install && vendor/bin/phpunit
cd backend && composer install && php artisan test     # calendar sync, ladder reconcile, API
cd app && flutter pub get && flutter analyze && flutter test
```

## Backend, first run

```
cd backend
cp .env.example .env && php artisan key:generate
php artisan migrate
php artisan calendar:sync          # fake vendor by default, see config/guard.php
php artisan packs:publish
php artisan serve
```

Register a device and pull a sync:

```
curl -s -X POST localhost:8000/api/devices -H 'Content-Type: application/json' \
  -d '{"platform":"android","tz":"Europe/London"}'
curl -s localhost:8000/api/sync -H "Authorization: Bearer <token>"
```

Queues: the ladder runs on a queue named `ladder`, polled every second with its own
workers. In development, `php artisan queue:work --queue=ladder,default`.

## Where M1 stands

Done: both engines pass the fixtures; backend migrations, calendar sync with a vendor
adapter (fake vendor, Trading Economics adapter awaiting a key), ladder reconcile with
delayed jobs, pack publishing, the device API; Flutter shell with the design tokens,
adaptive layout across the three width classes, the engine driving Home on the
device, and a sync client with a file-backed local store (register once, sync, fall
back to the last good payload when the network fails). Build with
`--dart-define=GUARD_API=https://your-backend` to use a backend; without it the app
runs on sample data.

M2: six-step onboarding (protection, instruments, rule mode, window, gated apps,
explainer), settings editable afterwards and pushed to the backend, a platform
bridge with the Android permissions half (usage access, overlay, exact alarm,
full-screen intent, notifications, battery) and the Home banner that names what's
missing. Gated app ids never leave the device. The Kotlin side is written but not
compiled here; the first `flutter build apk` is its check.

M3: backend APNs (token auth, time-sensitive, collapse id) and FCM (service
account, data-only, high priority) senders behind a per-platform router that
prunes dead tokens; signatures are verified against OpenSSL in tests. App side:
the local mirror schedules every rung as an OS notification twenty seconds after
its push time and cancels it when the push lands. Set `GUARD_PUSH_SENDER=live`
with the APNs and FCM keys in `.env` to go live. The app's Firebase registration
waits on a Firebase project: drop `google-services.json` and
`GoogleService-Info.plist` in and replace `FakeRegistrar` in `main.dart`.

M4, Android Soft gate: an exact alarm at window open starts a short-lived
foreground service that polls usage events once a second and shows a native
full-screen gate when a gated app comes to the front (countdown, events,
instrument, Stay out, Hold to view only for three seconds, hard block hides the
second). Windows survive reboot. Outcomes drain back into the journal and the
backend without the package name. The Dart side hands the device engine's
windows to the gate after every payload and settings change. Compiled by the
android-build CI job; not yet run on a device.

M5, Windows desktop gate: the runner polls the foreground window once a second
while a window is open (`windows/runner/gate_watcher.cpp`). When a gated process
(terminal64.exe by default) is in front it tells Dart, which raises the app
window topmost on that monitor and shows the same gate screen, Stay out
minimises the trading app, Hold to view lifts the gate for sixty seconds. The
app lives in the tray, close hides it, and it starts at login, because the gate
needs the process alive. Rungs schedule as Windows toasts. Compiled by the
windows-build CI job; not yet run on a Windows machine. macOS gets the tray and
the notifications but no gate until M7.

M6, free features: the manual tracker (daily-loss room, minimum trading days
from logged trades, inactivity limit, weekend warning) lives in prefs on the
device and drives Home's tiles. Reminders are local notifications planned from
the windows and the tracker (`lib/notifications/reminders.dart`): the
night-before digest at the user's time, the weekend hold warning on Friday, the
inactivity reminder three days before the firm's limit. Reminder ids sit above
the ladder's range so the two schedulers never cancel each other. The source
strip shows on every window. A viewed journal entry can be self-reported as a
trade.

M8, Pro, the half that needs no store account: the flag set in
`lib/features/flags.dart` derives from the server's word with the seven-day grace.
Packs come down on every sync (index for all firms, the full pack for the
user's firm) and are cached in prefs, so Firm match runs on the device offline.
A pack version change raises the rules-changed flag on Home with the changelog
behind it. Settings picks firm and account type from the index; the pack screen
shows version, verified state, source, the rule and the changelog. The paywall
is one SKU behind a `Billing` interface, and `POST /api/entitlement` verifies a
receipt through `ReceiptVerifier`, which rejects everything until the store
verifiers exist (`GUARD_RECEIPT_VERIFIER=fake` for development). Still to do in
M8: StoreKit, Play Billing and Microsoft Store behind `Billing`, the three
verifiers, a human reading the five packs' sources, ads.

M7, iOS Screen Time gate, as far as it goes without Apple's answer: the Swift
is written. `ios/Runner/ScreenTimeGate.swift` handles the same channels as
Android (authorise, Apple's picker, DeviceActivity schedules for the next
twenty windows, journal drain), `ios/Shared/GateShared.swift` is the app-group
store, and the three extensions (monitor, shield card, shield actions) sit in
their folders with plists and entitlements. The Runner target compiles in the
ios-build job; the extension targets are added in Xcode once, per
`ios/SCREEN-TIME-SETUP.md`. Two OS limits are recorded as D14: intervals pad
to fifteen minutes anchored to the close, and "View for 60 seconds" is a set of
usage-threshold events. Distribution waits on the entitlement.

Also in: Poppins and Inter bundled (OFL, licences beside the files), the
journal persisted on the device with the Pro streak, an on-demand unsigned MSIX
job (`native.yml`, workflow_dispatch), and drafts of the privacy policy, terms
and Play declarations under `docs/legal/` and `docs/PLAY-DECLARATIONS.md` for
the user to review before M9.

Not yet: MSIX signing, store builds, the store billing SDKs, ads. See
`docs/MILESTONES.md`.
