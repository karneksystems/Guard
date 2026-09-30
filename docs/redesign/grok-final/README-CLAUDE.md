# Guard redesign — start here (Claude)

1. **Open `HANDOFF-Claude.md` first** — locked IA, tokens, banned words, build order, file map, honest gaps.
2. **Then `COPY.md` + `tokens.dart`** — every customer string + paste-ready Flutter tokens (`→ app/lib/theme/tokens.dart`).
3. **PNGs are visual source of truth** — `phone/` · `tablet/` · `desktop/`. Match density, layout, phase colour.
4. **`composites/`** = OS context only (Island / LA / banner / MT5 overlay). Do not treat as in-app Flutter chrome.
5. **Wire assets** — `shared/flags/*.svg` on calendar rows; `shared/icons/nav-*.svg` in the tab shell.

IA: **Home · Today · Log · Settings**. Tomorrow's news is **not** a tab.

Banned UI words: Soft gate, Gate, Digest, UTC, Hold to view only, Hard block, … — full list in HANDOFF / COPY.
