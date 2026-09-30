# Guard · HANDOFF for Claude Code (build-ready)

**Do not ask Jamie for product decisions already locked below.** Implement from this pack. Open order: this file → `COPY.md` → `tokens.dart` → PNGs as visual source of truth.

Visual: **B Precision Field** + **C ~3pt phase glow**. This is a **customer experience rewrite**, not a colour restyle.

Scenario locked for boards + copy: gold / EUR CPI / local **08:51** / cover window **Today 8:55–9:05** unless clear.

---

## 0 · Pack layout (what to open)

| Path | Use |
|---|---|
| `HANDOFF-Claude.md` | This file — build order, locks, gaps |
| `README-CLAUDE.md` | One-page start here |
| `COPY.md` | **Every** customer string — paste/adapt; never invent UI copy |
| `tokens.dart` | Paste → `app/lib/theme/tokens.dart` |
| `TOKENS.md` | Human token reference (same values) |
| `JOURNEY.md` | Setup → clear → night before → ladder → cover → log → Pro |
| `phone/*.png` | Phone visual SoT (428×926) |
| `tablet/*.png` · `desktop/*.png` | Adaptive layouts |
| `composites/*.png` | **Reference only** for Island / LA / banner / overlay placement — not app chrome to reimplement as Flutter widgets |
| `icon/` | App icon + mono |
| `shared/flags/*.svg` | Calendar row flags (wire into Flutter) |
| `shared/icons/nav-*.svg` | Tab glyphs (wire into `adaptive_shell.dart`) |
| `MYFXBOOK-CALENDAR-NOTES.md` | Calendar research; Guard default ≠ Myfxbook all-levels |
| `ASSUMPTIONS.md` · `AUDIT-PREMIUM.md` · `COMPOSITES.md` · `INDEX.md` | Context / audit / index |

HTML under `html/` + generators are **design sources**, not runtime. Ship Flutter from PNGs + tokens + COPY.

---

## 1 · Customer IA (locked)

| Tab | Customer label | Engineering file (rename UI only) |
|---|---|---|
| 1 | **Home** | `home_screen.dart` — one hero fact |
| 2 | **Today** | was Windows → `windows_screen.dart` |
| 3 | **Log** | was Journal → `journal_screen.dart` |
| 4 | **Settings** | `settings_screen.dart` — grouped |

**Tomorrow's news is NOT a tab.** Was Digest; file may stay `digest_screen.dart`. Reach from:
- Home metric strip (“Tomorrow N”)
- Today (tomorrow section / deep link)
- Settings → Alerts
- Night-before push (`notif-tomorrow`)

Daily limits live under Settings → Account (not a fifth tab). File may stay `tracker_screen.dart`.

---

## 2 · Banned / required language (non-negotiable)

**Never show the user:** Soft gate · Soft cover · Gate · Digest · Night before · Conservative · instruments · Sample data · Firm match · UTC · Hold to view only · Hard block (as a customer phrase).

**Always use:** Cover · Cover is on · Stay out · Hold to look only · Block · your firm's rules · local times · We never touch your trades.

Engineering-only names OK in code: SoftGate, GateActivity, gate_*, digest_screen, news_glow, windows_screen, journal_screen.

Exact strings: `COPY.md`. Do not paraphrase Stay out / Hold to look only / Cover is on.

---

## 3 · Locked tokens (paste first)

**Source file:** `final/tokens.dart` → **`app/lib/theme/tokens.dart`**.

