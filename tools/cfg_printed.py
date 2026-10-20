#!/usr/bin/env python3
"""Recover the messages a session actually printed, from the harvest alone.

Principle: the game prints through `call str_out` (runtime 0x4FDF) with the
string sitting inline in the code stream immediately after the call. So if the
call instruction itself executed, its string was printed at least once — no
screen capture required. This matters because combat text is drawn and
overwritten inside a single turn, so framebuffer sampling at turn boundaries
caught nothing across 151 turns of a real fight, while memory proved a kill.

THE SOURCE MATTERS, AND GETTING IT WRONG IS EASY.
`spice86dumpCfgBlocks.json` lists *discovered* blocks, not executed ones —
Spice86 statically expands branch successors. Gating on it reported
`MINAX IS DEAD!!`, `RING PROTECTS FROM FIELD!` and `FIELD CAUSES 1000 DAMAGE!`
for a session that never met Minax, a ring or a force field. The authority is
`ExecutedInstructions` in `spice86dumpExecutionFlow.json`: a list of
`{Offset, Segment, Linear}` dicts of instructions that really ran. It excludes
all three of those, keeps `LEGS PARALIZED!`, and drops `ARMS PARALIZED!`. A
harvest taken before any fighting shows none of the combat strings, which is the
negative control that makes the positives trustworthy.

Address model, verified against a known case: a block entry is a runtime offset
in the code segment. The file offset is `runtime + 0x200`, and the string begins
at the call plus the 3-byte near-call encoding. `017D:2B8F` calls str_out at the
block start, so its string is at file 0x2D92 and reads "ATTACK--". Do not add the
segment base as well as the 0x200 — that silently finds nothing. For the executed
test the linear address IS `segment*16 + runtime`.

What this gives you: the SET of messages a session produced. What it cannot:
order or count. `ExecutedInstructions` is a set of distinct addresses with no
timestamps and no repetition counts, so "the thief stole it, then I attacked" is
not recoverable here. For ordering you need str_out breakpoints or the VGA ring.

Usage:
  tools/cfg_printed.py <harvest-dir> [--exe PATH] [--contains TEXT] [--all]
  --all   also list discovered-but-never-executed print sites, marked as such
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

STR_OUT = "call near 0x4FDF"
RUNTIME_TO_FILE = 0x200
NEAR_CALL_LEN = 3
# Messages are prefixed with layout control bytes: 0x0D carriage return, 0x8D a
# cursor/positioning marker used heavily in the status code. They are part of the
# message but not printable, so strip leading ones before validating; without
# this "\rKILLED--GOLD+" vanished behind the printable check.
LEAD_CTRL = (0x0D, 0x0A, 0x8D)
PRINTABLE = re.compile(rb"^[\x20-\x7e\x80-\xff]{2,}$")


def split_entry(entry: str) -> tuple[int, int]:
    seg, off = entry.split(":")
    return int(seg, 16), int(off, 16)


def extract(exe: bytes, file_off: int, limit: int = 80) -> str | None:
    """Read the inline string at file_off.

    Control bytes appear on BOTH ends: `0x0D`/`0x8D` prefix layout-sensitive
    messages and `0x0D` also trails them — `LEGS PARALIZED!\r` and
    `--PARALIZED!\r` both end in CR. Stripping only the leading ones made the
    printable test reject the two paralysis messages, which is precisely the
    evidence being hunted, and it failed silently. Strip both ends, and keep the
    markers in the output so the caller can still see them.
    """
    raw = exe[file_off:file_off + limit].split(b"\x00")[0]
    lead = []
    while raw and raw[0] in LEAD_CTRL:
        lead.append(raw[0])
        raw = raw[1:]
    trail = []
    while raw and raw[-1] in LEAD_CTRL:
        trail.append(raw[-1])
        raw = raw[:-1]
    if not raw or not PRINTABLE.match(raw):
        return None
    text = raw.decode("latin1")
    if lead:
        text = "\\x" + "\\x".join(f"{b:02x}" for b in lead) + text
    if trail:
        text += "\\x" + "\\x".join(f"{b:02x}" for b in reversed(trail))
    return text


def executed_lines(harvest: pathlib.Path) -> set[int]:
    flow = harvest / "spice86dumpExecutionFlow.json"
    if not flow.exists():
        sys.exit(f"missing {flow} — cannot tell executed from discovered; "
                 f"refusing to guess")
    data = json.loads(flow.read_text())
    entries = data.get("ExecutedInstructions") or []
    if not entries:
        sys.exit("ExecutedInstructions is empty — refusing to report guesses")
    return {e["Linear"] for e in entries}


def print_sites(blocks: list[dict], exe: bytes) -> list[dict]:
    """Every str_out call site in the discovered CFG, with its addresses."""
    sites = []
    for blk in blocks:
        seg, addr = split_entry(blk["entry"])
        off = 0
        for item in blk.get("asm") or []:
            parts = item.split("|", 1)
            if len(parts) != 2:
                continue
            hexbytes, text = parts
            if text.strip() == STR_OUT:
                msg = extract(exe, addr + off + NEAR_CALL_LEN + RUNTIME_TO_FILE)
                sites.append({
                    "block": blk["entry"],
                    "call_linear": seg * 16 + addr + off,
                    "msg": msg,
                })
            off += len(hexbytes) // 2
    return sites


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("harvest")
    ap.add_argument("--exe", default="original/ultimaii.exe")
    ap.add_argument("--contains", default=None,
                    help="only show messages containing this text")
    ap.add_argument("--all", action="store_true",
                    help="also show discovered-but-not-executed print sites")
    args = ap.parse_args()

    hdir = pathlib.Path(args.harvest)
    cfg = hdir / "spice86dumpCfgBlocks.json"
    if not cfg.exists():
        sys.exit(f"no CFG in {hdir}")
    exe = pathlib.Path(args.exe).read_bytes()
    blocks = json.loads(cfg.read_text())["blocks"]
    ran = executed_lines(hdir)
    sites = print_sites(blocks, exe)

    hit = [s for s in sites if s["msg"] and s["call_linear"] in ran]
    miss = [s for s in sites if s["msg"] and s["call_linear"] not in ran]

    if args.contains:
        needle = args.contains.upper()
        hit = [s for s in hit if needle in s["msg"].upper()]
        miss = [s for s in miss if needle in s["msg"].upper()]

    print(f"{len(blocks)} blocks, {len(sites)} str_out sites, "
          f"{len(ran)} executed instructions in this harvest")
    print(f"\n=== PRINTED ({len(hit)} sites, call instruction confirmed executed)")
    seen = set()
    for s in hit:
        key = (s["block"], s["msg"])
        if key in seen:
            continue
        seen.add(key)
        print(f"  {s['block']}  {s['msg']!r}")

    if args.all:
        print(f"\n=== DISCOVERED BUT NEVER EXECUTED ({len(miss)} sites) — "
              f"these did NOT print")
        seen = set()
        for s in miss:
            key = (s["block"], s["msg"])
            if key in seen:
                continue
            seen.add(key)
            print(f"  {s['block']}  {s['msg']!r}")
    else:
        print(f"\n({len(miss)} further print sites were discovered but never "
              f"executed; pass --all to list them)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
