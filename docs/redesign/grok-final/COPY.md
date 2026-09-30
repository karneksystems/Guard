## Journey

See `JOURNEY.md` for the stressed prop-trader path (setup → quiet day → night before → ladder → cover → log → Pro).

# Guard · customer copy (overhaul)

**IA:** Home · Today · Log · Settings. No Digest tab. No Windows tab.

**Banned in customer UI:** Soft gate, Soft cover, Gate, Digest, Night before, Conservative, instruments, Sample data, Firm match, UTC, Hold to view only, Hard block (as a phrase).

**Use:** Cover / Cover is on / Stay out / Hold to look only / Block / your firm's rules / local times / We never touch your trades.

Scenario: gold trader, EUR CPI, local 08:51, Today 8:55–9:05 unless clear.

---

## Calendar impact (Myfxbook-style)

| Level | Colour | Token | Use |
|---|---|---|---|
| Low | Green `#3DDC97` | `impactLow` | Calendar indicators only |
| Mid | Yellow `#E8C547` | `impactMid` | Distinct from phase amber `#F5A524` |
| High | Red `#E5484D` | `impactHigh` | Same as window-open; high news opens cover |

**Green is never** all-clear, success, Stay out, or phase status. Phase urgency (cover soon/open) stays amber/red edge glow. Impact colours live on event rows + filter chips only.

Filter chips: **Low · Mid · High** (multi-select). Default: **High only**. Show count per chip. Home “Also today” peek shows high-impact only (or respects the same filter).

---

## Nav

| Tab | Role |
|---|---|
| Home | One hero fact: next cover countdown or all clear |
| Today | Today's (and tomorrow's) schedule |
| Log | Stayed-out history + streak |
| Settings | Grouped controls |

Tomorrow's news is not a tab. It is a night-before notification + a card reachable from Home / Today / Settings → Alerts. Engineering file may stay `digest_screen.dart`.

---

## Home (one hero fact)

### Busy · soon (amber)

| Element | Copy |
|---|---|
| Brand | Guard |
| Status | Cover is on · gold, EUR |
| Phase | Opens soon |
| Countdown | 04:12 |
| Countdown label | until cover starts |
| Symbol | Gold |
| Event | EUR CPI |
| When | Today · 8:55–9:05 |
| Peek row | Also today · BoE Rate 10:55 *(high-impact only; respects Low/Mid/High filter)* |
| Metric strip | Loss room $1,880 · Days 3 of 4 · Tomorrow 1 |
| Foot | We never touch your trades. |

### Clear (nothing today)

| Element | Copy |
|---|---|
| Phase | All clear |
| Countdown / word | Clear |
| Label | nothing today |
| Body | No high impact news for you today. |
| Next | Next cover · Crude Inventories · Tomorrow · 13:25 *(High bars)* |
| Foot | We never touch your trades. |

Do not show: Soft gate, Conservative, Sample data, no backend configured, instrument jargon.

---

## Today (schedule · replaces Windows)

Myfxbook-style calendar rows. Impact colours on rows/filters only (not phase glow).

| Element | Copy |
|---|---|
| Title | Today |
| Sub | Tue 1 Oct · local times |
| Filters | Low · Mid · High *(multi-select chips with counts)* |
| Default filter | **High only** |
| Filter hint | Showing High · 2 mid & 2 low hidden |
| Section today | Cover windows |
| Row soon | 🇪🇺 EUR · EUR CPI · Cover 8:55–9:05 · High ▮▮▮ · 04:12 |
| Row later | 🇬🇧 GBP · BoE Rate Decision · Cover 10:55–11:05 · High ▮▮▮ · later |
| *(filtered)* | Chicago PMI Mid · speeches Low — hidden unless chips selected |
| Section next | Tomorrow · Wed 2 Oct |
| Row | 🇺🇸 USD · Crude Inventories · Cover 13:25–13:35 · High |
| Empty today | Nothing today. Tomorrow has one cover window. |

Phone row: time · currency/flag · title · impact bars · eta. Tablet/desktop may add Actual / Forecast / Previous columns when space allows.

---

## Gate / cover overlay (engineering: GateActivity · never say Gate to user)

| Element | Soon | Open | Block (Pro) |
|---|---|---|---|
| Kicker | Opens soon | Cover is on | Block is on |
| Countdown label | until cover starts | until you can trade again | until you can trade again |
| What | Gold · EUR CPI | same | same |
| When | Today · 8:55–9:05 | same | same |
| Mode | Cover · look ok | Cover · look ok | Block · no look |
| Promise | We never touch your trades. Looking is fine. Trading now may break your firm's rules. | same | We never touch your trades. Trading now may break your firm's rules. |
| Primary | Stay out | Stay out | Stay out |
| Secondary | Hold to look only | Hold to look only | *(omit)* |

---

## Live Activity

| Phase | Label | Count | Sub |
|---|---|---|---|
| Hour out | IN 1 HOUR | 59:12 | Gold · EUR CPI · cover at 8:55 |
| 5 min | OPENS SOON | 04:12 | Gold · EUR CPI · until cover starts |
| Open | COVER ON | 08:30 | Gold · EUR CPI · until 9:05 |
| Clear | ALL CLEAR | Clear | You're clear · trade at your pace |

### Dynamic Island

