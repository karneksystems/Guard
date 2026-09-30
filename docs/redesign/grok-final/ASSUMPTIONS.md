# Guard · assumptions (overhaul)

Ground-up customer experience rewrite. Visual language: **B Precision Field + C 3pt glow**. IA and copy are new.

## Information architecture

| Tab | Purpose |
|---|---|
| **Home** | One hero fact: countdown to next cover, or all clear |
| **Today** | Schedule (replaces Windows jargon) |
| **Log** | Stay-out history + streak (replaces Journal) |
| **Settings** | Grouped: Cover / What you trade / Alerts / Account |

**Tomorrow's news** is a night-before notification + in-app screen, **not a tab**. Engineering may keep `digest_screen.dart` / `windows_screen.dart` / `journal_screen.dart` file names; customer labels must match the table.

## Banned customer words

Soft gate · Soft cover · Gate · Digest · Night before · Conservative · instruments · Sample data · Firm match · UTC · Hold to view only · Hard block (as customer phrase).

## Required customer words

Cover · Cover is on · Stay out · Hold to look only · Block · your firm's rules · local times · We never touch your trades.

## Product pushbacks

1. Old home was a jargon status line + identical list rows. Hero is now **one fact**.
2. "Windows" / "Digest" / "Journal" read as engineer words. Today / Tomorrow's news / Log.
3. Paywall "Precision, not safety" is gone. **Your firm's exact rules.**
4. Settings grouped; Daily limits live under Account (not a fifth tab).
5. Gold spoken as **Gold**, not only XAUUSD, on customer surfaces (symbol codes OK in Today detail).
6. Glow is C's 3pt + bloom inside the app and on the cover overlay. iPhone cannot glow over other apps.
7. Live Activity uses SF fonts in production; boards use Poppins.
8. Gate/Lock dark-first; Home has light.
9. Price buttons must not look disabled while StoreKit loads.
10. Log streak is the Discord reward. Ship it on Pro; teaser on Free is optional.

## Open for Jamie

- Confirm "Gold" vs "XAUUSD" on Home hero (we lead with Gold · EUR CPI).
- Confirm Block label for Pro hard-block mode.
- Confirm yearly default on paywall.

## Calendar impact (Jamie lock)

- News impact like Myfxbook: **Low = green**, **Mid = yellow `#E8C547`**, **High = red `#E5484D`**.
- Green is **only** for low-impact calendar indicators. Never for all clear / success / Stay out.
- Mid yellow is distinct from phase amber `#F5A524` so filters ≠ urgency glow.
- High reuses window-open red — high news *is* what opens cover.
- Phase urgency (cover soon/open) stays amber/red edge glow. Calendar impact colours on event rows/filters only.
- Filter chips Low · Mid · High, multi-select, **default High only**, with counts.
- Home “Also today” peek: high-impact only (or respect filter).
- Rows: country/flag or currency icon, title, time, impact bars (1–3). Phone collapses to impact + time + title; tablet/desktop may show Actual/Forecast/Previous.
- No-impact/none = cool grey (not green). See `MYFXBOOK-CALENDAR-NOTES.md` for Myfxbook parity research; **Guard default remains High-only** (Jamie), even if Myfxbook often shows all levels.
