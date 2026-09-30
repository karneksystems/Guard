# Guard · design tokens

**Direction B · Precision Field**, with **C’s ~3pt phase edge glow + soft bloom**.
Paste `tokens.dart` over `app/lib/theme/tokens.dart`.

## Colour

| Token | Hex / value | Use |
|---|---|---|
| `brand` | `#0B5CAD` | Primary actions (light), brand |
| `brandDeep` | `#08306B` | Icon gradient, shield bg, Stay out text on amber |
| `sky` | `#5BC8F5` | Primary (dark), links, clear accents, promise accents |
| `amber` | `#F5A524` | News within 5 min only |
| `red` | `#E5484D` | Window open only |
| `impactLow` | `#3DDC97` | Calendar low-impact only (green) |
| `impactMid` | `#E8C547` | Calendar mid-impact (yellow ≠ amber) |
| `impactHigh` | `#E5484D` | Calendar high-impact (= `red`; opens cover) |
| `impactNone` | `#7C8794` | Calendar no-impact / none (cool grey) |
| `statusClear` | `#7C8794` | Clear / later (never green) |
| `inkBg` | `#070D18` | Dark scaffold |
| `inkSurface` | `#0C1422` | Dark cards |
| `inkSurfaceRaised` | `#121C2E` | Dark metrics |
| `inkText` | `#EDF2F8` | Dark text |
| `inkTextMuted` | `#8B9AAE` | Dark secondary |
| `inkHairline` | `#1A2740` | Dark borders |
| `paperBg` | `#F1F5FA` | Light scaffold |
| `paperSurface` | `#FFFFFF` | Light cards |
| `paperSurfaceRaised` | `#E6EEF7` | Light metrics |
| `paperText` | `#0A1524` | Light text |
| `paperTextMuted` | `#5A6A7E` | Light secondary |
| `paperHairline` | `#D0DBE8` | Light borders |
| `phaseGlowAmber` | `rgba(245,165,36,0.28)` | Soft bloom wash |
| `phaseGlowRed` | `rgba(229,72,77,0.32)` | Soft bloom wash |
| glow core amber | `rgba(245,165,36,0.90)` | 3pt inset edge |
| glow core red | `rgba(229,72,77,0.95)` | 3pt inset edge |

**Green is only for low-impact calendar indicators** (`impactLow`). Never for all-clear, success, Stay out, or phase status.
Mid uses distinct yellow `#E8C547` (not phase amber `#F5A524`). High reuses `#E5484D` — high news *is* what opens cover.
Phase urgency (cover soon/open edge glow) stays amber/red. Calendar impact colours live on event rows + filter chips only.

## Glow (maps to `news_glow.dart`)

| Prop | Value |
|---|---|
| Width | **3pt** inset edge (C, not B’s 1.5pt hairline) |
| Soft bloom | inset blur ~40pt at 0.28 / 0.32 alpha |
| Outer | ~32pt at 0.45 / 0.50 alpha |
| Breath | opacity ±15% over ~2.4s ease-in-out |
| Visibility | Inside app + gate; later Android/desktop click-through over charts |

CSS reference (from boards):

```css
box-shadow:
  inset 0 0 0 3px var(--gc),
  inset 0 0 40px var(--gs),
  inset 0 0 80px var(--gm),
  0 0 32px var(--go);
```

## Type

| Role | Family | Size | Weight |
|---|---|---|---|
| Gate countdown | Poppins | 56 | 600 |
| Home ring countdown | Poppins | 28 | 600 |
| Live Activity count | Poppins (SF in prod) | 36 | 600 |
| Page title | Poppins | 28 | 600 |
| Symbol (XAUUSD) | Poppins | 24 | 600 |
| Title | Poppins | 20 / 16 | 600 |
| Body | Inter | 17 / 15 / 13 | 400–500 |
| Label / kicker | Inter | 12 / 11 / 10 | 600–700 |
| Tabular nums | on all countdowns | — | — |

## Spacing / radius / elevation

| Scale | Values |
|---|---|
| Spacing | 2, 4, 8, 10, 12, 16, **18 gutter**, 20, 24, 28, 32 |
| Radius | 8 buttons, 10 metrics, **12 cards/rail**, 16 Live Activity |
| Elevation | **0** (hairline borders only) |
| Button height | 52 |
| Hold ring | 3s progress on secondary |

## Phase colour rules

- Amber / red **only** for phase urgency (hero, gate, glow, Live Activity countdown).
- Later / clear: sky (dark) or brand (light) / cool grey — **never green**.
- Calendar impact bars/dots: green / yellow / red for Low / Mid / High on event rows + filters only.
- List rows: red impact bars mean high-impact news, not “window open” phase (phase still uses edge glow).