| Mode | Copy |
|---|---|
| Compact soon | SOON · 04:12 |
| Compact open | ON · 08:30 |
| Expanded soon | Opens soon · 04:12 · Gold · EUR CPI · cover at 8:55 |
| Expanded open | Cover on · 08:30 · Gold · EUR CPI · until 9:05 |

---

## iPhone Screen Time shield

| Field | Copy / colour |
|---|---|
| Title | Stay out of your trading app |
| Subtitle | Gold · EUR CPI until 9:05. We never touch your trades. |
| Primary | Stay out · bg #F5A524 · label #08306B |
| Secondary | Hold to look only · label #5BC8F5 · bg rgba(91,200,245,0.15) · omit for Block |
| Background | #08306B |

---

## Notifications (local times)

| Rung | Title | Body |
|---|---|---|
| 60 | Gold cover in 60 min | EUR CPI. Stay flat from 8:55 to 9:05. |
| 15 | Gold cover in 15 min | EUR CPI. Be flat by 8:55. |
| 5 | Gold cover in 5 min | EUR CPI. Close or hold. Cover starts at 8:55. |
| 1 | One minute · gold | EUR CPI. Hands off until 9:05. |
| open | Cover is on · gold | EUR CPI. Stay out until 9:05. |
| clear | You're clear · gold | Cover ended. Trade at your own pace. |

### Tomorrow's news (night-before alert · not a tab)

| | Copy |
|---|---|
| Title | Tomorrow: 1 high impact window |
| Body | Tomorrow's news is ready. Gold · Crude Inventories at 13:25. Cover is on. |
| In-app title | Tomorrow's news |
| In-app sub | Wed 2 Oct · local times |
| Filters | Low · Mid · High · default **High only** · show counts |
| Row | 🇺🇸 USD · Crude Inventories · Cover 13:25–13:35 · High ▮▮▮ |

### Android full-screen alarm

| Element | Copy |
|---|---|
| Kicker | Cover is on |
| Label | until you can trade again |
| Detail | Gold · EUR CPI · Today · 8:55–9:05 |
| Promise | We never touch your trades. |
| Primary | Stay out |
| Secondary | Hold to look only |

---

## Setup (3 steps · journey 0)

| Step | Title | Body | CTA |
|---|---|---|---|
| 1 | What do you trade? | Pick what Guard should watch. Free watches two. We cover **High** impact by default. | Continue |
| 1 choices | Gold / EUR pairs / US indices / GBP pairs | High impact that moves gold · Euro news · CPI, ECB · … | — |
| 2 | Alerts and apps | So Guard can warn you and cover MT5 when High news hits. | Continue |
| 2 rows | Notifications (60·15·5·1) / Cover trading apps (MT5, MT4) / Alarms on time / Tomorrow's news | We never touch your trades. | — |
| 2 warn | Alarms still off | Turn on Alarms on time or cover may land late. | — |
| 3 | You're set | Cover is on for gold and EUR. First High window today: *(EUR CPI preview row)* | Go to Home |
| 3 body | We'll warn you at 60, 15, 5 and 1 minute, then cover the app when news opens. | We never touch your trades. | — |

---

## Log (was Journal)

| Element | Copy |
|---|---|
| Title | Log |
| Sub | You stayed out. That's the win. |
| Streak | 12 stayed out this month |
| Streak sub | Your best month yet |
| Outcome labels | Stayed out · Looked · Traded anyway |
| Empty | No covers yet. When news hits, your stay-outs show up here. |

---

## Tracker (inside Settings or Log · keep plain)

| Element | Copy |
|---|---|
| Title | Daily limits |
| Loss | Loss room · $1,880 of $2,500 · 75% left |
| Days | Trading days · 3 of 4 · 1 to go |
| CTA | Log today's P&L |

---

## Settings (grouped)

| Group | Rows |
|---|---|
| Cover | Mode · Cover · look ok / Apps covered · MT5, MT4 / Window · 5 min before and after |
| What you trade | Watching · gold, EUR / Your firm's rules · None · Free |
| Alerts | Warnings · 60 · 15 · 5 · 1 / Tomorrow's news *(toggle)* |
| Account | Plan · Free / Go Pro / Permissions |
| Foot | We never touch your trades. |

Never: Firm match, Conservative, instruments, Soft gate.

---

## Paywall

| Element | Copy |
|---|---|
| Context | When Free isn't enough |
| Headline | Your firm's exact rules |
| Sub | Pro adds your firm's rules, Block, unlimited markets, and a full stay-out log. |
| Monthly | £4.99 a month |
| Yearly | £39 a year · £3.25/mo · BEST VALUE |
| Features | Your firm's rules, matched · Block (no look) · Unlimited markets · Full log + streak · Custom cover windows · No ads |
| CTA | Start Pro · £39/year |
| Foot | Cancel anytime. We never touch your trades. |

Drop old headline "Precision, not safety". Never grey out prices while loading.

---

## Permissions (Android)

| Row | Why |
|---|---|
| Notifications | Warnings and Tomorrow's news |
| Usage access | See when MT5 is in front |
| Display over apps | Show the cover |
| Alarms on time | Cover on the minute |
| Full screen alarms | Alarm style when locked |
| Battery unrestricted | Keep watching in the background |
| Foot | We never read your trades or log into any account. |
