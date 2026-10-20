#!/usr/bin/env python3
"""Recover the messages a session actually printed, from the CFG alone.

WARNING — THIS TOOL IS CURRENTLY WRONG AND MUST NOT BE TRUSTED.
It reads `CfgBlocks`, which lists *discovered* blocks, not executed ones:
Spice86 statically expands branch successors. Run against the vga-test harvest it
reported `MINAX IS DEAD!!`, `RING PROTECTS FROM FIELD!` and
`FIELD CAUSES 1000 DAMAGE!` for a session that never met Minax, a ring or a force
field. The fix is to gate on `ExecutedInstructions` in
`spice86dumpExecutionFlow.json`, which excludes all three and correctly keeps
`LEGS PARALIZED!` while dropping `ARMS PARALIZED!`. Tracked in
`docs/phase4-state.md § Backlog`. Do not cite output from this tool as evidence
until that is done.

Why the idea is still good: the game prints through `call str_out` (runtime
0x4FDF) with the string sitting inline in the code stream immediately after the
call, so a genuinely executed block containing a str_out call is proof its string
was printed at least once — no screen capture required. Combat text is drawn and
overwritten inside a single turn, so framebuffer sampling at turn boundaries
caught nothing across 151 turns of a real fight.

Address model, verified against a known case: a block entry is a runtime offset
in the code segment, the file offset is runtime + 0x200, and the string begins at
the call plus the 3-byte near-call encoding. `017D:2B8F` calls str_out at the
block start, so its string is at file 0x2D92, which reads "ATTACK--". Do not add
the segment base as well as the 0x200 — that finds nothing.

What this can give you: the SET of messages a session produced. What it cannot:
order or count. The CFG is cumulative, not a timeline, so "printed at least once"
is the honest claim. For ordering you need the execution-flow edges or the VGA
ring.

Usage: tools/cfg_printed.py <harvest-dir> [--exe original/ultimaii.exe]
                            [--contains TEXT]
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
# The game prefixes messages with layout control bytes: 0x0D carriage return,
# 0x8D a cursor/positioning marker used heavily in the status code. They are part
# of the message but not printable, so strip leading ones before validating.
# Without this, "\rKILLED--GOLD+" was silently dropped by the printable check.
LEAD_CTRL = (0x0D, 0x0A, 0x8D)
PRINTABLE = re.compile(rb"^[\x20-\x7e\x80-\xff]{2,}$")


def block_addr(entry: str) -> int:
    return int(entry.split(":")[1], 16)


def extract(exe: bytes, file_off: int, limit: int = 80) -> str | None:
    raw = exe[file_off:file_off + limit].split(b"\x00")[0]
    lead = []
    while raw and raw[0] in LEAD_CTRL:
        lead.append(raw[0])
        raw = raw[1:]
    if not raw or not PRINTABLE.match(raw):
        return None
    text = raw.decode("latin1")
    if lead:
        text = "\\x" + "\\x".join(f"{b:02x}" for b in lead) + text
    return text


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("harvest")
    ap.add_argument("--exe", default="original/ultimaii.exe")
    ap.add_argument("--contains", default=None,
                    help="only show messages containing this text")
    args = ap.parse_args()

    hdir = pathlib.Path(args.harvest)
    cfg = hdir / "spice86dumpCfgBlocks.json"
    if not cfg.exists():
        sys.exit(f"no CFG in {hdir}")
    exe = pathlib.Path(args.exe).read_bytes()
    blocks = json.loads(cfg.read_text())["blocks"]

    printed: list[tuple[str, str]] = []
    for blk in blocks:
        entry = blk["entry"]
        asm = blk.get("asm") or []
        addr = block_addr(entry)
        off = 0
        for item in asm:
            parts = item.split("|", 1)
            if len(parts) != 2:
                continue
            hexbytes, text = parts
            if text.strip() == STR_OUT:
                msg = extract(exe, addr + off + NEAR_CALL_LEN + RUNTIME_TO_FILE)
                if msg:
                    printed.append((entry, msg))
            off += len(hexbytes) // 2

    if args.contains:
        needle = args.contains.upper()
        printed = [(e, m) for e, m in printed if needle in m.upper()]

    print(f"{len(blocks)} blocks scanned, "
          f"{len(printed)} executed str_out sites resolved")
    seen = set()
    for entry, msg in printed:
        key = (entry, msg)
        if key in seen:
            continue
        seen.add(key)
        print(f"  {entry}  {msg!r}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
