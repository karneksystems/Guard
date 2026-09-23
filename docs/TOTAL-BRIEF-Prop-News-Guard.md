# Prop News Guard — total brief

**From:** Jamie Stephens / Stanchion Systems · 23 Sep 2026 · **Working title only, brand TBD**
**Flow:** this brief → Grok (visuals + concepts) → CC (build). Read `CLAUDE-HANDOFF-Prop-News-Guard.md` for the full product detail; where they differ, **this brief wins**.

---

## Part A — the product (for everyone)

### What it is
A free multi-device guard for manual prop-firm traders (no EA, no VPS). Same product on **phone, tablet, and desktop** — people trade on all three. It stops them breaching accounts by trading into restricted news windows, and later by other prop rules.

### The one line
"Your firm can't see us. We never touch your trades."

### Non-negotiables
- **Never open, close, edit or modify any trade or order.** No master password. No trade API.
- **Invisible to the firm.** The MVP never logs into an account and never runs on a terminal. Nothing the firm can detect or object to.
- **No invented rules.** Firm packs are versioned, sourced, dated. Unknown means not allowed.
- **No signals, no advice.** It warns about rules. It never says what to trade.

### How it protects (user picks)
- **Warn only:** alerts and timer, MT5 always opens.
- **Soft gate (default):** opening / focusing MT5 (or the chosen trading app) in a restricted window shows a full-screen gate with countdown. Stay out, or hold 3 seconds to view only. Viewing is fine, trading may breach. Same behaviour on phone, tablet, and desktop.
- **Hard block:** trading apps locked until the window ends (OS-dependent; Pro).

### Devices (Jamie lock, 22 Sep 2026)
- **Phone, tablet, and desktop are all in scope** — not phone-only.
- **Desktop:** Windows first for Soft gate (where most MT5 desktop trading happens). macOS alerts + Soft gate as far as APIs allow.
- **Tablet:** same Soft gate / alerts as phone; UI scales (not a stretched phone layout).
- Shared codebase still preferred (React Native / Flutter + desktop targets, or thin native companions that share the rule engine and calendar). Architecture must not assume a phone-only gate.

### Rule modes
- **Conservative (default):** high-impact events whose currency touches the user's instruments. Gold's basket is USD + EUR + GBP, editable. This is the "EUR CPI at 08:00 while in gold" fix.
- **Firm match (Pro):** the firm's official pack. Window, eval vs funded, event list, instrument map, source link, verified date.

### Free vs Pro
Free stops the breach. Pro buys precision and convenience. **£4.99/month or £39/year, one SKU.** Apple IAP on iPhone, accepted at this price.

