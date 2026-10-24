#!/usr/bin/env python3
"""str_out_audit.py — every `call str_out` must be followed by a string the atlas reports.

Why this is a gate and not a survey. The string printer's calling convention is one of the
best-evidenced facts in this project: `call L_0051df` and the bytes immediately after the return
address ARE the message, NUL-terminated, optionally wrapped in 0x8D/0x0D control bytes (the same
contract the Apple II side has, `JSR $4006` — see docs/apple2-reference.md § 4). So the set of
call sites is not an inference from a listing, it is a property of the executable, and it can be
enumerated from `original/ultimaii.exe` alone.

That gives a check `strings_atlas.py` cannot do on its own. The atlas extracts strings from the
`db` lines in `asm/`, so it can only ever report what Phase 3 chose to render as data. When the
clean wave put a printed message inside a code span, the atlas goes quiet about a string the
game definitely prints — and it stays quiet, because nothing downstream can tell the difference
between "no string there" and "string there, rendered as instructions". This tool compares the
contract's answer with the atlas's answer and reports the gap.

It found 16 on first run and 11 after the extraction bug it exposed was fixed — see
`disasm/defects.md`, which records both the wrong count and the wrong explanation for it. What
survives is still worth having: three of the five `ANOS:` era lines, the title screen's copyright
line, `KLIMB`, `IGNITE TORCH`, `SPELL-`, and a handful of command rejects that `asm/` draws as
instructions and the atlas therefore cannot see.

THE COMMITTED ARTEFACT IS OFFSETS ONLY. No game text reaches a file — `--show` prints text to
stdout and nothing else does, same rule as tools/apple2_anchor_map.py and for the same reason
(AGENTS.md's text line). `disasm/str-out-unmatched.tsv` is the allow-list: known-unmatched
sites, by offset, length and owning `asm/` file.

Usage:
    python3 tools/str_out_audit.py --selftest      # controls, including a deliberate failure
    python3 tools/str_out_audit.py --check         # CI-shaped: exit 1 on drift either way
    python3 tools/str_out_audit.py --list          # unmatched sites, offsets only
    python3 tools/str_out_audit.py --show          # the same WITH text, stdout only
    python3 tools/str_out_audit.py --emit          # rewrite the allow-list
"""
import argparse
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import strings_atlas  # noqa: E402  the DOS side, imported not reimplemented

EXE = "original/ultimaii.exe"
BIAS = 0x200
STR_OUT_FILE = 0x51DF          # runtime 0x4FDF? no: the L_0051df label IS the file offset
WRAPPERS = (0x8D, 0x0D)
MIN_LEN = 3
ALLOW = "disasm/str-out-unmatched.tsv"
FUNC_RE = re.compile(r"^#\s*func\s+([0-9A-Fa-f]{4})\.\.([0-9A-Fa-f]{4})", re.M)


def call_sites(exe, target=STR_OUT_FILE):
    """File offsets of the byte after every near `call` to the printer."""
    out = []
    for i in range(len(exe) - 3):
        if exe[i] == 0xE8 and i + 3 + int.from_bytes(exe[i + 1:i + 3], "little", signed=True) == target:
            out.append(i + 3)
    return out


def message_at(exe, off):
    """The message a str_out call prints: skip control wrappers, read to the NUL."""
    j = off
    while j < len(exe) and exe[j] in WRAPPERS:
        j += 1
    k = j
    while k < len(exe) and exe[k] != 0:
        k += 1
    raw = exe[j:k]
    if len(raw) < MIN_LEN:
        return None
    if not all(0x20 <= c <= 0x7E for c in raw):
        return None
    return j, raw.decode("latin1")


def owner_of(foff):
    """The asm/ file whose declared # func range contains this file offset."""
    best = None
    for p in sorted(glob.glob("asm/*.asm")):
        m = FUNC_RE.search(open(p, errors="replace").read())
        if not m:
            continue
        s = int(m.group(1), 16) + BIAS
        e = int(m.group(2), 16) + BIAS
        if s <= foff < e:
            best = os.path.basename(p)[:-4]
    return best or "?"


def audit(exe=None, atlas=None):
    if exe is None:
        exe = open(EXE, "rb").read()
    sites = call_sites(exe)
    known = {r["foff"] for r in (atlas if atlas is not None else strings_atlas.build())}
    rows = []
    for o in sites:
        m = message_at(exe, o)
        if m is None:
            continue                      # not a message (a jump table, a pad, a false E8)
        off, text = m
        rows.append({"site": o, "foff": off, "len": len(text), "text": text,
                     "matched": any(abs(off - k) <= 2 for k in known),
                     "owner": owner_of(off)})
    return rows


def load_allow(path=ALLOW):
    if not os.path.exists(path):
        return None
    out = set()
    for line in open(path):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if parts[0].lower() == "file_off":
            continue
        out.add(int(parts[0], 16))
    return out


