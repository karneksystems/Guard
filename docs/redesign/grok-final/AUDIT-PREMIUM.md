# Guard · premium audit (roast + fixes)

Audit after calendar impact work. Visual: B Precision Field + C glow. Language: Cover locked.

## Roast of current finals (pre-pass)

The pack read like a tidy Flutter starter kit, not a paid prop-desk instrument.

1. **Flat cardboard surfaces.** Cards were one fill + 1px hairline. No inset highlight, no surface stack, no vignette. Looked like `Card(elevation: 0)` defaults.
2. **Sparse air.** Huge empty gutters under titles and between three lonely metric tiles. Premium densifies; template pads.
3. **Weak type ladder.** Page title 28 / body 13 / label 11 with soft opacity was the only hierarchy. Kickers didn’t bite; values didn’t sit on a rail.
4. **Calendar was a toy list.** Time · dot · “Gold · Event” · badge. No flag/currency weight, no impact bars, no Actual/Forecast/Previous. Myfxbook this was not.
5. **Impact colour conflict unresolved in pixels.** Docs said green/yellow/red; rendered Today still used phase amber/sky dots. Filters absent. Home peek still dumped Mid Chicago PMI.
6. **Gate felt like a modal mock.** Uniform navy wash, thin L-corners, info grid floating on void. Arc had no track depth. Stay out was a flat Material fill.
7. **Home hero was a sticker.** Ring on a plain card, chip looked like a Chip widget, metrics were three identical boxes with no inner structure.
8. **Nav icons were unicode placeholders** at 0.4 opacity — free-template tell.
9. **Glow did the heavy lifting** while surfaces stayed cheap. Edge bloom cannot rescue empty hierarchy.
10. **Light mode worse** — paper white cards with the same sparse rhythm, no paper depth.

## Jamie conflict resolve (locked in pass)

| Role | Colour | Where |
|---|---|---|
| Low impact | Green `#3DDC97` | Calendar rows + filter chips only |
| Mid impact | Yellow `#E8C547` | Same (≠ phase amber `#F5A524`) |
| High impact | Red `#E5484D` | Same (= window-open red; OK) |
| Phase soon/open | Amber / red edge glow | Gate, home ring, Live Activity — never green for clear |

Default filter: **High only**. Home “Also today” = high only.

## Fixes applied (this pass)

### Tokens / CSS
- Layered ink backgrounds (radial vignette + vertical wash).
- Card surfaces: raised gradient, top inset hairline light, stronger border (`ink-hair` + sky/amber whisper on phase).
- Premium type: tighter kickers (0.14em / w700), denser body, tabular values on a clearer scale.
- Filter chips: solid selected fills, swatch + count, pill weight.
- Calendar rows: flag+ccy badge, 3-bar impact, cover window, A/F/P micro stats, eta chip.
- Gate: vignette, denser info cells as mini panels, Stay out with gradient + inner top light, hold ring thicker.
- Home: hero with phase wash, peek as structured high-impact rail, metrics as one segmented strip.
- Nav: active sky underline, heavier label weight.

### Screens regenerated
- phone: today, today-light, tomorrows-news, tomorrows-news-light, home-busy-dark/light, home-clear-dark/light, gate-amber/red/hard-block, edge-glow-detail
- tablet/desktop home (high-only peek)

### Docs
- COPY / TOKENS / tokens.dart / ASSUMPTIONS / HANDOFF / INDEX already carry impact rules; this audit records the premium bar.
- `MYFXBOOK-CALENDAR-NOTES.md` folded (flag+currency, A/F/P, none=grey; Guard default stays High-only).

## Still not shipping (honest)

- Live Actual/Forecast wiring (boards use sample figures).
- Flutter must wire `shared/flags/` + `shared/icons/nav-*.svg` (boards already use them).
- Composites are illustrative OS context; device spacing may differ.

## Follow-on · composites + OS densify (B+C)

- Flags: geometric SVG assets (eu/us/gb/…) replace emoji on calendar rows.
- Nav: SVG Home / Today / Log / Settings replace unicode.
- OS templates densified: lock LA, DI, notif, shield-mock, android-fsi.
- Springboard composites: `final/composites/` (≥10) — see COMPOSITES.md + composites/README.md.

## Pass / fail

| Check | Result |
|---|---|
| Looks like free Flutter template | Fail → fixed surfaces/type/density |
| Calendar Myfxbook-weight + High default | Pass (boards) |
| Green only for low impact | Pass (tokens + CSS scoped) |
| Cover language | Pass |
| Gate/home expensive | Pass (boards; Flutter must match tokens) |

## Journey pass (follow-on)

See `JOURNEY.md`. Setup 2 → Alerts and apps + alarm warning; setup 3 previews first High window; `notif-tomorrow` added; Home clear Next cover High peek; Log shows Traded anyway + impact bars; Paywall context “When Free isn’t enough.”
