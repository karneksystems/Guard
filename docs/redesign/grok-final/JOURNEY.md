# Guard · user journey (stressed prop trader)

Persona: funded gold/EUR trader. Local morning. Firm bans news trading. Hands shake; copy must be plain. **Cover** language only — never Soft gate / Digest / Gate.

Visual: B + C glow · calendar impact Low green / Mid yellow `#E8C547` / High red `#E5484D` · default filter **High only**.

---

## Journey map

| # | Moment | Screen / surface | One job | Feedback they need |
|---|---|---|---|---|
| 0 | First open | Setup 1 → 2 → 3 | Pick markets · turn on cover · confirm | Progress dots · what Free vs Pro watches |
| 1 | Quiet day | Home clear | One fact: nothing high today | Next High cover · no green “success” |
| 2 | Night before | Notif + Tomorrow’s news | Know tomorrow’s High windows | Count · time · Cover is on |
| 3 | T-60…T-1 | Push ladder | Get flat without jargon | Local times · same event name every rung |
| 4a | Cover soon | Home busy + gate amber + Live Activity | Countdown to cover | Amber glow · Stay out ready |
| 4b | Cover on | Gate red / Block / FSI / shield | Stay out (or Hold to look) | Red glow · Hold progress · never touch trades |
| 4c | Clear | Notif clear + Home | Trade at your pace | Cool grey/sky — **not green** |
| 5 | After | Log | Streak reward for staying out | Stayed out / Looked / Traded anyway |
| 6 | Need firm rules | Paywall (from Settings / soft prompt) | Pro = firm’s exact rules + Block | Prices never greyed while loading |

---

## Step-by-step (happy path)

### 0 · First open — 3-step setup

1. **What do you trade?** Multi-select. Free = two. Subcopy ties to **High impact** (what actually opens Cover). Gold + EUR selected in boards.
2. **Alerts + apps.** Notifications, Cover trading apps (MT5/MT4), Alarms on time, Tomorrow’s news. Incomplete alarms → plain warning: cover may land late.
3. **You’re set.** Recap: Cover on for gold + EUR · first **High** window today · ladder 60/15/5/1 · Go to Home.

**Confusing before fix:** Step 2 titled “Turn on cover” while mixing OS permissions; Alarm left off with no consequence. Step 3 was a lonely glyph — no preview of the first window.

### 1 · Quiet day

Home: **All clear** / Clear / nothing today. Body: “No high impact news for you today.” Next cover row with High bars. Metrics still visible. **Never green.**

**IA fail risk:** Trader taps Today, sees empty High filter, thinks app broken — hint “Showing High · N mid & N low hidden” is required.

### 2 · Night before

- Push: **Tomorrow: 1 high impact window** · Gold · Crude Inventories at 13:25. Cover is on.
- In-app Tomorrow’s news: High-default chips · Myfxbook row · Cover plan · loss room peek.
- Reach from: notif tap · Home Tomorrow metric · Today · Settings → Alerts. **Not a tab.**

**Missing before fix:** No dedicated tomorrow notif board in the pack.

### 3 · T-60…T-1 ladder (plain English)

| Rung | Title | Body job |
|---|---|---|
| 60 | Gold cover in 60 min | Name event · stay flat window |
| 15 | Gold cover in 15 min | Be flat by start |
| 5 | Gold cover in 5 min | Close or hold · cover starts |
| 1 | One minute · gold | Hands off until end |

Same event string (EUR CPI) every rung. Local times only. Opens soon Home + amber glow by T-5.

**Confusing if broken:** Mixing UTC, renaming the event mid-ladder, or “Soft cover in 5.”

### 4 · Cover soon → Cover on → Clear

- **Soon:** Home hero countdown · gate amber · Live Activity OPENS SOON · Hold to look only available · Impact High on gate panel.
- **On:** Gate red (or Block, no Hold) · Stay out primary · Android FSI / iOS shield same words.
- **Clear:** Push “You’re clear · gold” · Home returns to clear or next High · Log records outcome.

**Missing feedback before fix:** Gate “Promise” cell duplicated foot copy; Impact not shown on cover surface. Hold ring easy to miss.

### 5 · Log streak reward

Streak banner is the Discord-shaped win: **N stayed out this month**. Rows: event · market · time · Cover · outcome (Stayed out / Looked / Traded anyway). High impact marks on rows so the log matches Today.

**IA fail:** Calling it Journal; burying streak under Settings.

### 6 · Pro when they need firm rules

Entry: Settings → Account → Go Pro, or soft prompt when Free hits a firm-rules wall. Headline: **Your firm’s exact rules.** Features: firm rules · Block · unlimited markets · full log + streak. Yearly default. Never “Precision, not safety.”

**Confusing if:** Paywall appears on first open before Cover works; or prices look disabled while StoreKit loads.

---

## Confusing steps · missing feedback · IA fails

| Issue | Why it hurts | Fix in this pack |
|---|---|---|
| Setup 2 = “permissions laundry” | Stressed trader doesn’t know which toggle matters | Rename to alerts+apps · list MT5/MT4 · warn if Alarms off |
| No tomorrow notif mock | Night-before moment invisible in handoff | `notif-tomorrow` board |
| Today empty on High-only | Looks broken | Filter hint + counts |
| Green = clear (old habit) | Violates Jamie lock | Green **only** Low impact calendar |
| Soft gate / Digest / Journal | Engineer words under stress | Cover / Tomorrow’s news / Log |
| Home peek showed Mid PMI | Default should be High-only | Peek = BoE Rate High only |
| Log without streak weight | No reward loop | Premium streak banner + impact on rows |
| Paywall with no “why now” | Feels random | Context line: firm rules when Free isn’t enough |
| Ladder event name drift | Trust breaks | Same EUR CPI string on every rung |
| Hold to look with no progress | Looks like a dead button | Hold ring + 3s copy in boards |

---

## Alignment checklist (ship)

- [x] Setup 1 markets · High-impact framing · Free = two  
- [x] Setup 2 alerts + apps + Tomorrow’s news · alarm warning  
- [x] Setup 3 first High window preview · ladder promise  
- [x] Home clear · no green · next High  
- [x] Tomorrow notif + Tomorrow’s news screen · High default  
- [x] Notif ladder plain English · local times  
- [x] Cover soon/on/clear · Stay out / Hold · Impact on gate  
- [x] Log streak + outcomes · calendar impact marks  
- [x] Paywall firm rules · Cover language  
- [x] Today Myfxbook rows · Low/Mid/High filters · High default  

---

## Files

Boards: `phone/setup-1|2|3`, `home-clear-*`, `notif-*` + `notif-tomorrow`, `tomorrows-news*`, `gate-*`, `home-busy-*`, `today*`, `log`, `paywall`.  
Copy: `COPY.md` · Tokens: `TOKENS.md` / `tokens.dart` · Premium roast: `AUDIT-PREMIUM.md` · Calendar research: `MYFXBOOK-CALENDAR-NOTES.md`.