def render(rows):
    lines = ["# str_out call sites the atlas does not report. Generated — do not hand-edit.",
             "#   python3 tools/str_out_audit.py --emit",
             "# Offsets are FILE offsets (runtime + 0x200). No game text: len is the byte count.",
             "file_off\truntime\tlen\tasm_owner_claiming_this_range"]
    for r in sorted(rows, key=lambda x: x["foff"]):
        lines.append("%05X\t%05X\t%d\t%s" % (r["foff"], r["foff"] - BIAS, r["len"], r["owner"]))
    return "\n".join(lines) + "\n"


def selftest():
    exe = open(EXE, "rb").read()
    rows = audit(exe)
    matched = [r for r in rows if r["matched"]]
    unmatched = [r for r in rows if not r["matched"]]
    fails = []
    sites = call_sites(exe)
    if len(sites) < 300:
        fails.append(f"only {len(sites)} near calls to the printer — the call-site scan or the "
                     f"printer address (0x{STR_OUT_FILE:04X}) is wrong, not the tree")
    if len(rows) < 200:
        fails.append(f"only {len(rows)} of {len(sites)} sites carry a printable message — the "
                     "message reader is over-rejecting")
    if len(matched) < len(unmatched) * 5:
        fails.append(f"{len(matched)} matched vs {len(unmatched)} unmatched — the atlas or the "
                     f"matcher regressed; the honest ratio is roughly 20:1")
    # Positive control: a string the atlas is known to report must come back matched.
    # asm/0A02 is the reject echo, and it is the case the trailing-db bug silently dropped.
    if not any(r["matched"] and r["owner"].startswith("0A02") for r in rows):
        fails.append("asm/0A02's message is not a matched str_out site — the atlas lost it again")
    # Negative control, and the one that makes this a gate rather than a report: feed the audit
    # an atlas with one entry removed and it MUST notice. A checker that cannot go red here is
    # the failure mode AGENTS.md names.
    atlas = strings_atlas.build()
    victim = next(r for r in atlas if r["file"].startswith("0A02"))
    crippled = [r for r in atlas if r is not victim]
    probe = audit(exe, atlas=crippled)
    if not any(p["foff"] == victim["foff"] and not p["matched"] for p in probe):
        fails.append("removing a string from the atlas did NOT show up as unmatched — the "
                     "comparison is not reading the atlas it was given")
    # And the reverse: a site with no message after it must not be reported at all.
    if any(r["len"] < MIN_LEN for r in rows):
        fails.append("a sub-MIN_LEN run was reported as a message")
    if fails:
        print("SELFTEST FAILED")
        for f in fails:
            print("  -", f)
        return 1
    print(f"selftest ok: {len(rows)} printable str_out sites, {len(matched)} matched, "
          f"{len(unmatched)} unmatched; the atlas-minus-one probe correctly went red")
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
    unmatched = [r for r in rows if not r["matched"]]
    if a.emit:
        open(ALLOW, "w").write(render(unmatched))
        print(f"wrote {ALLOW}: {len(unmatched)} sites")
        return 0
    if a.show:
        for r in sorted(unmatched, key=lambda x: x["foff"]):
            print("file:%05X runtime:%05X owner:%s  %r"
                  % (r["foff"], r["foff"] - BIAS, r["owner"], r["text"]))
        print(f"\n{len(unmatched)} unmatched of {len(rows)} printable sites")
        return 0
    if a.list:
        print(render(unmatched))
        return 0
    if a.check:
        allow = load_allow()
        if allow is None:
            print(f"{ALLOW} missing — run --emit", file=sys.stderr)
            return 1
        now = {r["foff"] for r in unmatched}
        new = sorted(now - allow)
        fixed = sorted(allow - now)
        bad = False
        if new:
            print(f"NEW unmatched str_out sites ({len(new)}) — asm/ renders a printed message "
                  f"as instructions and the atlas cannot see it:")
            for f in new:
                r = next(x for x in unmatched if x["foff"] == f)
                print(f"  file {f:05X} runtime {f - BIAS:05X} owner {r['owner']} len {r['len']}")
            bad = True
        if fixed:
            print(f"{len(fixed)} allow-listed sites are now matched — the allow-list is stale, "
                  f"run --emit (a list that only grows is a list nobody trusts):")
            for f in fixed:
                print(f"  file {f:05X}")
            bad = True
        if bad:
            return 1
        print(f"str_out audit: {len(rows) - len(unmatched)}/{len(rows)} printable sites matched, "
              f"{len(unmatched)} known-unmatched, no drift")
        return 0
    print(f"{len(rows)} printable str_out sites, {len(rows) - len(unmatched)} matched, "
          f"{len(unmatched)} unmatched. --list / --show / --check")
    return 0


if __name__ == "__main__":
    sys.exit(main())