| Role | Value | Where |
|---|---|---|
| Brand | `#0B5CAD` | Primary / light CTAs |
| Brand deep | `#08306B` | Depth |
| Sky | `#5BC8F5` | Clear phase, accents (never green for clear) |
| Phase amber | `#F5A524` | Cover soon + edge glow |
| Phase / high red | `#E5484D` | Cover open + impactHigh |
| impactLow | `#3DDC97` | Calendar low **only** |
| impactMid | `#E8C547` | Calendar mid (≠ amber) |
| impactHigh | `#E5484D` | Calendar high (= red) |
| impactNone | `#7C8794` | No-impact grey |
| Glow width | **3.0** pt + bloom 40 / outer 32 | `news_glow.dart` |
| Gutter | 18 | Phone |
| Radius | 8 / 10 / 12 (sm / default / md) | Buttons / metrics / cards |
| Button height | 52 | Primary / outlined |
| Home ring | ~168pt · countdown type 28–40 | Hero |
| Gate arc | 240 / countdown type 56 | Cover overlay |
| Hold | 3s → 60s look window | Cover secondary |
| Elevation | **0** | Hairline borders only |
| Type | Poppins display · Inter body | Bundle fonts |

**Green never** = all-clear, success, Stay out, or phase status. Clear = sky or cool grey.

Wire glow: `Tokens.glowWidth` + `phaseGlowAmber` / `phaseGlowRed` (+ Core) into `app/lib/shell/news_glow.dart`. Breathe opacity ±15% OK.

---

## 4 · Calendar (locked)

1. Impact colours **only** on calendar rows + Low/Mid/High filter chips — not on phase glow.
2. Filters: multi-select chips with **counts**. **Default = High only.**
3. Home “Also today” peek = high-impact (or same filter as Today).
4. Row anatomy (phone): flag SVG + currency · title · cover time · 1–3 impact bars · eta. Wider: may add Actual / Forecast / Previous.
5. Wire assets: `final/shared/flags/{eu,us,gb,jp,ca,au,ch,cn}.svg` — **no emoji flags** in production UI.
6. Guard default High-only is intentional (Jamie), even if Myfxbook often shows all levels. See `MYFXBOOK-CALENDAR-NOTES.md`.

---

## 5 · Cover / Live Activity / Island / shield / Android FSI

| Surface | Engineering | Customer | PNG reference |
|---|---|---|---|
| Cover overlay | GateActivity.kt · GuardShield · desktop overlay | Stay out · Hold to look only (omit on Block) · arc · glow **on** | `phone/gate-*.png` · `composites/overlay-mt5.png` |
| Live Activity | GuardLiveActivity.swift | Four phases: hour / soon / on / clear — COPY.md | `phone/lock-*.png` · `composites/lock-*.png` |
| Dynamic Island | Same LA compact | SOON / ON compact; expanded = `phone/di-expanded.png` | `composites/home-island-*.png` |
| Screen Time shield | GuardShield.swift + shield config | Copy table in `phone/shield-config-doc.png` · mock `shield-mock.png` | |
| Android FSI | GateActivity full-screen intent | `phone/android-fsi.png` | |
| Notifications | `rung_words.dart` — drop UTC | Six ladder rungs + tomorrow + clear — COPY.md | `phone/notif-*.png` |

**OS chrome rules (composites are reference only):**
- **No edge glow on Springboard** or over other apps. Glow lives inside Guard cover UI only.
- Cover overlay **only over trading apps** (MT5 etc.), not the home screen.
- Island + banner coexistence on lock/unlocked is illustrative; match Apple/system spacing in code, use boards for copy + phase colour + density intent.
- Live Activity production fonts = SF; boards use Poppins — keep SF on device.

---

## 6 · Build order (do in sequence)

