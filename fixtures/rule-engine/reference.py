#!/usr/bin/env python3
"""Reference implementation of the rule engine, used only to generate and check fixtures.

The Dart engine on the device and the PHP engine on the server must produce the same
output for every case in cases/. This file is the tie-breaker when they disagree, and
it's deliberately small enough to read in one sitting. See ../../RULE-ENGINE.md.

  python3 reference.py --write    fill "expected" in every case from "input"
  python3 reference.py --check    recompute and diff against "expected"; exit 1 on drift
"""
import hashlib
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

CASES = Path(__file__).resolve().parent / "cases"
PACKS = Path(__file__).resolve().parent.parent.parent / "packs"

DEFAULT_BASKETS = {
    "XAUUSD": ["USD", "EUR", "GBP"], "XAGUSD": ["USD", "EUR", "GBP"],
    "US30": ["USD"], "US500": ["USD"], "USTEC": ["USD"], "US2000": ["USD"],
    "DE40": ["EUR"], "FR40": ["EUR"], "EU50": ["EUR"], "UK100": ["GBP"],
    "JP225": ["JPY"], "HK50": ["CNY", "HKD"], "AUS200": ["AUD"],
    "USOIL": ["USD"], "UKOIL": ["USD"], "BTCUSD": ["USD"], "ETHUSD": ["USD"],
}
RUNGS = [("t-60", -60), ("t-15", -15), ("t-5", -5), ("t-1", -1), ("open", 0)]


def parse(ts: str) -> datetime:
    return datetime.strptime(ts, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)


def fmt(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def short_sha(*parts: str) -> str:
    return hashlib.sha1("|".join(parts).encode()).hexdigest()[:20]


def basket_for(instrument: dict) -> list[str]:
    if instrument.get("basket"):
        return instrument["basket"]
    sym = instrument["symbol"].upper()
    if sym in DEFAULT_BASKETS:
        return DEFAULT_BASKETS[sym]
    if len(sym) == 6 and sym.isalpha():           # plain FX pair
        return [sym[:3], sym[3:]]
    return ["USD"]


def load_pack(inp: dict) -> dict | None:
    if "pack" in inp:                              # inline pack, used by fixtures that need a verified copy
        return inp["pack"]
    if inp.get("packId"):
        return json.loads((PACKS / f"{inp['packId']}.json").read_text())
    return None


def effective_rule(inp: dict):
    """Return (before, after, event_selector, affected, verified, notes) for this user."""
    s = inp["settings"]
    notes = []
    if s["mode"] == "conservative":
        return s["windowBeforeMin"], s["windowAfterMin"], "high", "event-currency", True, notes

    pack = load_pack(inp)
    acct = next(a for a in pack["accountTypes"] if a["id"] == inp["accountTypeId"])
    rule = acct["newsRule"]
    if not rule["applies"]:
        return None, None, None, None, not pack["needsReverify"], ["firm does not restrict news on this account type"]

    before, after = rule["windowBeforeMin"], rule["windowAfterMin"]
    verified = not pack["needsReverify"]
    if not verified:
        before, after = max(before, s["windowBeforeMin"]), max(after, s["windowAfterMin"])
        notes.append("pack unverified: using the larger of pack window and user default")

    selector = "high"
    if rule["eventSet"] == "firm-list":
        if inp.get("firmEventIds"):
            selector = "firm-list"
        else:
            notes.append("using the calendar, not the firm's list")
    return before, after, selector, rule["affectedInstruments"], verified, notes


def compute_windows(inp: dict) -> tuple[list[dict], list[str]]:
    before, after, selector, affected, verified, notes = effective_rule(inp)
    if before is None:
        return [], notes

    if selector == "firm-list":
        ids = set(inp["firmEventIds"])
        events = [e for e in inp["events"] if e["id"] in ids and not e.get("tentative")]
    else:
        events = [e for e in inp["events"] if e["impact"] == "high" and not e.get("tentative")]

    raw = []
    for inst in inp["instruments"]:
        basket = basket_for(inst)
        for e in events:
            if affected == "event-currency" and e["currency"] not in basket:
                continue
            if affected == "list" and inst["symbol"] not in inp.get("affectedList", []):
                continue
            t = parse(e["scheduledAtUtc"])
            raw.append((inst["symbol"], t - timedelta(minutes=before), t + timedelta(minutes=after), e["id"]))

    raw.sort(key=lambda r: (r[0], r[1], r[2]))
    merged: list[list] = []
    for sym, o, c, eid in raw:
        if merged and merged[-1][0] == sym and o <= merged[-1][2]:
            merged[-1][2] = max(merged[-1][2], c)
            merged[-1][3].append(eid)
        else:
            merged.append([sym, o, c, [eid]])

    windows = []
    for sym, o, c, reasons in merged:
        wid = short_sha(inp["userId"], sym, fmt(o), fmt(c))
        windows.append({
            "windowId": wid, "instrument": sym, "opensAtUtc": fmt(o), "closesAtUtc": fmt(c),
            "reasons": reasons, "verified": verified,
        })
    return windows, notes


def compute_ladder(user_id: str, windows: list[dict]) -> list[dict]:
    ladder = []
    for w in windows:
        o = parse(w["opensAtUtc"])
        for kind, delta in RUNGS:
            fire = o + timedelta(minutes=delta)
            ladder.append({"alertId": short_sha(user_id, w["windowId"], kind, w["opensAtUtc"]),
                           "windowId": w["windowId"], "kind": kind, "fireAtUtc": fmt(fire)})
        ladder.append({"alertId": short_sha(user_id, w["windowId"], "end", w["opensAtUtc"]),
                       "windowId": w["windowId"], "kind": "end", "fireAtUtc": w["closesAtUtc"]})
    ladder.sort(key=lambda r: (r["fireAtUtc"], r["windowId"], r["kind"]))
    return ladder


def run_case(case: dict) -> dict:
    if "inputBefore" in case:                     # reconcile case: two snapshots, diff the ladders
        wb, _ = compute_windows(case["inputBefore"])
        wa, _ = compute_windows(case["inputAfter"])
        lb = {r["alertId"] for r in compute_ladder(case["inputBefore"]["userId"], wb)}
        la = {r["alertId"] for r in compute_ladder(case["inputAfter"]["userId"], wa)}
        return {"cancelledAlertIds": sorted(lb - la), "createdAlertIds": sorted(la - lb),
                "keptAlertIds": sorted(lb & la), "windowsAfter": wa}
    windows, notes = compute_windows(case["input"])
    return {"windows": windows, "ladder": compute_ladder(case["input"]["userId"], windows), "notes": notes}


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "--check"
    drift = 0
    for path in sorted(CASES.glob("*.json")):
        case = json.loads(path.read_text())
        got = run_case(case)
        if mode == "--write":
            case["expected"] = got
            path.write_text(json.dumps(case, indent=2) + "\n")
            print(f"wrote {path.name}")
        else:
            ok = case.get("expected") == got
            drift += 0 if ok else 1
            print(f"{'ok  ' if ok else 'DRIFT'} {path.name}")
    if mode != "--write":
        print(f"{drift} case(s) drifted")
    return 1 if drift else 0


if __name__ == "__main__":
    sys.exit(main())
