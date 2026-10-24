#!/usr/bin/env python3
"""str_out_audit.py — the rendering gap: messages the atlas carries ONLY from the contract.

Renamed in meaning on 2026-10-28d, when `strings_atlas.py` grew a second source. It used to
report sites the atlas could not see at all; now the atlas sees every print site, because the
contract source covers whatever `asm/` fails to render as data. So this no longer asks "is the
string missing?" — it asks the sharper question:

    **Which messages does the atlas know only because the executable says so, and not because
    `asm/` renders them as data?**

Those are the places where the reconstruction's presentation is weaker than its evidence. Nine
exist. They are not a bug in the proof — every one of those files reassembles byte-identically —
they are the places where a reader of `asm/` alone would not know a message is there, and
`engine/tests/asm_body_guard.py` forbids editing the body lines to change that, which is a
decision about the tree's invariant rather than a cleanup anyone should make quietly.

The gate still has two red directions, and that is the point of keeping it:
  * a NEW gap appears — `asm/` lost a rendering, or a fresh misclassification crept in;
  * a listed gap closes — someone fixed the rendering and left the list stale.
A list that only grows is a list nobody trusts.

`--selftest` demonstrates the gate going red on every run, by hiding a db-line string from the
atlas and requiring the gap to grow. A checker that cannot fail is the failure mode AGENTS.md
names, and this project has been bitten by one that printed FAIL and reported PASS to CI.

Usage:
    python3 tools/str_out_audit.py --selftest     # controls, including a deliberate failure
    python3 tools/str_out_audit.py --check        # CI-shaped: exit 1 on drift either way
    python3 tools/str_out_audit.py --list         # the gap, offsets only
    python3 tools/str_out_audit.py --show         # the gap WITH text, stdout only
    python3 tools/str_out_audit.py --emit         # rewrite the committed list
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import strings_atlas as sa      # noqa: E402  the scanner and the atlas; nothing duplicated here

EXE = sa.EXE
BIAS = sa.BIAS
GAP = "disasm/str-out-rendering-gap.tsv"


def audit(exe=None, atlas=None):
    """Every printable str_out site, tagged with whether asm/ renders it as data."""
    if exe is None:
        exe = open(EXE, "rb").read()
    rows = atlas if atlas is not None else sa.build(exe)
    by_pos = {(r["foff"], r["text"]): r.get("source", "db-line") for r in rows}
    out = []
    for site in sa.str_out_sites(exe):
        m = sa.message_at(exe, site)
        if m is None:
            continue                      # not a message: a pad, a table, a coincidental E8
        foff, text = m
        src = by_pos.get((foff, text), "MISSING")
        out.append({"site": site, "foff": foff, "len": len(text), "text": text,
                    "source": src,
                    "owner": next((r["file"] for r in rows
                                   if r["foff"] == foff and r["text"] == text), "?")})
    return out


def gaps(rows):
    return [r for r in rows if r["source"] != "db-line"]


def load_list(path=GAP):
    if not os.path.exists(path):
        return None
    out = set()
    for line in open(path):
        line = line.strip()
        if not line or line.startswith("#") or line.startswith("file_off"):
            continue
        out.add(int(line.split("\t")[0], 16))
    return out


def render(rows):
    lines = ["# Messages asm/ does not render as data — the atlas knows them only from the",
             "# str_out calling convention. Generated; do not hand-edit.",
             "#   python3 tools/str_out_audit.py --emit",
             "# Offsets are FILE offsets (runtime + 0x200). No game text: len is the byte count.",
             "# Fixing one means editing body lines, which engine/tests/asm_body_guard.py",
             "# forbids — see disasm/defects.md for why that is a decision and not a cleanup.",
             "file_off\truntime\tlen\tasm_owner_claiming_this_range\tatlas_source"]
    for r in sorted(rows, key=lambda x: x["foff"]):
        lines.append("%05X\t%05X\t%d\t%s\t%s"
                     % (r["foff"], r["foff"] - BIAS, r["len"], r["owner"], r["source"]))
    return "\n".join(lines) + "\n"


def selftest():
    exe = open(EXE, "rb").read()
    rows = audit(exe)
    g = gaps(rows)
    fails = []
    if len(rows) < 200:
        fails.append(f"only {len(rows)} printable str_out sites — the scanner or the printer "
                     f"address is wrong, not the tree")
    if any(r["source"] == "MISSING" for r in rows):
        missing = [r for r in rows if r["source"] == "MISSING"]
        fails.append(f"{len(missing)} print sites are in NEITHER source — the atlas lost them "
                     f"entirely, e.g. file {missing[0]['foff']:05X}")
    if len(g) > 40:
        fails.append(f"{len(g)} rendering gaps — asm/ has lost more renderings than the nine "
                     f"on record; check what re-rendered the tree")
    # The control that makes this a gate: hide a string that asm/ DOES render as data and the
    # gap list must grow. If it does not, the comparison is not reading the atlas it was given.
    atlas = sa.build(exe)
    victim = next(r for r in atlas if r.get("source") == "db-line"
                  and r["file"].startswith("0A02"))
    crippled = [r for r in atlas if not (r["foff"] == victim["foff"] and r["text"] == victim["text"])]
    probe = gaps(audit(exe, atlas=crippled))
    if not any(p["foff"] == victim["foff"] and p["source"] == "MISSING" for p in probe):
        fails.append("hiding a db-line string did NOT enlarge the gap — the audit is not "
                     "reading the atlas it was handed")
    if fails:
        print("SELFTEST FAILED")
        for f in fails:
            print("  -", f)
        return 1
    print(f"selftest ok: {len(rows)} printable str_out sites, {len(rows) - len(g)} rendered as "
          f"data by asm/, {len(g)} rendering gaps; hiding a db-line string correctly went red")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--show", action="store_true", help="print text to stdout only")
    ap.add_argument("--emit", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    rows = audit()
    g = gaps(rows)
    if a.emit:
        open(GAP, "w").write(render(g))
        print(f"wrote {GAP}: {len(g)} sites")
        return 0
    if a.show:
        for r in sorted(g, key=lambda x: x["foff"]):
            print("file:%05X runtime:%05X owner:%-26s [%s]  %r"
                  % (r["foff"], r["foff"] - BIAS, r["owner"], r["source"], r["text"]))
        print(f"\n{len(g)} rendering gaps of {len(rows)} printable sites")
        return 0
    if a.list:
        print(render(g))
        return 0
    if a.check:
        allow = load_list()
        if allow is None:
            print(f"{GAP} missing — run --emit", file=sys.stderr)
            return 1
        now = {r["foff"] for r in g}
        new = sorted(now - allow)
        closed = sorted(allow - now)
        bad = False
        if new:
            print(f"NEW rendering gaps ({len(new)}) — asm/ no longer renders a printed message "
                  f"as data, or a fresh misclassification crept in:")
            for f in new:
                r = next(x for x in g if x["foff"] == f)
                print(f"  file {f:05X} runtime {f - BIAS:05X} owner {r['owner']} "
                      f"source {r['source']} len {r['len']}")
            bad = True
        if closed:
            print(f"{len(closed)} listed gaps are now rendered as data — the list is stale, "
                  f"run --emit:")
            for f in closed:
                print(f"  file {f:05X}")
            bad = True
        if bad:
            return 1
        print(f"str_out audit: {len(rows) - len(g)}/{len(rows)} printable sites rendered as "
              f"data by asm/, {len(g)} known rendering gaps, no drift")
        return 0
    print(f"{len(rows)} printable str_out sites, {len(g)} rendering gaps. --list / --show / --check")
    return 0


if __name__ == "__main__":
    sys.exit(main())