**Free**
- High-impact calendar, Conservative basket
- Soft gate on 1–2 instruments
- Alert ladder (T−60, T−15, T−5, T−1, open, end) delivered as **real push notifications** on every supported device (not in-app only). Phone/tablet: iOS Time Sensitive + APNs; Android full-screen intent / FCM + alarm-style repeat until dismissed. Desktop: Windows / macOS push (or OS notification centre with actionable Restricted Window alerts) so a trader gets the ladder even when the app is closed or another monitor has MT5. A quiet single ping is the failure mode.
- Default ±5 min window
- Night-before "big day" digest (tomorrow's NFP / CPI / FOMC etc.)
- Gate journal, last 7 days (stayed out / viewed / traded anyway, self-reported)
- Weekend hold warning
- Manual daily-loss tracker (user enters P&L, app says how much room is left)
- Minimum trading days countdown
- Inactivity reminder
- Source strip on every event (calendar source, date)
- Light ads, never on the gate screen

**Pro**
- Unlimited instruments
- Firm match packs, all firms, with "rules changed" flag and changelog
- Custom windows (presets 2/3/5/10 and custom before/after)
- Hard block
- Full journal history and streak
- No ads

**v1.1 (parked, not launch):** session cut-offs per firm, medium-impact events, multi-account, lock-screen widget, watch glances, ICS export.
**v1.2:** investor-password read-only, opt-in, **only where the firm pack says `investorPasswordAllowed: yes` with a source**. Unlocks drawdown warnings from real equity. Unknown = no.
**Later:** revenge-trade cool-down, iOS full app shield entitlement.

### The hub (designed in, built later)
A community layer: profiles, payout proofs, leaderboard, comments. **Not in the launch build.** It can't be tested empty and unverified payout screenshots become fake-central. But it must not look bolted on later, so the skeleton is built now: a profile object, a hidden nav slot, a data model with room for posts and payouts. Hub features stay dark until the guard has users.

### Data and platform
- Licensed calendar API, not scraped ForexFactory. **Cost it before build**, it's the biggest running cost of a free app.
- **Push notifications are required** (Jamie lock, 22 Sep 2026): server-scheduled alert ladder via APNs + FCM (+ desktop push / OS notifications). Local-only reminders are not enough — timezone changes, killed apps, and desktop multitasking need reliable remote push. Cost push infra with the calendar vendor.
- **Gate / Soft gate:** Android phone/tablet first (overlay / accessibility, like focus apps). **Windows desktop Soft gate in the same launch MVP track** (detect MT5 launch/focus during a window → full-screen gate). iOS / iPadOS: push + Soft gate as far as APIs allow; full shield entitlement is Phase 1.5, not a launch blocker. macOS: push + Soft gate as APIs allow.
- Shared codebase (React Native / Flutter with desktop targets, or mobile + Windows companion sharing one backend). Small backend: calendar sync, **push scheduling**, rule-pack JSON, Pro auth.
- Store UTC, display local, warn on timezone mismatch. Broker server time vs calendar time is where "2 minutes before" becomes an hour off.

### Naming
Not "News Guard" alone (NewsGuard Technologies). No firm names in the title. No lookalikes of TradeLocker / LockMyTrades / PropFirmVerifier. Brand TBD after Grok's concepts.

---

## Part B — brief for Grok (visuals and concepts)

You're designing the look, feel and character of the app described in Part A. We build from your concepts, so make them real and specific.

**Who it's for:** a manual prop trader on phone, tablet, or desktop, often a few minutes before a news event, stressed, about to make a mistake. The UI has to be instantly readable in that moment on every form factor.

**Tone:** calm, plain, trustworthy. The opposite of trading-app hype. No neon, no candlesticks on fire, no rockets, no gold bars, no dollar signs. Think a good weather app or a well-made alarm clock, not a trading terminal.

**Design tone (Jamie lock, 22 Sep 2026):** OTTO craft on cool ink — Poppins display / Inter body, metal accent `#AE9558` + champagne hairlines, flat metal buttons. **No greens** (no sage/mint/jade brand or chrome; status chips metal or cool grey). Full tokens in `DESIGN-CONCEPTS-Grok.md`. Does not change product rules above.

**Deliver:**
1. **Three name + identity directions.** Each with a name, a one-line rationale, a simple mark or icon, and a colour direction. Check none clash with the names in the Naming section. Ownable, short, sayable.
2. **The gate screen**, the most important screen in the app. Full-screen, countdown, event name, instrument, the "we never modify your trades" line, two actions: Stay out / Hold to view only. Show it as it would look 90 seconds before EUR CPI for a gold trader.
3. **The alert.** Lock-screen notification and the full-screen alarm state. It has to be impossible to ignore without being ugly.
4. **Home screen.** Today's windows, next event countdown, protection mode, the daily-loss tracker, minimum-days countdown. Scannable in two seconds.
5. **Onboarding**, six steps: protection mode, instruments, rule mode (+ firm if Firm match), window default, which apps to gate, the "we never touch your trades" explainer.
6. **Night-before digest** notification and screen.
7. **Journal** view.
8. **Pro paywall**, one SKU, £4.99 / £39, honest, no dark patterns.
9. **Hub placeholder:** a profile screen and where the hub would live in nav, so it's designed in from the start even though it ships dark.
10. **Multi-device:** phone + tablet layouts, plus a **desktop Soft gate / home** reference (Windows-first). Android and iOS variants where the OS differs (gate overlay on Android; Time Sensitive push on iOS). Show the push / lock-screen alert states — push is required, not optional.

**Rules:** flat, legible, big type where it matters, works one-handed. Every screen must read at a glance under stress. Show the source strip on events. Never show a firm's logo. Ads, if shown, never on the gate.

**Output:** concept boards per direction, then full screens for the chosen direction, exportable as reference for the build. Note any assumptions.

---

## Part C — brief for CC (build)

Build from the chosen Grok direction and Part A.

**Order**
1. Skeleton: shared app, backend, calendar sync, rule engine (Conservative baskets + firm-pack JSON schema), profile object and hidden hub nav slot.
2. Onboarding and settings, all editable after install.
3. Push pipeline + alert ladder with un-ignorable delivery (APNs Time Sensitive, FCM / Android full-screen intent, alarm repeat, desktop OS notifications).
4. Soft gate on Android (phone/tablet) **and Windows desktop** (MT5 focus/launch). iOS / iPadOS / macOS soft gate as far as APIs allow.
5. Free features: digest, journal (7 days), weekend warning, daily-loss tracker, min-days, inactivity, source strip — on phone, tablet, and desktop shells.
6. Pro: IAP/Play/desktop store billing as applicable, one SKU, firm packs (start FTMO, FundingPips, FundedNext, Alpha Capital, Blue Guardian from `PROP-FIRM-RULES.md`, all marked `needsReverify: true` until checked), custom windows, hard block, journal history, no ads.
7. Store submission: mobile stores + desktop distribution plan (Microsoft Store / signed installer — decide in architecture).

**Must**
- Never send a trade instruction. No code path that can.
- Firm packs: JSON, versioned, `sourceUrl`, `lastVerified`, `investorPasswordAllowed: yes|no|unknown`. The app must refuse to enable anything a pack doesn't explicitly allow.
- Calendar vendor: evaluate and cost at least two before committing. No scraping.
- Disclaimers shipped: not a broker, not affiliated with any firm, not financial advice, user responsible for their firm's current rules, times can change.
- Privacy policy and terms in place before submission.

**Deliverables before build starts**
1. Architecture (app, backend, calendar vendor with licence and cost).
2. Rule-engine spec and firm-pack schema.
3. Soft gate approaches: Android + **Windows desktop**; iOS/macOS limits noted.
4. Push architecture (APNs, FCM, desktop), scheduling, quiet-hours / DND policy, failure modes.
5. Free/Pro flags.
6. Milestone plan: Android Soft gate + push → Windows Soft gate + push → iOS/iPad push (Soft gate as allowed) → packs → stores.

**Out of scope for launch:** everything in v1.1/v1.2/Later, the hub's features, any firm compliance guarantee, iOS full shield. Desktop and tablet Soft gate / push are **in** scope for launch planning (not parked with v1.1).
