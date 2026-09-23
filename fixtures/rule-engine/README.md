# Rule-engine fixtures

Shared test cases the Dart engine (device) and the PHP engine (server) both have to
pass. `reference.py` is the tie-breaker: it generated every `expected` block and it
recomputes them on `--check`. If either real engine disagrees with a fixture, the
fixture is right until someone changes `RULE-ENGINE.md` and regenerates.

```
python3 reference.py --check     # recompute, diff, exit 1 on drift
python3 reference.py --write     # regenerate expected blocks after a spec change
```

## Case format

```json
{
  "name": "what the case proves",
  "input": {
    "userId": "u1",
    "settings": { "mode": "conservative", "windowBeforeMin": 5, "windowAfterMin": 5 },
    "instruments": [ { "symbol": "XAUUSD" } ],
    "events": [ { "id": "e1", "currency": "EUR", "title": "CPI", "impact": "high", "scheduledAtUtc": "2026-10-01T07:00:00Z" } ]
  },
  "expected": { "windows": [], "ladder": [], "notes": [] }
}
```

Firm match adds `packId` (a file in `../../packs`) or an inline `pack`, plus
`accountTypeId`. `firmEventIds` lists the ids the firm's own list contains, when the
pack uses `firm-list`. A reconcile case has `inputBefore` and `inputAfter` instead of
`input`, and expects cancelled, created and kept alert ids.

Instruments may carry an explicit `basket`; otherwise the default table in
`reference.py` applies, and any six-letter symbol is read as an FX pair.

## Identifiers

`windowId` is the first 20 hex characters of sha1 over `userId|symbol|opensAtUtc|closesAtUtc`.
`alertId` is the first 20 of sha1 over `userId|windowId|kind|opensAtUtc`.
Timestamps are ISO 8601 UTC with a trailing Z and no fractional seconds. Both engines
must hash exactly these strings, or the ids won't match across device and server and
the mirror will stop deduping.

## Cases

| File | Proves |
|---|---|
| 01-gold-eur-cpi | The brief's example: EUR CPI while in gold opens a window, ladder lands on the minute |
| 02-fx-both-legs | EURUSD reacts to USD and EUR, ignores GBP |
| 03-medium-ignored | Medium impact never opens a window |
| 04-merge-overlap | Two USD prints five minutes apart on US500 become one window with two reasons and one ladder |
| 05-ftmo-unverified | Firm match on an unverified pack uses the larger of pack and default, verified false |
| 06-ftmo-verified | Same pack marked verified inline: 2 minute window, verified true |
| 07-ftmo-challenge | Account type with no news rule yields no windows and says so |
| 08-tentative | A tentative event opens nothing |
| 09-event-revised | Moving an event cancels every old alert id and creates new ones, keeps none |
| 10-pro-custom-window | Pro 3 before, 10 after |
