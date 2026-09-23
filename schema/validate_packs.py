#!/usr/bin/env python3
"""Validate every pack in ../packs against firm-pack.schema.json.

Run from anywhere:  python3 validate_packs.py
Exit code 1 on any failure, so CI can gate on it.
Needs: pip install jsonschema
"""
import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator, FormatChecker

HERE = Path(__file__).resolve().parent
SCHEMA = json.loads((HERE / "firm-pack.schema.json").read_text())
PACKS = sorted((HERE.parent / "packs").glob("*.json"))


def main() -> int:
    validator = Draft202012Validator(SCHEMA, format_checker=FormatChecker())
    failures = 0
    for path in PACKS:
        pack = json.loads(path.read_text())
        errors = sorted(validator.iter_errors(pack), key=lambda e: list(e.path))
        # The one rule the schema can't express on its own: a verified pack must
        # carry a date and a name. (The schema's if/then does this too; belt and braces.)
        if pack.get("needsReverify") is False and not (pack.get("lastVerified") and pack.get("verifiedBy")):
            errors.append(type("E", (), {"path": ["needsReverify"], "message": "needsReverify is false but lastVerified or verifiedBy is empty"})())
        if pack["firmId"] != path.stem:
            errors.append(type("E", (), {"path": ["firmId"], "message": f"firmId must equal the file name ({path.stem})"})())
        status = "ok " if not errors else "FAIL"
        badge = "unverified" if pack.get("needsReverify") else f"verified {pack.get('lastVerified')}"
        print(f"{status} {path.name:22s} {badge}")
        for err in errors:
            failures += 1
            loc = "/".join(str(p) for p in err.path) or "(root)"
            print(f"     {loc}: {err.message}")
    print(f"{len(PACKS)} packs, {failures} errors")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
