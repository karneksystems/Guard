# Guard · composites + OS densify note

Pass after premium app screens. Jamie picked **B + C**: springboard composites + polish gaps.

## What landed

### A · Springboard composites (`final/composites/`)
10 full-phone PNGs — quiet / soon / on / clear / banner stack / MT5 overlay. See `composites/README.md`.

### B · Polish gaps
1. **Flags** — emoji replaced with geometric SVG flags under `shared/flags/` (eu, us, gb, jp, ca, au, ch, cn). Wired via `flag_img()` / `ccy_badge()` in `generate_screens.py`. Visible on Today, Today light, Tomorrow's news (+ light), setup-3 preview row.
2. **Nav icons** — unicode ◈◷☰⚙ replaced with inline SVG (Home / Today / Log / Settings). Also stored as `shared/icons/nav-*.svg` for Flutter handoff.
3. **OS densify** — lock Live Activities, DI compact/expanded, android-fsi, shield-mock, notif-* got heavier surfaces, Guard icon chips, glanceable High / cover / A-F-P micro where space allows. CSS in `shared/premium.css` (OS density pass).

## Docs touched
- `composites/README.md` · this file · `AUDIT-PREMIUM.md` · `INDEX.md` · `HANDOFF-Claude.md`

## Remaining gaps (honest)
- Flag SVGs are geometric simplifications (public-domain style), not Apple SF Symbols flags.
- Composites are design boards — Island / LA / banner coexistence is illustrative; real iOS layout spacing may differ slightly.
- `shield-config-doc` not re-dense-passed (still valid copy table).
- Flutter still needs SVG nav + flag assets wired from `shared/icons/` and `shared/flags/`.
