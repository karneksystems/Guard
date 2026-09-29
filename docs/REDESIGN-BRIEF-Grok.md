# Guard: redesign brief for Grok

From Jamie Stephens, Stanchion Systems, 29 September 2026.
Flow: this brief, then Grok (design), then Claude Code (build). Where this brief
and older design notes disagree, this brief wins. `TOTAL-BRIEF-Prop-News-Guard.md`
still wins on product rules.

The app is built and running on an iPhone through TestFlight. It works. It
looks like a competent developer's app, not a product people pay £39 a year
for and tell their prop firm Discord about. That gap is what this brief is for.

Screenshots of every current screen are in [`docs/redesign/shots/`](redesign/shots/),
rendered from the real code with the real fonts, clock set to 08:51 UTC on
1 October 2026, four minutes before EUR CPI.

## 1. The product in one minute

Guard stops manual prop firm traders breaking their account by trading into
high impact news. Before the news it warns them (notifications at 60, 15, 5
and 1 minute, then at open and all clear). During the news it covers their
trading app (MT4, MT5, cTrader, TradingView, broker apps) with a full screen
gate: stay out, or hold to look without trading.

It never touches a trade, never logs into an account, never runs on a trading
terminal. The firm can't see it. That's the promise and the design should make
it feel true: calm, plain, trustworthy, not a trading app.

Who uses it: a trader on phone, tablet or desktop, often a few minutes before
CPI or NFP, stressed, about to make a mistake. Every screen has to read in two
seconds under that stress, one handed.

Free stops the breach. Pro (£4.99 a month or £39 a year, one SKU) adds the
firm's exact rules, custom windows, hard block, unlimited instruments, full
journal history, no ads.

## 2. What's locked

Keep these. Everything else is open.

| Lock | Detail |
|---|---|
| Name | Guard (App Store listing "Guard: Prop News" for now) |
| Brand colours | Blue `#0B5CAD`, deep navy `#08306B`, sky `#5BC8F5`. Jamie picked these on 29 Sep: "I like the blue and sky blue, keep it" |
| Urgency colours | Amber `#F5A524` means news within five minutes. Red `#E5484D` means a window is open. Nothing else may use them |
| No greens | No green anywhere, including "all clear". Clear is sky or cool grey |
| Icon | Sky shield with a clock on a navy to blue gradient ([file](../app/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png)). You may refine it; keep the idea and colours |
| Fonts | Poppins (display) and Inter (body) are bundled. Propose others only with a strong reason |
| Tone | A good weather app or alarm clock. No neon, candles, rockets, gold bars, dollar signs, firm logos |
| Copy | Customer text uses commas, never dashes. Plain words. Contractions. No hype |
| Promise line | "We never touch your trades." appears on the gate and in setup |
| Ads | Never on the gate, the cover, or any alert |

The old "OTTO craft on cool ink, metal `#AE9558` and champagne hairlines"
direction from 22 Sep is replaced by the blue and sky palette above.

## 3. What's wrong now (from the screenshots)

Be as hard on this as you like. These are the ones we already see.

1. **Home is a text list.** [`01-home-dark.png`](redesign/shots/01-home-dark.png).
   The next window card is the only hierarchy. "Windows ahead" repeats rows
   that all look identical, each with a red bar even when nothing is open, so
   red stops meaning anything.
2. **Times are in UTC** on Home, Windows and Journal ("08:55 to 09:05 UTC",
   "2026-10-01"). Traders think in local time. Dates should read "Today",
   "Tomorrow", "Thu 2 Oct".
3. **The status line is jargon.** "Soft gate · Conservative · 2 instruments ·
   Sample data · no backend configured". Nobody knows what those words mean
   on day one.
4. **Contrast.** "NEXT WINDOW", "opens in 4 min" and "sample calendar" are
   brand blue on navy in dark mode, which is hard to read. The selected Home
   icon in the nav bar is dark on dark.
5. **The countdown isn't the hero.** The single most useful fact (how long
   until I have to be flat) is 18pt text under the symbol.
6. **Tablet and desktop are a stretched phone.** [`11-home-tablet.png`](redesign/shots/11-home-tablet.png).
   Full width rows, a huge empty card, stats tiles 800px wide.
7. **The gate is correct but plain.** [`03-gate-desktop-and-android.png`](redesign/shots/03-gate-desktop-and-android.png).
   Big empty top third, the countdown doesn't say what it counts to, no
   visual difference between "opens soon" and "open now".
8. **Settings is a long flat list** of eleven rows with no grouping.
   [`08-settings.png`](redesign/shots/08-settings.png).
9. **Paywall headline** "Precision, not safety" is clever and unclear. The
   price buttons render greyed out when prices haven't loaded, which looks
   broken. [`09-paywall.png`](redesign/shots/09-paywall.png).
