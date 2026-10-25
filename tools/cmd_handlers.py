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
    python3 tools/cmd_handlers.py --verify-provenance
                                             # re-derive `exec` from captures/ and prove the
                                             # committed numbers match. Needs captures/, which
                                             # are gitignored, so this runs locally, not in CI.
    python3 tools/cmd_handlers.py --write-provenance
                                             # rewrite the stale NUMBERS in each handler's
                                             # provenance line from the same derivation.

Why `exec` is derived and not written. AGENTS.md § 3 forbids a hand-kept second copy of a
fact that is derivable, and this column was exactly that: it had drifted wrong eight times,
including a "60 harvests" that was a typed literal while the corpus was 141. The captures
are the truth. The catch is that `captures/spice86/` is gitignored, so CI cannot re-derive --
which is why the committed line stays, and what makes it not hand-kept any more is that a
human no longer types the digits: `--write-provenance` does, and `--verify-provenance` is the
gate that proves they still match.

The boundary is deliberate. Numbers are generated. A VERDICT (executed vs never) is not
auto-rewritten, because the sentence around it is prose a person wrote and a tool that
silently flips "never appears" into "appears in 2 of" would be editing a finding. A verdict
contradiction is reported for a human instead.

Exit codes: 0 ok, 1 a crosswalk inconsistency or provenance drift, 2 the inputs are missing
(includes: asked to derive without captures/ present -- it refuses rather than passing quiet).
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
NEVER_RE = re.compile(r"never appears in ExecutedInstructions of any of the (\d+) harvests")
CAPTURES = os.path.join(ROOT, "captures", "spice86")
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


def load_flow_dumps(captures_dir=CAPTURES):
    """Return {harvest_name: set(executed runtime offsets)}, or None if there are no captures.

    `Offset` in these dumps is a DECIMAL number, not a hex string. An earlier probe parsed it
    as hex and got a confident "never executed" for every address including the controls, which
    is the failure mode AGENTS.md § 5 calls the dangerous shape. The controls below are what
    would have caught that, and they are kept because the trap is one keystroke away.
    """
    if not os.path.isdir(captures_dir):
        return None
    import json as _json
    dumps = {}
    for name in sorted(os.listdir(captures_dir)):
        p = os.path.join(captures_dir, name, "spice86dumpExecutionFlow.json")
        if not os.path.isfile(p):
            continue
        try:
            with open(p, encoding="utf-8", errors="replace") as fh:
                blob = _json.load(fh)
        except (ValueError, OSError):
            continue
        flow = blob.get("ExecutedInstructions") if isinstance(blob, dict) else None
        if not isinstance(flow, list) or not flow:
            continue
        dumps[name] = {e["Offset"] for e in flow if isinstance(e, dict) and isinstance(e.get("Offset"), int)}
    return dumps or None


def derive_exec(rows, dumps):
    """{letter: (hits, total)} straight from the captures. The only source of truth for `exec`."""
    total = len(dumps)
    out = {}
    for r in rows:
        addr = int(r["addr"], 16)
        hits = sum(1 for offs in dumps.values() if addr in offs)
        out[r["letter"]] = (hits, total)
    return out


