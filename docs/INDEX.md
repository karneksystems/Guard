# Wideberth (working name), prop-firm news guard

Docs for the guard described in `TOTAL-BRIEF-Prop-News-Guard.md`. The brief wins on
product. The rest is the pre-build set the brief's Part C asks for, plus a decisions
log. These files move to the product's own private repo once the name clears (D3).

| File | What it is |
|---|---|
| TOTAL-BRIEF-Prop-News-Guard.md | The brief. Source of truth on product |
| DECISIONS.md | Every decision taken since the brief, with the reason and what reopens it |
| PLATFORM-ANNEX.md | Short version of what each OS allows for Soft gate and push |
| ARCHITECTURE.md | App, backend, data model, time handling, distribution, privacy, cost lines |
| RULE-ENGINE.md | Conservative and firm-match logic, pack JSON schema, five seed packs (unverified) |
| SOFT-GATE.md | Gate state machine and the per-platform implementation |
| PUSH-ARCHITECTURE.md | Ladder, scheduler, providers, local mirror, quiet hours, failure modes |
| FREE-PRO-FLAGS.md | The flag table and how it's enforced |
| MILESTONES.md | Build order with exit criteria and honest durations |
| CALENDAR-VENDORS.md | Vendor pricing, the cost curve, and the evaluation plan |
| APPLE-ENTITLEMENT-REQUEST.md | Text for the Family Controls request, file it now |
| schema/ | Pack JSON Schema and the validator CI runs (`python3 schema/validate_packs.py`) |
| packs/ | Five seed packs, all unverified until a human reads the source and sets lastVerified |
| fixtures/rule-engine/ | Ten shared engine cases and the Python reference that generated them (`python3 reference.py --check`) |

Still missing from the brief's references, and needed before M1: CLAUDE-HANDOFF,
DESIGN-CONCEPTS-Grok.md, PROP-FIRM-RULES.md.
