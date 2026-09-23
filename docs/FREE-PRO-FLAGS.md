# Free and Pro flags

Pre-build deliverable 5. One SKU, £4.99 a month or £39 a year. One boolean per user
on the server, pro_until, and every flag below derives from it plus the platform.
Nothing about being woken up is Pro (D12).

| Flag key | Free | Pro | Notes |
|---|---|---|---|
| calendar.highImpact | yes | yes | |
| calendar.mediumImpact | no | no | v1.1 |
| mode.conservative | yes | yes | default |
| mode.firmMatch | no | yes | needs a pack; unverified packs show the badge |
| instruments.max | 2 | unlimited | |
| window.default | 5 / 5 fixed | presets 2, 3, 5, 10 and custom | |
| protection.warnOnly | yes | yes | |
| protection.softGate | yes | yes | platform permitting |
| protection.hardBlock | no | yes | platform permitting |
| ladder.push | yes | yes | all six rungs |
| ladder.localMirror | yes | yes | |
| digest.nightBefore | yes | yes | |
| journal.days | 7 | unlimited | |
| journal.streak | no | yes | |
| weekendHold.warning | yes | yes | |
| dailyLoss.tracker | yes | yes | manual entry |
| minDays.countdown | yes | yes | |
| inactivity.reminder | yes | yes | |
| sourceStrip | yes | yes | always on, not a flag in practice |
| ads.light | yes | no | never on the gate, never on the alert |
| packs.rulesChangedFlag | no | yes | |
| packs.changelog | no | yes | |
| hub.* | dark | dark | skeleton only at launch |
| investorPassword.readOnly | no | no | v1.2, and only where the pack says yes |

Enforcement: the server is the source of truth for pro_until and returns the flag
set on every sync. The device caches the last set and, if the server is unreachable,
keeps Pro for 7 days past pro_until before falling back to Free, so an outage never
drops a paying user's window presets in the middle of an NFP week.
