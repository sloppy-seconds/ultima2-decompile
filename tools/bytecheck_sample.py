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
from bytecheck import EXE, clean_c, literals_from_c, present, range_bytes  # noqa: E402

SEEDS_FILE = "disasm/seed-entries.txt"
JT_FILE = "disasm/jump-table.txt"
GIDX = "decompiled/ghidra/ultimaii-functions.tsv"
GC = "decompiled/ghidra/ultimaii.c"
RC = "decompiled/reko/ultimaii.c"
RDIS = "decompiled/reko/ultimaii.dis"
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
    # Reko's own claimed code addresses, from the IR disassembly
    ranges = {}
    cur = None
    lo = hi = None
    for line in open(RDIS):
        m = re.match(r"^define fn0800_([0-9a-fA-F]{4})$", line)
        if m:
            if cur is not None:
                ranges[cur] = (lo, hi)
            cur = int(m.group(1), 16)
            lo = hi = cur
            continue
        m = re.match(r"^l0800_([0-9a-fA-F]{4}):", line)
        if m and cur is not None:
            a = int(m.group(1), 16)
            lo = min(lo, a)
            hi = max(hi, a)
    if cur is not None:
        ranges[cur] = (lo, hi)
    return defs, ranges


def check(entry, size, c_body, flavor="ghidra"):
    raw = range_bytes(entry, size)
    lits = literals_from_c(c_body, flavor)
    missing = [v for v in lits if not present(v, raw)]
    # context lines for each missing literal (from the cleaned body)
    ctx = {}
    lines = clean_c(c_body, flavor).splitlines()
    whole = open(EXE, "rb").read()
    for v in missing:
        hx = f"0x{v:X}"
        found = None
        for ln in lines:
            if re.search(r"(?<![0-9a-fA-F])" + re.escape(hx) + r"(?![0-9a-fA-F])", ln, re.I):
                found = ln.strip()[:90]
                break
        # does the pattern exist anywhere else in the file?
        pat = None
        for n in (2, 1, 3, 4):
            if v < (1 << (8 * n)):
                if v.to_bytes(n, "little") in whole:
                    pat = "elsewhere-in-file"
                    break
        else:
            pat = "absent-from-file"
        ctx[hx] = (found, pat)
    return lits, missing, ctx


def main():
    seeds = load_seeds()
    gidx, gbodies = load_ghidra()
    rdefs, rranges = load_reko()

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
        if gfailed:
            # a failure stub claims nothing
            gl, gm, gc = [], [], {}
        else:
            gl, gm, gc = check(e, max(g["size"], 2), gbody, "ghidra")
        rbody = rdefs.get(e, "")
        if rbody:
            rlo, rhi = rranges.get(e, (e, nxt))
            rspan = max(rhi - rlo + 6, 2)
            rl, rm, rc = check(rlo, rspan, rbody, "reko")
        else:
            rl, rm, rc, rspan = [], [], {}, 0
        has_claims = bool(gl or rl)
        verdict = "verified" if not (gm or rm) else "mismatch"
        if not has_claims:
            verdict = "no-claims"
        rows.append({
            "entry": f"{e:04X}", "handler": handlers.get(e, ""),
            "in_sample": "handler" if e in handlers else "stratified",
            "ghidra_status": "ok" if g and g["status"] == "ok" else ("failed" if g else "absent"),
            "ghidra_claim_size": 0 if gfailed else g["size"],
            "ghidra_lits": len(gl), "ghidra_missing": [f"0x{v:X}" for v in gm],
            "ghidra_ctx": gc,
            "reko_defined": bool(rbody), "reko_span": rspan, "reko_lits": len(rl),
            "reko_missing": [f"0x{v:X}" for v in rm],
            "reko_ctx": rc,
            "verdict": verdict,
        })

    with open(OUT, "w") as f:
        f.write(f"# Byte-check report (CP6)\n\n")
        f.write(f"Sample: {len(sample)} functions = all 26 jump-table handlers + "
                f"{len(sample)-26} stratified (seed={RNG_SEED}).\n\n")
        f.write("Method: every integer literal and DS-relative operand asserted by the "
                "decompiler C must appear as a little-endian byte pattern (1-4 B) inside the "
                "claimed range of `original/ultimaii.exe`. Ghidra ranges = claimed body size; "
                "failed stubs claim nothing (`no-claims`); Reko ranges = the procedure's own "
                "`l0800_` label extent from `ultimaii.dis` (+6 B last-instruction slack). "
                "Extraction strips comments, struct-layout fields, type tags, internal ids, "
                "and char literals - none of these are instruction claims. Literals <=2 "
                "skipped (implicit). Tool: `tools/bytecheck.py`.\n\n")
        f.write("| entry | src | handler | ghidra | g-size | g-lits | g-missing | reko | r-span | r-lits | r-missing | verdict |\n")
        f.write("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |\n")
        for r in rows:
            f.write(f"| {r['entry']} | {r['in_sample']} | {r['handler']} | {r['ghidra_status']} "
                    f"| {r['ghidra_claim_size']:#x} | {r['ghidra_lits']} | {','.join(r['ghidra_missing']) or '-'} "
                    f"| {'def' if r['reko_defined'] else 'none'} | {r['reko_span']:#x} | {r['reko_lits']} "
                    f"| {','.join(r['reko_missing']) or '-'} | {r['verdict']} |\n")
        n_v = sum(1 for r in rows if r["verdict"] == "verified")
        n_m = sum(1 for r in rows if r["verdict"] == "mismatch")
        n_u = sum(1 for r in rows if r["verdict"] == "no-claims")
        f.write(f"\nTotals: {n_v} verified, {n_m} mismatch, {n_u} no-claims of {len(rows)}.\n")
        f.write("\n## Flag detail (context line in the decompiler C; pattern location)\n\n")
        for r in rows:
            if r["verdict"] != "mismatch":
                continue
            f.write(f"### {r['entry']} ({r['handler'] or r['in_sample']})\n\n")
            for side in ("ghidra", "reko"):
                for v in r[side + "_missing"]:
                    ln, pat = r[side + "_ctx"].get(v, (None, None))
                    f.write(f"- {side} {v}: {pat}" + (f" | `{ln}`" if ln else "") + "\n")
            f.write("\n")
    print(f"sampled {len(sample)} -> {OUT}")
    print(json.dumps({"verified": sum(1 for r in rows if r['verdict']=='verified'),
                      "mismatch": sum(1 for r in rows if r['verdict']=='mismatch'),
                      "no_claims": sum(1 for r in rows if r['verdict']=='no-claims')}))


if __name__ == "__main__":
    main()