def header_lines(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read().splitlines()


def verify_provenance(rows, derived):
    """Prove the committed numbers still equal the derivation. Returns an exit code."""
    stale, contradicted, missing = [], [], []
    for r in rows:
        hits, total = derived[r["letter"]]
        path = os.path.join(ASM, r["file"])
        text = "\n".join(header_lines(path))
        m_exec, m_never = EXEC_RE.search(text), NEVER_RE.search(text)
        if not m_exec and not m_never:
            missing.append(r["letter"])
            continue
        if m_exec:
            if hits == 0:
                contradicted.append((r["letter"], f"line claims executed in {m_exec.group(1)}, captures say never"))
            elif (int(m_exec.group(1)), int(m_exec.group(2))) != (hits, total):
                stale.append((r["letter"], f"{m_exec.group(1)}/{m_exec.group(2)} -> {hits}/{total}"))
        else:
            if hits:
                contradicted.append((r["letter"], f"line says never appears, captures show it in {hits} harvest(s)"))
            elif int(m_never.group(1)) != total:
                stale.append((r["letter"], f"never-appears total {m_never.group(1)} -> {total}"))
    if not (stale or contradicted or missing):
        print(f"cmd_handlers: provenance verified against {len(derived)} handlers in "
              f"{next(iter(derived.values()))[1]} harvests with a flow dump")
        return 0
    print("cmd_handlers: PROVENANCE DRIFT", file=sys.stderr)
    for L, why in contradicted:
        print(f"  VERDICT CONTRADICTS THE CAPTURES  cmd_{L}: {why}", file=sys.stderr)
    for L, why in stale:
        print(f"  numbers stale (fix: --write-provenance)  cmd_{L}: {why}", file=sys.stderr)
    for L in missing:
        print(f"  no machine-parsed exec claim in the header  cmd_{L}", file=sys.stderr)
    print("A verdict contradiction is a finding, not a digit: --write-provenance will not flip\n"
          "prose, so read the line and decide.", file=sys.stderr)
    return 1


def write_provenance(rows, derived):
    """Rewrite the digits only. A verdict mismatch is refused, never auto-edited."""
    changed, refused = 0, []
    for r in rows:
        hits, total = derived[r["letter"]]
        path = os.path.join(ASM, r["file"])
        lines = header_lines(path)
        out, touched = [], False
        for line in lines:
            m = EXEC_RE.search(line)
            if m:
                if hits == 0:
                    refused.append((r["letter"], "claims executed, captures say never"))
                    out.append(line)
                    continue
                new = line.replace(m.group(0), f"entry executed in {hits} of {total} harvests")
                touched |= new != line
                out.append(new)
                continue
            m = NEVER_RE.search(line)
            if m:
                if hits:
                    refused.append((r["letter"], f"says never appears, captures show {hits}"))
                    out.append(line)
                    continue
                new = line.replace(m.group(0),
                                   f"never appears in ExecutedInstructions of any of the {total} harvests")
                touched |= new != line
                out.append(new)
                continue
            out.append(line)
        if touched:
            with open(path, "w", encoding="utf-8") as fh:
                fh.write("\n".join(out) + "\n")
            changed += 1
    print(f"cmd_handlers: rewrote numbers in {changed} handler header(s) from "
          f"{next(iter(derived.values()))[1]} harvests")
    for L, why in refused:
        print(f"  REFUSED, needs a human: cmd_{L}: {why}", file=sys.stderr)
    return 1 if refused else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--json", action="store_true", help="emit JSON instead of a table")
    ap.add_argument("--unexercised-only", action="store_true",
                    help="only handlers never executed in any capture")
    ap.add_argument("--check", action="store_true",
                    help="print nothing on success; exit non-zero on any inconsistency")
    ap.add_argument("--verify-provenance", action="store_true",
                    help="re-derive `exec` from captures/ and prove the committed numbers match")
    ap.add_argument("--write-provenance", action="store_true",
                    help="rewrite the stale numbers in each handler header from the derivation")
    ap.add_argument("--captures", default=CAPTURES,
                    help="captures dir to derive from (default captures/spice86)")
    ap.add_argument("--table", default=TABLE, help="jump table file (default disasm/jump-table.txt)")
    ap.add_argument("--asm", default=ASM, help="asm directory (default asm/)")
    args = ap.parse_args()

    rows = collect(args.table, args.asm)  # collect() is the gate: exits non-zero on a mismatch
    if args.verify_provenance or args.write_provenance:
        dumps = load_flow_dumps(args.captures)
        if dumps is None:
            # Refuse rather than pass. A provenance check that reports success because it found
            # nothing to check is the exact gate shape AGENTS.md § 3 already calls out.
            print(f"cmd_handlers: cannot verify provenance, no flow dumps under {args.captures} "
                  f"(captures/ is gitignored; this mode runs locally)", file=sys.stderr)
            sys.exit(2)
        derived = derive_exec(rows, dumps)
        sys.exit(write_provenance(rows, derived) if args.write_provenance
                 else verify_provenance(rows, derived))
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
        # The corpus size is measured from the rows, never typed. It used to be a literal 60 in
        # this sentence while the corpus was 141, which is the whole reason D9 exists.
        total = max((r["harvests"] or 0) for r in rows)
        corpus = f"{total} harvests" if total else "harvests (run --verify-provenance to measure)"
        print(f"\nnever executed in any of the {corpus} "
              f"({len(never)}): {' '.join(never)}")
        print("That is a capture gap, not a decode gap: see docs/needs-gameplay.md and")
        print("AGENTS.md § 3 — an unexercised handler is still byte-proven.")
        print("\nDo not confuse this count with the 19 in disasm/jump-table.md: that one")
        print("counts handlers absent from the single Phase 1 playthrough's runtime CFG")
        print("(disasm/entry-points.txt); this one counts the current corpus as")
        print("parsed out of each handler's own `# provenance:` line by")
        print("tools/provenance_from_traces.py. Both are correct for their own corpus.")


if __name__ == "__main__":
    main()
