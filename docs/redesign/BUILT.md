# Grok redesign: what was built, and where it differs

Built on 30 September 2026 from `grok-final/` (Grok's pack, unchanged). Screens
rendered from the real code are in `built/`, at iPhone 14 Plus size, clock at
08:51 on 1 October, four minutes before EUR CPI. Regenerate with
`flutter test tool/screenshots_test.dart --update-goldens` in `app/`.

Everything in `HANDOFF-Claude.md` section 10 is done: tokens pasted, 3pt glow,
Home / Today / Log / Settings with Grok's icons, Tomorrow's news off the tab
bar, COPY.md on every screen and alert, High only filters with counts, flags
from `shared/flags`, the cover, Live Activity, shield and Android cover in the
new words, tablet and desktop layouts.

## Where the build differs, and why

| Pack says | Built | Why |
|---|---|---|
| "8:55–9:05" (en dash) in COPY.md | "8:55 to 9:05" | House style: commas and words, never dashes |
| iPhone shield secondary "Hold to look only", with a tinted button and three fact chips (`shield-mock.png`) | "Look for 60 seconds", label colour only, no chips | Apple's shield buttons are taps, and the template has no chips or button background for the second button. `shield-config-doc.png` was right; the mock can't be built |
| Actual, Forecast, Previous on rows and the Lock Screen | Left out | The calendar feed doesn't carry them yet. Add when the backend stores them |
| Low impact green `#3DDC97` | Kept | Jamie's lock with Grok, which replaces "no greens" from the 29 Sep brief for calendar rows and chips only |
| No edge glow over other apps anywhere | Still in the backlog for Android and desktop | Jamie asked for it on 29 Sep. Needs Jamie to confirm dropping it |
| Hero "Gold · EUR CPI" | "Gold, EUR · EUR CPI" when one release covers both markets | Both are covered; showing one would be wrong |
| Hero states: soon, on, clear | Adds "Next cover" in sky when the next cover is later today but more than five minutes out | The boards had no state for 10:00 on a CPI day |
| Paywall plan cards | Cards pick, the button buys | A tap on a price that charges you is a dark pattern |
| Setup: four markets | Five, adds JPY pairs. US indices watches US500 | Yen news is a common prop market; one instrument per choice keeps Free's limit of two honest |
| New icon in `icon/` | Kept the icon already shipped | Same design; Grok's PNG has rounded corners baked in, which iOS rounds again |
| Android cover with an arc | Countdown text, no arc | The Android cover is built from plain views so it starts in milliseconds over the lock screen |
| Live Activity ring | System circular timer | Live Activities can only animate with system timers |
| "Sample data" banned | "Example news until Guard connects" on Today | Honest about the placeholder calendar without the jargon |

## Found on the way

- Alerts from the server now use the same words and local times, from the
  user's stored time zone (`backend/app/Push/RungMessage.php`, `EventNames.php`).
- The app registers with `DateTime.now().timeZoneName` ("BST"), but the backend
  only accepts IANA names ("Europe/London"). Registration will fail once the
  server is live. Needs a time zone plugin on the app side; not fixed here.
