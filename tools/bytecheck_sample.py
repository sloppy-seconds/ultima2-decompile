#!/usr/bin/env python3
"""CP6: stratified byte-check over Ghidra + Reko claims.

Sample = ALL jump-table handlers + a stratified random sample of the remaining entries
(strata: ghidra status ok/failed x size bucket small<=0x20 / mid<=0x80 / large>0x80).
For each sampled entry:
  - Ghidra claim: C body from ultimaii.c, claimed size from the index TSV (span-to-next
    used when the body is a failure stub).
  - Reko claim: define from reko/ultimaii.c, checked over the entry->next-entry span
    (Reko emits no machine-readable body size).
Writes disasm/bytecheck-report.md. Deterministic: fixed RNG seed.
"""
import bisect
import json
import random
import re
import sys

sys.path.insert(0, "tools")
from bytecheck import literals_from_c, present, range_bytes  # noqa: E402

SEEDS_FILE = "disasm/seed-entries.txt"
JT_FILE = "disasm/jump-table.txt"
GIDX = "decompiled/ghidra/ultimaii-functions.tsv"
GC = "decompiled/ghidra/ultimaii.c"
RC = "decompiled/reko/ultimaii.c"
OUT = "disasm/bytecheck-report.md"
RNG_SEED = 20261019
EXTRA_SAMPLE = 18  # on top of the 26 handlers


def load_seeds():
    return sorted(int(l.split()[0], 16) for l in open(SEEDS_FILE))


def load_ghidra():
    rows = {}
    with open(GIDX) as f:
        hdr = f.readline()  # noqa: F841
        for line in f:
            p = line.rstrip("\n").split("\t")
            if len(p) < 5:
                continue
            entry = int(p[0].split(":")[1], 16)
            rows[entry] = {"name": p[2], "size": int(p[3]), "status": p[4]}
    # bodies
    txt = open(GC).read()
    bodies = {}
    for m in re.finditer(r"/\* ===== (1000:[0-9a-f]{4}).*?\((\d+) bytes\) ===== \*/\n(.*?)(?=\n/\* ===== |\Z)",
                         txt, re.S):
        e = int(m.group(1).split(":")[1], 16)
        bodies[e] = m.group(3)
    return rows, bodies


def load_reko():
    txt = open(RC).read()
    defs = {}
    for m in re.finditer(r"^define (fn0800_([0-9a-fA-F]{4}))\n\{.*?^\}", txt, re.S | re.M):
        defs[int(m.group(2), 16)] = m.group(0)
    return defs


def check(entry, size, c_body):
    raw = range_bytes(entry, size)
    lits = literals_from_c(c_body)
    missing = [v for v in lits if not present(v, raw)]
    return lits, missing


def main():
    seeds = load_seeds()
    gidx, gbodies = load_ghidra()
    rdefs = load_reko()

    handlers = {}
    for line in open(JT_FILE):
        off, lab = line.split()
        handlers[int(off, 16)] = lab

    def bucket(sz):
        return "small" if sz <= 0x20 else ("mid" if sz <= 0x80 else "large")

    # stratified extra sample from non-handler entries
    pool = {}
    for e in seeds:
        if e in handlers:
            continue
        st = "ok" if gidx.get(e, {}).get("status", "absent") == "ok" else "failed"
        sz = gidx.get(e, {}).get("size", 0)
        pool.setdefault((st, bucket(sz)), []).append(e)
    rng = random.Random(RNG_SEED)
    extra = []
    strata = sorted(pool)
    per = max(1, EXTRA_SAMPLE // len(strata))
    for k in strata:
        take = min(per, len(pool[k]))
        extra += rng.sample(pool[k], take)
    while len(extra) < EXTRA_SAMPLE:
        k = rng.choice(strata)
        e = rng.choice(pool[k])
        if e not in extra:
            extra.append(e)

    sample = sorted(set(handlers) | set(extra))
    rows = []
    for e in sample:
        nxt = seeds[bisect.bisect_right(seeds, e)] if bisect.bisect_right(seeds, e) < len(seeds) else 0x6000
        span = nxt - e
        g = gidx.get(e)
        gbody = gbodies.get(e, "")
        gfailed = g is None or g["status"] != "ok"
        gsize = span if gfailed else max(g["size"], 2)
        if gbody:
            gl, gm = check(e, gsize, gbody)
        else:
            gl, gm = [], []
        rbody = rdefs.get(e, "")
        if rbody:
            rl, rm = check(e, span, rbody)
        else:
            rl, rm = [], []
        verdict = "verified" if not (gm or rm) else "mismatch"
        if not gbody and not rbody:
            verdict = "unverified"
        rows.append({
            "entry": f"{e:04X}", "handler": handlers.get(e, ""),
            "in_sample": "handler" if e in handlers else "stratified",
            "ghidra_status": "ok" if g and g["status"] == "ok" else ("failed" if g else "absent"),
            "ghidra_claim_size": gsize, "ghidra_lits": len(gl), "ghidra_missing": [f"0x{v:X}" for v in gm],
            "reko_defined": bool(rbody), "reko_span": span, "reko_lits": len(rl),
            "reko_missing": [f"0x{v:X}" for v in rm],
            "verdict": verdict,
        })

    with open(OUT, "w") as f:
        f.write(f"# Byte-check report (CP6)\n\n")
        f.write(f"Sample: {len(sample)} functions = all 26 jump-table handlers + "
                f"{len(sample)-26} stratified (seed={RNG_SEED}).\n\n")
        f.write("Method: every integer literal and DS-relative operand asserted by the "
                "decompiler C must appear as a little-endian byte pattern (1-4 B) inside the "
                "claimed range of `original/ultimaii.exe`. Ghidra ranges = claimed body size "
                "(entry->next-entry span for failed stubs); Reko ranges = entry->next-entry "
                "span. Literals 0/1 skipped (implicit). Tool: `tools/bytecheck.py`.\n\n")
        f.write("| entry | src | handler | ghidra | g-size | g-lits | g-missing | reko | r-span | r-lits | r-missing | verdict |\n")
        f.write("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |\n")
        for r in rows:
            f.write(f"| {r['entry']} | {r['in_sample']} | {r['handler']} | {r['ghidra_status']} "
                    f"| {r['ghidra_claim_size']:#x} | {r['ghidra_lits']} | {','.join(r['ghidra_missing']) or '-'} "
                    f"| {'def' if r['reko_defined'] else 'none'} | {r['reko_span']:#x} | {r['reko_lits']} "
                    f"| {','.join(r['reko_missing']) or '-'} | {r['verdict']} |\n")
        n_v = sum(1 for r in rows if r["verdict"] == "verified")
        n_m = sum(1 for r in rows if r["verdict"] == "mismatch")
        n_u = sum(1 for r in rows if r["verdict"] == "unverified")
        f.write(f"\nTotals: {n_v} verified, {n_m} mismatch, {n_u} unverified of {len(rows)}.\n")
    print(f"sampled {len(sample)} -> {OUT}")
    print(json.dumps({"verified": sum(1 for r in rows if r['verdict']=='verified'),
                      "mismatch": sum(1 for r in rows if r['verdict']=='mismatch'),
                      "unverified": sum(1 for r in rows if r['verdict']=='unverified')}))


if __name__ == "__main__":
    main()