10. **Journal and Tracker** are functional forms with no reward: no streak,
    no sense of "you stayed out 12 times this month".

## 4. What to design

Deliver in this order. Phone first (iPhone 14 Plus, 428 x 926 pt, is the test
device), then tablet and desktop.

1. **Design tokens.** Full colour set for dark and light (backgrounds,
   surfaces, text, muted text, hairlines, the four phase colours), type scale
   with sizes and weights, spacing scale, radius, elevation (we use none
   today). As a table of hex values and numbers, not only a picture.
2. **The gate**, phone and desktop. The most important screen. Two states:
   five minutes before (amber) and open (red). Show it for a gold trader 90
   seconds into EUR CPI. Stay out, and Hold to view only (3 second hold, with
   progress). Hard block variant with no view option.
3. **Home.** Next event as the hero with a live countdown, phase colour,
   today's windows as a timeline rather than a list, daily loss room, minimum
   trading days, tomorrow's count. Clear state (nothing today) matters as
   much as the busy state.
4. **The edge glow.** Inside the app the screen edge glows amber then red.
   It exists ([`news_glow.dart`](../app/lib/shell/news_glow.dart)); refine
   width, softness and whether it breathes. On Android and desktop it will
   later sit over other apps as a click through border, so design it to work
   over someone else's chart.
5. **Lock Screen countdown** (iOS Live Activity) and Dynamic Island. See the
   limits in section 5. Phases: sky an hour out, amber at five minutes, red
   open, sky "all clear".
6. **The news cover on iPhone** (Screen Time shield). Apple's fixed template,
   see section 5. Pick background, icon, the two button colours and the words.
7. **Notifications.** Lock screen and banner for each rung (60, 15, 5, 1
   minute, open, all clear), and the Android full screen alarm state.
   Current words are in [`rung_words.dart`](../app/lib/notifications/rung_words.dart).
8. **Setup**, three steps, already cut down from six: what do you trade,
   turn on alerts (and pick apps to cover), you're set. Keep it three.
9. **Windows** (the full list), **Night before digest** screen and
   notification, **Journal**, **Tracker**, **Settings** (grouped),
   **Paywall**, **Permissions** (Android asks for six).
10. **Tablet and desktop** layouts for Home and the gate. Desktop is Windows
    first, a tray app whose gate covers MT5 on the monitor MT5 is on.

For each screen: dark and light, the exact copy, every state (empty, loading,
error, busy), and measurements. We build in Flutter with Material 3, so
anything expressible as widgets, colours, radii and type is cheap. Custom
illustration is fine if you supply it as SVG.

## 5. Hard platform limits

Design within these; they aren't ours to change.

**iPhone news cover** (Screen Time `ShieldConfiguration`). Apple draws it. We
set only: background colour and blur style, one icon (SF Symbol or small
image), title text and colour, subtitle text and colour, primary button label,
label colour and background colour, and an optional secondary button label
and colour. No layout, no fonts, no countdown, no images beyond the icon.
Current version: [`GuardShield.swift`](../app/ios/GuardShield/GuardShield.swift).

**iPhone Lock Screen countdown** (Live Activity). Max about 160pt tall on the
Lock Screen, SwiftUI, system fonts (SF). Countdowns must be system timers.
Until the server is live the app can only change it while open, so the design
must still make sense if it's stuck on an old phase: show the time the window
opens or reopens as text, not only a countdown. Dynamic Island needs compact
leading, compact trailing, minimal and expanded. The test phone (14 Plus) has
no Dynamic Island, so the Lock Screen view matters most. Current version:
[`GuardLiveActivity.swift`](../app/ios/GuardLiveActivity/GuardLiveActivity.swift).

**iPhone can't draw over other apps.** The glow over other apps is Android and
desktop only.

**Android gate** is a native full screen activity, so any layout works, but it
must build from plain views (text, buttons, one countdown). Current version:
[`GateActivity.kt`](../app/android/app/src/main/kotlin/com/stanchion/guard_app/GateActivity.kt).

**Notifications** are OS templates: title, body, up to two action buttons on
Android and Windows. No colour control on iOS.

## 6. What to send back

1. Two or three directions as boards (home, gate, lock screen for each), each
   inside the locks in section 2. One line on why each would win.
2. For the direction Jamie picks: every screen in section 4, dark and light,
   phone first, then tablet and desktop for Home and the gate.
3. A token table and a type scale Claude Code can paste into
   [`tokens.dart`](../app/lib/theme/tokens.dart).
4. The icon refined at 1024 x 1024, plus a monochrome version for the Android
   notification icon and the Windows tray.
