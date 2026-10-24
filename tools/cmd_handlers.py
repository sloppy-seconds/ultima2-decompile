#!/usr/bin/env python3
"""cmd_handlers.py — generated crosswalk of the 26 command-letter handlers.

Why this is a tool and not a document. `AGENTS.md` § 3 forbids a hand-maintained
index of addresses: two copies always drift and a stale index is worse than
none. The three pieces of this crosswalk already exist and are authoritative in
their own place —

  * `disasm/jump-table.txt`   the decoded `cs:0x0730` word table, 26 entries
  * `asm/<ADDR>_cmd_<L>.asm`  the handler file, named from the same table
  * the `# provenance:` line   whether the entry has ever executed in a capture

— and nobody could answer "which handlers are both unnamed and unexercised?"
without grepping 26 files. This joins them, and it fails loudly when the three
disagree, so it doubles as a consistency gate: a rename that does not update the
table, or a table entry whose file has gone missing, exits non-zero.

Usage:
    python3 tools/cmd_handlers.py            # table, sorted by letter
    python3 tools/cmd_handlers.py --unexercised-only
    python3 tools/cmd_handlers.py --json
    python3 tools/cmd_handlers.py --check    # no output unless something is wrong

Exit codes: 0 ok, 1 a crosswalk inconsistency, 2 the inputs are missing.
"""

import argparse
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TABLE = os.path.join(ROOT, "disasm", "jump-table.txt")
ASM = os.path.join(ROOT, "asm")

TABLE_RE = re.compile(r"^([0-9A-Fa-f]{4})\s+handler=([A-Z])\s*$")
EXEC_RE = re.compile(r"entry executed in (\d+) of (\d+) harvests")
# The first header line, minus the leading "# cmd_X — ".
NAME_RE = re.compile(r"^#\s*cmd_[A-Z]\s+—\s+(.*)$")
CONF_RE = re.compile(r"^#\s*confidence:\s*(.*)$")


def read_table(path):
    entries = []
    with open(path, encoding="utf-8") as fh:
        for lineno, line in enumerate(fh, 1):
            if not line.strip() or line.startswith("#"):
                continue
            m = TABLE_RE.match(line.strip())
            if not m:
                fail(f"{path}:{lineno}: not a `XXXX handler=L` line: {line.strip()!r}")
            entries.append((m.group(2), m.group(1).upper()))
    return entries


def read_handler(addr, letter, asm_dir=ASM):
    """Return (filename, summary, executed, total, confidence) for one handler."""
    prefix = f"{addr}_"
    hits = [f for f in os.listdir(asm_dir) if f.startswith(prefix)]
    if not hits:
        fail(f"no asm file for handler {letter} at {addr} (expected {addr}_cmd_{letter}.asm)")
    if len(hits) > 1:
        fail(f"ambiguous: {len(hits)} files start with {addr}_ : {', '.join(sorted(hits))}")
    fname = hits[0]
    expected = f"{addr}_cmd_{letter}.asm"
    if fname != expected:
        fail(f"handler {letter} -> {addr}: file is {fname}, jump table says it should be {expected}")
    summary, executed, total, conf = "", None, None, ""
    with open(os.path.join(asm_dir, fname), encoding="utf-8") as fh:
        for line in fh:
            if not line.startswith("#"):
                break  # header over
            m = NAME_RE.match(line.rstrip())
            if m and not summary:
                summary = m.group(1).strip()
            m = EXEC_RE.search(line)
            if m:
                executed, total = int(m.group(1)), int(m.group(2))
            m = CONF_RE.match(line.rstrip())
            if m and not conf:
                conf = m.group(1).strip()
    if not summary:
        fail(f"{fname}: no `# cmd_{letter} — ...` name line")
    if not conf:
        fail(f"{fname}: no `# confidence:` line")
    return fname, summary, executed, total, conf


def fail(msg):
    print(f"cmd_handlers: {msg}", file=sys.stderr)
    sys.exit(1)


def collect(table=TABLE, asm_dir=ASM):
    if not os.path.isfile(table) or not os.path.isdir(asm_dir):
        print("cmd_handlers: missing disasm/jump-table.txt or asm/", file=sys.stderr)
        sys.exit(2)
    rows = []
    for letter, addr in read_table(table):
        fname, summary, executed, total, conf = read_handler(addr, letter, asm_dir)
        rows.append({
            "letter": letter,
            "addr": addr,
            "file": fname,
            "executed": executed,
            "harvests": total,
            "confidence": conf,
            "summary": summary,
        })
    return rows


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--json", action="store_true", help="emit JSON instead of a table")
    ap.add_argument("--unexercised-only", action="store_true",
                    help="only handlers never executed in any capture")
    ap.add_argument("--check", action="store_true",
                    help="print nothing on success; exit non-zero on any inconsistency")
    ap.add_argument("--table", default=TABLE, help="jump table file (default disasm/jump-table.txt)")
    ap.add_argument("--asm", default=ASM, help="asm directory (default asm/)")
    args = ap.parse_args()

    rows = collect(args.table, args.asm)  # collect() is the gate: exits non-zero on a mismatch
    if args.check:
        n = sum(1 for r in rows if r["executed"] in (None, 0))
        print(f"cmd_handlers: {len(rows)} handlers crosswalked, {n} never executed in a capture")
        return

    if args.unexercised_only:
        rows = [r for r in rows if r["executed"] in (None, 0)]

    if args.json:
        print(json.dumps(rows, indent=2))
        return

    if not rows:
        print("cmd_handlers: no handlers matched")
        return
    width = max(len(r["summary"]) for r in rows)
    print(f"{'key':<4}{'addr':<7}{'exec':<9}{'conf':<9}{'file':<28}summary")
    for r in rows:
        ex = "--" if r["executed"] is None else f"{r['executed']}/{r['harvests']}"
        conf = r["confidence"].split()[0].strip("(,")
        print(f"{r['letter']:<4}{r['addr']:<7}{ex:<9}{conf:<9}{r['file']:<28}{r['summary'][:width]}")
    never = [r["letter"] for r in rows if r["executed"] in (None, 0)]
    if never:
        print(f"\nnever executed in any of the {rows[0]['harvests'] or 60} harvests "
              f"({len(never)}): {' '.join(never)}")
        print("That is a capture gap, not a decode gap: see docs/needs-gameplay.md and")
        print("AGENTS.md § 3 — an unexercised handler is still byte-proven.")
        print("\nDo not confuse this count with the 19 in disasm/jump-table.md: that one")
        print("counts handlers absent from the single Phase 1 playthrough's runtime CFG")
        print("(disasm/entry-points.txt); this one counts the current 60-harvest corpus as")
        print("parsed out of each handler's own `# provenance:` line by")
        print("tools/provenance_from_traces.py. Both are correct for their own corpus.")


if __name__ == "__main__":
    main()
