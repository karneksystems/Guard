# Rule engine and firm-pack schema

Pre-build deliverable 2. The engine runs on the device in Dart and on the server in
PHP from the same spec, and a shared fixture set keeps them honest.

## Inputs

- Events from the vendor: currency, impact (high, medium, low), scheduled time in
  UTC, title, source, tentative flag.
- The user's instruments, each with a currency basket.
- Mode: conservative or firm match.
- Window default: minutes before and after. Free is fixed at 5 and 5. Pro has presets
  2, 3, 5, 10 and custom before and after.
- A pack, in firm match only.

## Conservative mode (default)

An event opens a window on an instrument when impact is high and the event's currency
is in the instrument's basket. Default baskets:

| Instrument | Basket |
|---|---|
| FX pair | both legs, EURUSD is EUR and USD |
| XAUUSD, XAGUSD | USD, EUR, GBP (the brief's gold fix, editable) |
| US30, US500, USTEC, US2000 | USD |
| DE40, FR40, EU50 | EUR |
| UK100 | GBP |
| JP225 | JPY |
| HK50 | CNY, HKD |
| AUS200 | AUD |
| USOIL, UKOIL | USD |
| BTCUSD and other crypto | USD |

Every basket is editable. Window is [event minus before, event plus after].
Overlapping windows on the same instrument merge into one, carrying every event as a
reason.

## Firm match (Pro)

The pack picks the rule by account type: minutes before and after, which event set
(the firm's own list or the calendar's high-impact set), which instruments are
affected (event currency, all, or a list), which actions are restricted, whether an
SL or TP trigger counts, and the consequence. The engine computes windows with the
pack's minutes and event set. If the pack says firm-list and the list hasn't been
ingested yet, it falls back to calendar high-impact and the window shows "using the
calendar, not the firm's list".

Unknown means not allowed. A pack with needsReverify true shows an "unverified"
badge, the engine uses the larger of the pack window and the user's default, and
nothing that depends on investorPasswordAllowed unlocks. A missing field is read as
its most restrictive value.

## Outputs

windows[], each with opens and closes in UTC, instrument, reasons, mode and a
verified flag. The ladder derives from windows, not events: T-60, T-15, T-5 and T-1
relative to opens, open at opens, end at closes. Merged windows give one ladder.

## Edge cases

- Event time revised: recompute, cancel the rungs that moved, create new ones with new
  alert ids. The alert id includes the scheduled time, so a moved event never reuses
  an id.
- Event cancelled: window removed, rungs cancelled, one "cancelled" notice if T-60
  already fired.
- Tentative events with no fixed time: listed in the digest, no window, no rungs.
- Central bank speeches are high impact on most calendars and on FTMO's list. They're
  events like any other.
- Daylight saving: irrelevant in UTC. The broker-time line in the UI switches with the
  broker's DST rule from settings.

## Pack schema, version 1

```json
{
  "schemaVersion": 1,
  "firmId": "ftmo",
  "firmName": "FTMO",
  "packVersion": "2026.09.23-draft.1",
  "sourceUrl": "https://ftmo.com/en/faq/can-i-trade-news/",
  "sourceFetchedAt": null,
  "lastVerified": null,
  "verifiedBy": null,
  "needsReverify": true,
  "investorPasswordAllowed": "unknown",
  "accountTypes": [
    {
      "id": "ftmo-account",
      "label": "FTMO Account (funded)",
      "phase": "funded",
      "newsRule": {
        "applies": true,
        "windowBeforeMin": 2,
        "windowAfterMin": 2,
        "eventSet": "firm-list",
        "eventListUrl": null,
        "affectedInstruments": "event-currency",
        "restrictedActions": ["open", "close"],
        "slTpTriggerCounts": true,
        "holdingThroughAllowed": true,
        "consequence": "breach",
        "notes": "No warning system on standard funded accounts."
      }
    },
    { "id": "challenge", "label": "FTMO Challenge", "phase": "evaluation", "newsRule": { "applies": false } },
    { "id": "verification", "label": "Verification", "phase": "evaluation", "newsRule": { "applies": false } },
    { "id": "swing", "label": "FTMO Account Swing", "phase": "funded", "newsRule": { "applies": false } }
  ],
  "changelog": [
    { "packVersion": "2026.09.23-draft.1", "date": "2026-09-23", "change": "Initial draft from secondary sources. Not read on the firm's page." }
  ]
}
```

Field rules:

- consequence is one of breach, termination, profit-removed, profit-reduced, none.
- profit-reduced carries countedShare between 0 and 1.
- exemptIfOpenedMinutesBefore is an integer, for rules like FundingPips' five-hour
  exception.
- eventSet is firm-list or calendar-high-impact.
- affectedInstruments is event-currency, all, or list with an instruments array.
- investorPasswordAllowed is yes, no or unknown. Only yes, with a sourceUrl, unlocks
  the v1.2 features.
- needsReverify flips to false only when a human has read the firm's page and set
  lastVerified and verifiedBy.
- CI validates every pack against the JSON Schema and refuses a pack with
  needsReverify false and lastVerified null.

## Seed packs, all draft, all needsReverify true

The values below come from third-party summaries of the firms' help pages, found on
23 Sep 2026. None was read on the firm's own page from this environment, and the
brief's PROP-FIRM-RULES.md wasn't available here. Every number is unverified until
someone opens the sourceUrl and sets lastVerified.

| Firm | Applies to | Before / after | Consequence | Notes | Source |
|---|---|---|---|---|---|
| FTMO | FTMO Account (funded) only. Challenge, Verification and Swing exempt | 2 / 2 | breach | SL or TP triggered inside the window counts. Holding through is allowed. FTMO publishes its own restricted-event list, so eventSet is firm-list | ftmo.com/en/faq/can-i-trade-news/ |
| FundedNext | Listed high-impact events. Which models is still to confirm | 5 / 5 | profit-reduced, countedShare 0.4 (their "News Reward Share Rule") | | help.fundednext.com/en/articles/10701447 |
| FundingPips | Regular funded accounts: profit removed unless the trade was opened 300 minutes before. FundingPips Zero: termination | 5 / 5 | profit-removed, or termination on Zero | Weekend holding rules on the same page | help.fundingpips.com/hc/en-us/articles/34504137479441 |
| Alpha Capital | Alpha Pro 6%, Alpha One, Alpha Three: 5 / 5. Alpha Pro 8% and 10%: 2 / 2 | 5 or 2 | to confirm | | help.alphacapitalgroup.uk/en/articles/9293522 |
| Blue Guardian | Funded only. Challenge phase allowed | 5 / 5 | profit-removed, no violation | Red-folder set includes FOMC, NFP, CPI, JOLTS, claims and Fed speeches | help.blueguardian.com, per-model rule pages |

The pack files are in `packs/`, the JSON Schema in `schema/firm-pack.schema.json`,
and `schema/validate_packs.py` is the CI gate. Ten engine fixtures with a Python
reference implementation are in `fixtures/rule-engine/`; both the Dart and PHP
engines must pass them, and the identifier hashing they define is the contract that
keeps the local mirror deduping against server push.
