#!/usr/bin/env python3
"""
bcd_census.py — enumerate every packed-decimal arithmetic site in asm/ and report
how (or whether) each one guards its result.

Why this tool exists
--------------------
T4 proved that a kill reward added to gold at the 9999 ceiling WRAPS to 14 rather
than clamping: asm/2DC1_combat_gold_gain does `adc`/`daa` per BCD byte and simply
discards the carry out of the top byte. A census of the same idiom across asm/
shows whether that is one bug or a house style, and — on the subtract side —
whether underflow is guarded.

The two idioms the 8088 forces on you
------------------------------------
add:  clc ; mov FIELD,%al ; adc $n,%al ; daa ; mov %al,FIELD
      The carry out of the top byte is DISCARDED unless a later jcc tests it.
sub:  stc/cmc ; mov FIELD,%al ; cmc ; sbb $n,%al ; das ; cmc ; mov %al,FIELD
      The `cmc` after `das` deliberately re-exposes the borrow in CF so a
      following `jb`/`jae` can branch on it. A `cmp`/`test` search MISSES this,
      which is the mistake this tool was written not to repeat.

Guard classification (per site, and per function chain)
-----------------------------------------------------
  borrow-test  a cmc sits between das and the store AND a jb/jbe/jae/ja follows
  clamp        a cmp/test of the field with a conditional branch
  none         neither found in the window
`stored_before_guard` records whether the (possibly wrapped) value is written to
memory before the branch — in asm/2599 it is, so the wrapped value survives even
though the code notices.

Known false-positive class
--------------------------
A `das`/`daa` can also be a *mis-decoded data byte* in a bulk-wave function that
was never reviewed (e.g. asm/025E, the "REVENGE" title printer, whose `das` is
followed by the nonsense `add %al,(%bp,%di)`). Such sites rarely target a known
counter, so they are tallied separately as non-counter sites and must NOT be read
as game mechanics. Check the file's `# confidence:` header before citing one.

Derived view: this prints, it does not store. Regenerate rather than copy.
Usage: python3 tools/bcd_census.py [--detail] [--op daa|das] [--counters-only]
"""
import argparse
import collections
import glob
import os
import re
import sys

HEX = r"(?:0x)?([0-9A-Fa-f]{2,4})"
RE_DAA = re.compile(r"^\s*daa\b")
RE_DAS = re.compile(r"^\s*das\b")
RE_FORCED = re.compile(r"re-encodes '(daa|das)'")
RE_ADC = re.compile(r"\badc\s+([^,]+),%[a-z]+")
RE_SBB = re.compile(r"\bsbb\s+([^,]+),%[a-z]+")
RE_STORE = re.compile(r"\bmov\s+%[a-z]+," + HEX + r"(?:\((%di|%bx|%si|%bp)\))?")
RE_JCC = re.compile(r"\b(jb|jbe|jae|ja|jl|jge|jg|jle)\b")
RE_CMP = re.compile(r"\b(cmp|test)\b")

# DS offset -> field name. Source: docs/save-format.md "proven" table and
# engine/src/core/state.h. 0x4E/0x4F are DISPUTED (state.h cha/wis vs live).
FIELDS = {
    "4b": "stat_str", "4c": "stat_agi", "4d": "stat_sta",
    "4e": "stat_cha(DISPUTED)", "4f": "stat_wis(DISPUTED)", "50": "stat_int",
    "51": "hp_hi", "52": "hp_lo",
    "53": "food_hi", "54": "food_mid", "55": "food_lo",
    "56": "exp_a", "57": "exp_b",
    "58": "gold_a", "59": "gold_b",
    "64": "torches", "65": "keys", "66": "tools", "6d": "boots",
    "e5": "item_slot_15",
}
# Indexed bases: target = base + index register.
BASES = {
    "76": "weapons_owned[i]", "96": "armour_owned[i]",
    "b6": "DS:b6[i](unnamed)", "d6": "items_held[i]",
}


def field_of(target, indexed):
    if target == "?":
        return "?", False
    t = target.lower().lstrip("0") or "0"
    if indexed and indexed != "direct":
        if t in BASES:
            return BASES[t], True
        return f"DS:{target}(i)", False
    if t in FIELDS:
        return FIELDS[t], True
    return f"DS:{target}", False


def op_of(line):
    """Return 'daa'/'das' for a decimal-adjust line, else None.

    Matches the plain mnemonic and the `.byte 0x27` / `.byte 0x2f` forced-kept
    encoding the clean corpus uses where gas re-encoded the instruction
    differently. Missing those would silently under-count the census.
    """
    if RE_DAA.match(line):
        return "daa"
    if RE_DAS.match(line):
        return "das"
    m = RE_FORCED.search(line)
    return m.group(1) if m else None