1. **Tokens** — paste `final/tokens.dart` → `app/lib/theme/tokens.dart`. Wire 3pt glow + bloom into `news_glow.dart`.
2. **Copy** — apply `COPY.md` everywhere (`rung_words.dart` drop UTC; onboarding; home chip; paywall; gate strings).
3. **Shell / nav** — `adaptive_shell.dart`: labels **Home / Today / Log / Settings**. Load SVG from `shared/icons/nav-{home,today,log,settings}.svg` (replace unicode).
4. **Home** — one-hero busy + clear; dark + light. Match `phone/home-*.png`.
5. **Cover overlay** — arc, Stay out, Hold to look only, omit Hold for Block; glow on. Match `phone/gate-*.png`.
6. **Live Activity** four phases + Island compact/expanded. Match lock/DI PNGs + composites for placement intent.
7. **Notifications** — six rungs + Tomorrow's news + Android FSI. Match `phone/notif-*.png` · `android-fsi.png`.
8. **Screens** — Setup 1–3 · Today (flags + High-default filters) · Tomorrow's news · Log + streak · Daily limits · Settings groups · Paywall · Permissions.
9. **Tablet + desktop** — Home + cover; match `tablet/` · `desktop/`.
10. **Icons** — `final/icon/icon-1024.png` (+ mono / mono-dark) into Flutter launcher / themed icons.
11. **Assets** — add `shared/flags/` + `shared/icons/` to Flutter assets; use on Today / Tomorrow's news / nav.

---

## 7 · File map

| Deliverable | Code path |
|---|---|
| tokens.dart | `app/lib/theme/tokens.dart` |
| Glow | `app/lib/shell/news_glow.dart` |
| Phase | `app/lib/state/news_phase.dart` |
| Home | `app/lib/screens/home_screen.dart` |
| Today UI | `app/lib/screens/windows_screen.dart` |
| Tomorrow's news UI | `app/lib/screens/digest_screen.dart` |
| Log UI | `app/lib/screens/journal_screen.dart` |
| Daily limits | `app/lib/screens/tracker_screen.dart` |
| Settings | `app/lib/screens/settings_screen.dart` |
| Paywall | `app/lib/screens/paywall_screen.dart` |
| Permissions | `app/lib/screens/permissions_screen.dart` |
| Setup | `app/lib/onboarding/onboarding_flow.dart` |
| Shell | `app/lib/shell/adaptive_shell.dart` |
| Rungs | `app/lib/notifications/rung_words.dart` |
| Android cover | `GateActivity.kt` |
| iOS shield | `GuardShield.swift` |
| Live Activity | `GuardLiveActivity.swift` |
| Flags | Flutter assets ← `final/shared/flags/` |
| Nav icons | Flutter assets ← `final/shared/icons/` |

---

## 8 · Measurements cheat sheet

Phone **428×926** · gutter **18** · radius **8/10/12** · button **52** · home ring ~**168** · gate arc **240** / type **56** · glow **3pt** + bloom · hold **3s** · elevation **0**.

---

## 9 · Honest Flutter gaps (do not block on Jamie)

- Wire `shared/flags/` + `shared/icons/` into `pubspec.yaml` assets (boards already use them).
- Live Actual/Forecast/Previous: boards use sample figures; real feed wiring is product/backend.
- Composites = OS context boards; Island/LA/banner pixel spacing may differ on device — follow system APIs, keep copy/colour/phase from pack.
- Flag SVGs are geometric (public-domain style), not Apple SF Symbol flags — acceptable for ship.
- `shield-config-doc` is a copy/spec board, not a runtime screen.
- Production Live Activity uses SF fonts; Poppins stays in-app.
- StoreKit: price buttons must not look disabled while loading (ASSUMPTIONS #9).
- Optional open product nits (do not ask unless blocked): “Gold” vs “XAUUSD” on hero (boards lead **Gold · EUR CPI**); Block label for Pro; yearly default on paywall — treat board copy as default.

---

## 10 · Done when

- [ ] Tokens pasted; glow 3pt live on cover + phase surfaces
- [ ] Nav = Home / Today / Log / Settings with SVG icons; no Digest/Windows/Journal labels
- [ ] Tomorrow's news reachable, not a tab
- [ ] COPY.md strings on gate, notifs, home, paywall, setup; zero banned words in UI
- [ ] Today filters default High; impact colours only on rows/chips; flags from `shared/flags`
- [ ] Cover / LA / Island / shield / FSI match phase copy + colour intent
- [ ] Phone/tablet/desktop Home + cover match PNG density (surfaces, not flat Card defaults)
