# Guard redesign final pack (overhaul)

Visual: **B Precision Field + C 3pt glow**. CX: ground-up rewrite.

## Docs
- JOURNEY.md — end-to-end trader path + IA fails
- AUDIT-PREMIUM.md — premium roast + fixes
- MYFXBOOK-CALENDAR-NOTES.md — calendar research
- README-CLAUDE.md — open this first (one-pager)
- HANDOFF-Claude.md — build order + file map (build-ready)
- COPY.md — every customer string
- TOKENS.md + tokens.dart — paste into Flutter
- ASSUMPTIONS.md — IA + pushbacks

## Phone PNGs (428×926) — final/phone/
gate-amber, gate-red, gate-hard-block (Block), home-busy-dark/light, home-clear-dark/light, edge-glow-detail, lock-sky-hour, lock-amber-5min, lock-red-open, lock-sky-clear, di-compact, di-expanded, shield-mock, shield-config-doc, notif-60/15/5/1/open/clear/tomorrow/tomorrow, android-fsi, setup-1/2/3, today, today-light, tomorrows-news, tomorrows-news-light, log, tracker, settings, paywall, permissions

## Tablet / Desktop
final/tablet/{home,gate-amber,gate-red}.png
final/desktop/{home,gate-amber,gate-red}.png

## Icon
final/icon/icon-1024.{png,svg} · icon-mono.{png,svg} · icon-mono-dark.{png,svg}

## Composites (Springboard / lock / overlay)
final/composites/ — home-quiet, home-island-soon/on, lock-hour/soon/on/clear, lock-banner-60, unlocked-banner-open, overlay-mt5
See composites/README.md · COMPOSITES.md

## HTML sources
final/html/*.html · final/html/composites/ · shared/{guard,premium,composites}.css
Flags: shared/flags/ · Nav SVG: shared/icons/

## IA
Home · Today · Log · Settings. Tomorrow's news is not a tab.

## Calendar impact
Low green `#3DDC97` · Mid yellow `#E8C547` · High red `#E5484D`. Default filter High only. Green never for clear/success.
- MYFXBOOK-CALENDAR-NOTES.md · AUDIT-PREMIUM.md
