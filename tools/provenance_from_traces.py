#!/usr/bin/env python3
"""
provenance_from_traces.py — derive real `# provenance:` evidence for named asm
functions from the Spice86 execution-flow dumps, instead of filling the field in.

Why
---
`tools/xref_provenance.py --strict` reports named functions with no
`# provenance:` line. The tempting fix — bulk-write `# provenance: static` to make
the number go to zero — is explicitly forbidden, and for a good reason: it would
record "read from the listing, never observed" on functions that HAVE been
observed running, destroying the one piece of information the field carries.

The evidence already exists. `captures/spice86/*/spice86dumpExecutionFlow.json`
holds `ExecutedInstructions`, and per AGENTS.md § 4 that list — not the discovered
CFG blocks — is the authority for "this ran". A function whose entry address
appears there has genuine `live:<harvest>` provenance and can be cited to the
harvest that proves it.

Address-space calibration (do not skip, do not assume)
-----------------------------------------------------
Three numbering schemes differ by a constant in this project (see
docs/decompiling.md). Rather than assume which one `ExecutedInstructions.Offset`
uses, the tool TESTS both mappings against functions already proven executed and
refuses to continue if neither is unambiguous. Getting this wrong silently would
produce a census of confident nonsense — the exact failure class AGENTS.md § 5
warns about.

Output is a report. It does not edit files.
Usage: python3 tools/provenance_from_traces.py [--json]
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASM = os.path.join(ROOT, "asm")
CAPS = os.path.join(ROOT, "captures", "spice86")

FUNC_RE = re.compile(r"^#\s*func\s+([0-9A-Fa-f]{4})\.\.([0-9A-Fa-f]{4})", re.M)
PROV_RE = re.compile(r"^#\s*provenance:", re.M | re.I)
NAME_RE = re.compile(r"^#\s*(\S.*?)\s+\u2014")

# Functions whose execution is already proven in the docs, used to calibrate the
# address mapping. If one of these is not found under a mapping, that mapping is
# wrong. Keys are asm filename stems (segment offsets).
CALIBRATION = [
    "2DC1_combat_gold_gain",   # T4: proven to run at fight turn 209
    "2DEE_combat_exp_gain",    # T4: same instant
    "2D8C_combat_kill_reward", # T4: zeroed the monster record at turn 209
]


def load_executed():
    """harvest name -> set of executed Offset values (ints)."""
    out = {}
    for path in sorted(glob.glob(os.path.join(CAPS, "*", "spice86dumpExecutionFlow.json"))):
        harvest = os.path.basename(os.path.dirname(path))
        try:
            data = json.load(open(path))
        except Exception as exc:
            print(f"WARN: unreadable {harvest}: {exc}", file=sys.stderr)
            continue
        ex = data.get("ExecutedInstructions") if isinstance(data, dict) else None
        if not ex:
            continue
        offs = set()
        for e in ex:
            if isinstance(e, dict) and "Offset" in e:
                offs.add(int(e["Offset"]))
            elif isinstance(e, int):
                offs.add(e)
        if offs:
            out[harvest] = offs
    return out


def calibrate(funcs, executed):
    """Return the delta that maps asm segment offsets onto ExecutedInstructions."""
    for delta in (0, 0x200):
        hits = 0
        needed = 0
        for stem in CALIBRATION:
            f = next((x for x in funcs if x["stem"] == stem), None)
            if not f:
                continue
            needed += 1
            entry = f["start"] + delta
            if any(entry in offs for offs in executed.values()):
                hits += 1
        if needed and hits == needed:
            return delta, hits, needed
    return None, hits if needed else 0, needed


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()

    funcs = []
    for path in sorted(glob.glob(os.path.join(ASM, "*.asm"))):
        text = open(path, errors="replace").read()
        lines = text.splitlines()
        m = FUNC_RE.search(text)
        if not m:
            continue
        stem = os.path.basename(path)[:-4]
        # "named" = the filename carries a real name rather than sub_XXXX.
        parts = stem.split("_", 1)
        named = len(parts) == 2 and not parts[1].lower().startswith("sub_")
        funcs.append(dict(
            stem=stem, path=path, named=named,
            start=int(m.group(1), 16),
            has_prov=bool(PROV_RE.search(text)),
        ))

    executed = load_executed()
    if not executed:
        print("ERROR: no ExecutedInstructions found in any capture — cannot derive "
              "provenance. Refusing to emit an empty result.", file=sys.stderr)
        return 2

    delta, hits, needed = calibrate(funcs, executed)
    if delta is None:
        print(f"ERROR: address calibration failed ({hits}/{needed} calibration "
              f"functions found under either delta 0 or 0x200). The dump format "
              f"changed or the calibration set is stale. Not guessing.", file=sys.stderr)
        return 2

    missing = [f for f in funcs if f["named"] and not f["has_prov"]]

    rows = []
    for f in missing:
        entry = f["start"] + delta
        where = sorted(h for h, offs in executed.items() if entry in offs)
        rows.append((f["stem"], f["start"], where))

    live = [r for r in rows if r[2]]
    dead = [r for r in rows if not r[2]]

    if a.json:
        print(json.dumps({"delta": hex(delta), "harvests": len(executed),
                          "live": [[s, hex(st), w] for s, st, w in live],
                          "static_only": [s for s, _, _ in dead]}, indent=1))
        return 0

    print(f"{len(executed)} harvests with ExecutedInstructions; "
          f"address delta calibrated to {hex(delta)} "
          f"({hits}/{needed} calibration functions matched)")
    print(f"named functions lacking # provenance: {len(rows)}")
    print(f"  of which GENUINELY OBSERVED RUNNING: {len(live)}")
    print(f"  of which never observed executed:   {len(dead)}\n")

    print("=== has live evidence (cite these) ===")
    for stem, start, where in live:
        shown = ", ".join(where[:3])
        extra = f" (+{len(where)-3} more)" if len(where) > 3 else ""
        print(f"  {stem:38} entry {start:04X}  live:{shown}{extra}")

    print("\n=== no executed evidence (static is the honest label) ===")
    for stem, start, _ in dead:
        print(f"  {stem:38} entry {start:04X}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