5. A list of your assumptions and anything you think we got wrong in the
   product, not only the pixels.

## 7. Source files

Private repo `karneksystems/guard`, branch `main`. Links open only for people
with access. Grok, if you can't open them, ask Jamie for the zip that came
with this brief, which holds the same files.

| Area | File |
|---|---|
| Product rules | [docs/TOTAL-BRIEF-Prop-News-Guard.md](TOTAL-BRIEF-Prop-News-Guard.md) |
| Free and Pro | [docs/FREE-PRO-FLAGS.md](FREE-PRO-FLAGS.md) |
| Gate behaviour | [docs/SOFT-GATE.md](SOFT-GATE.md) |
| Alert ladder | [docs/PUSH-ARCHITECTURE.md](PUSH-ARCHITECTURE.md) |
| Design tokens and theme | [app/lib/theme/tokens.dart](../app/lib/theme/tokens.dart) |
| App root | [app/lib/main.dart](../app/lib/main.dart) |
| Navigation shell (bar, rail) | [app/lib/shell/adaptive_shell.dart](../app/lib/shell/adaptive_shell.dart) |
| Edge glow | [app/lib/shell/news_glow.dart](../app/lib/shell/news_glow.dart) |
| Phase logic (clear, soon, live) | [app/lib/state/news_phase.dart](../app/lib/state/news_phase.dart) |
| Setup | [app/lib/onboarding/onboarding_flow.dart](../app/lib/onboarding/onboarding_flow.dart) |
| Home | [app/lib/screens/home_screen.dart](../app/lib/screens/home_screen.dart) |
| Windows | [app/lib/screens/windows_screen.dart](../app/lib/screens/windows_screen.dart) |
| Digest | [app/lib/screens/digest_screen.dart](../app/lib/screens/digest_screen.dart) |
| Journal | [app/lib/screens/journal_screen.dart](../app/lib/screens/journal_screen.dart) |
| Tracker | [app/lib/screens/tracker_screen.dart](../app/lib/screens/tracker_screen.dart) |
| Settings | [app/lib/screens/settings_screen.dart](../app/lib/screens/settings_screen.dart) |
| Permissions | [app/lib/screens/permissions_screen.dart](../app/lib/screens/permissions_screen.dart) |
| Paywall | [app/lib/screens/paywall_screen.dart](../app/lib/screens/paywall_screen.dart) |
| Firm pack view | [app/lib/screens/pack_screen.dart](../app/lib/screens/pack_screen.dart) |
| Hub placeholder | [app/lib/screens/profile_screen.dart](../app/lib/screens/profile_screen.dart) |
| Gate (desktop, Flutter) | [app/lib/gate/gate_screen.dart](../app/lib/gate/gate_screen.dart) |
| Gate (Android, native) | [app/android/.../GateActivity.kt](../app/android/app/src/main/kotlin/com/stanchion/guard_app/GateActivity.kt) |
| News cover (iPhone) | [app/ios/GuardShield/GuardShield.swift](../app/ios/GuardShield/GuardShield.swift) |
| Lock Screen countdown | [app/ios/GuardLiveActivity/GuardLiveActivity.swift](../app/ios/GuardLiveActivity/GuardLiveActivity.swift) |
| Notification words | [app/lib/notifications/rung_words.dart](../app/lib/notifications/rung_words.dart) |
| Sample calendar used in shots | [app/lib/data/sample_data.dart](../app/lib/data/sample_data.dart) |
| Icon | [app/ios/Runner/Assets.xcassets/AppIcon.appiconset/](../app/ios/Runner/Assets.xcassets/AppIcon.appiconset/) |
| Screenshot renderer | [app/tool/screenshots_test.dart](../app/tool/screenshots_test.dart) |

| Screenshot | Shows |
|---|---|
| [01-home-dark](redesign/shots/01-home-dark.png) | Home, dark, four minutes before CPI, amber glow |
| [02-home-light](redesign/shots/02-home-light.png) | Same, light |
| [03-gate-desktop-and-android](redesign/shots/03-gate-desktop-and-android.png) | The Flutter gate, window open |
| [04-windows](redesign/shots/04-windows.png) | All windows |
| [05-digest](redesign/shots/05-digest.png) | Night before digest |
| [06-journal](redesign/shots/06-journal.png) | Journal with two entries |
| [07-tracker](redesign/shots/07-tracker.png) | Daily loss and minimum days |
| [08-settings](redesign/shots/08-settings.png) | Settings |
| [09-paywall](redesign/shots/09-paywall.png) | Pro paywall |
| [10-onboarding-step1](redesign/shots/10-onboarding-step1.png) | Setup, step one |
| [11-home-tablet](redesign/shots/11-home-tablet.png) | Home at tablet width |