def analyse(path):
    lines = open(path, errors="replace").read().splitlines()
    name = os.path.basename(path)
    conf = "unset"
    for ln in lines[:12]:
        m = re.search(r"#\s*confidence:\s*(\w+)", ln)
        if m:
            conf = m.group(1)
            break
    sites = []
    for i, ln in enumerate(lines):
        op = op_of(ln)
        if not op:
            continue
        addend, imm = "?", "?"
        pat = RE_SBB if op == "das" else RE_ADC
        for j in range(i - 1, max(-1, i - 8), -1):
            m = pat.search(lines[j]) or RE_ADC.search(lines[j]) or RE_SBB.search(lines[j])
            if m:
                a = m.group(1).strip()
                imm = "imm" if a.startswith("$") else "mem"
                addend = a
                break
        target, indexed = "?", "direct"
        for j in range(i + 1, min(len(lines), i + 10)):
            t = lines[j]
            if op_of(t):
                break
            m = RE_STORE.search(t)
            if m:
                target, indexed = m.group(1), (m.group(2) or "direct")
                break
        field, counter = field_of(target, indexed)
        # guard detection over a window after the adjust
        win = lines[i + 1:min(len(lines), i + 16)]
        joined = "\n".join(win)
        cmc_after = any(re.search(r"\bcmc\b", w) for w in win[:6])
        jcc = RE_JCC.search(joined)
        clamp = RE_CMP.search(joined)
        if op == "das" and cmc_after and jcc:
            guard = "borrow-test"
        elif clamp and jcc:
            guard = "clamp"
        elif jcc:
            guard = "branch-only"
        else:
            guard = "none"
        # is the store before the first conditional branch?
        stored_first = "no"
        for w in win:
            if RE_STORE.search(w) and not op_of(w):
                stored_first = "yes"
                break
            if RE_JCC.search(w):
                stored_first = "no"
                break
        sites.append(dict(file=name, line=i + 1, op=op, addend=addend, imm=imm,
                          target=target, indexed=indexed, conf=conf,
                          field=field, counter=counter, guard=guard,
                          stored_first=stored_first, win=lines[max(0, i - 6):i + 10]))
    return sites


def main():
    ap = argparse.ArgumentParser()
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ap.add_argument("--asm", default=os.path.join(root, "asm"))
    ap.add_argument("--detail", action="store_true")
    ap.add_argument("--op", choices=["daa", "das", "both"], default="both")
    ap.add_argument("--counters-only", action="store_true",
                    help="list only sites that target a known game counter")
    a = ap.parse_args()

    files = sorted(glob.glob(os.path.join(a.asm, "*.asm")))
    if not files:
        # Fail loudly: an empty census reads exactly like a clean bill of health.
        print(f"ERROR: no .asm files under {a.asm} — cannot census", file=sys.stderr)
        return 2

    sites = []
    for f in files:
        sites.extend(analyse(f))
    if not sites:
        print("ERROR: no daa/das sites found — asm/ layout changed or parse broke",
              file=sys.stderr)
        return 2

    if a.op != "both":
        shown = [s for s in sites if s["op"] == a.op]
    else:
        shown = sites
    if a.counters_only:
        shown = [s for s in shown if s["counter"]]

    print(f"{len(sites)} decimal-adjust sites in {len(files)} asm files "
          f"({sum(1 for s in sites if s['op']=='daa')} daa add / "
          f"{sum(1 for s in sites if s['op']=='das')} das sub); "
          f"{sum(1 for s in sites if s['counter'])} target a known counter\n")
    print(f"{'file':32} {'ln':>4} {'op':4} {'addend':9} {'imm':4} "
          f"{'field':22} {'guard':12} stored-first conf")
    print("-" * 114)
    for s in shown:
        print(f"{s['file']:32} {s['line']:>4} {s['op']:4} {s['addend']:9} {s['imm']:4} "
              f"{'':3} {s['field']:22} {s['guard']:12} {s['stored_first']}  {s['conf']}")

    print("\nguard tally, KNOWN COUNTER sites only (trust these):")
    t = collections.Counter((s["op"], s["guard"]) for s in sites if s["counter"])
    for op in ("daa", "das"):
        row = {g: n for (o, g), n in t.items() if o == op}
        print(f"  {op}: " + ", ".join(f"{k}={v}" for k, v in sorted(row.items())))
    n_nc = sum(1 for s in sites if not s["counter"])
    print(f"\n{n_nc} non-counter sites excluded from the tally above — unresolved target "
          f"or mis-decoded data; do not cite them as mechanics.")

    print("\nunguarded ADD sites on known counters (the T4 wrap family):")
    for s in sites:
        if s["op"] == "daa" and s["counter"] and s["guard"] in ("none", "branch-only"):
            print(f"  {s['file']}:{s['line']}  +{s['addend']} -> {s['field']}")

    print("\nsubtract sites with NO borrow test on known counters (underflow unguarded):")
    print("  NOTE: read this per FIELD CHAIN, not per byte. A multi-byte field tests")
    print("  the borrow once, on its TOP byte (e.g. asm/2599 food: food_lo and food_mid")
    print("  show none, food_hi shows borrow-test). So a 'none' on a low byte of a")
    print("  multi-byte field is not an unguarded subtract. The exposed cases are the")
    print("  single-byte counters, which have no chain-end test to catch them.")
    for s in sites:
        if s["op"] == "das" and s["counter"] and s["guard"] in ("none", "branch-only"):
            print(f"  {s['file']}:{s['line']}  -{s['addend']} -> {s['field']}")

    if a.detail:
        for s in shown:
            print(f"\n===== {s['file']}:{s['line']} {s['op']} -> {s['field']} "
                  f"[{s['guard']}] =====")
            for w in s["win"]:
                print("   " + w)
    return 0


if __name__ == "__main__":
    sys.exit(main())
