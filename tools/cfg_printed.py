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
`{Offset, Segment, Linear}` dicts of instructions that really ran.

So print sites are derived from `ExecutedInstructions` as the PRIMARY source:
scan the executed code-segment instructions for the 3-byte near call `E8 <rel16>`
whose target is str_out (runtime 0x4FDF). Each hit is a call that really ran, and
its inline string was printed. CFG blocks are only a SECONDARY seed, used to list
discovered-but-never-executed sites under `--all`; they are never trusted as proof
that something printed.

Address model, verified against a known case: a code-segment instruction's file
offset is `runtime + 0x200`, and the inline string begins at the call plus the
3-byte near-call encoding. `017D:2B8F` calls str_out at the block start, so its
string is at file 0x2D92 and reads "ATTACK--". Do not add the segment base as well
as the 0x200 — that silently finds nothing. For the executed test the linear
address IS `segment*16 + runtime`.

The code segment is not hardcoded: it is the segment in which the str_out entry
(runtime 0x4FDF) itself appears in `ExecutedInstructions`. If str_out never ran
there is nothing to report and the tool says so rather than guessing.

Message terminator: an inline message is a run of printable bytes terminated by a
control byte. The control bytes 0x0D/0x0A/0x8D appear on BOTH ends of a message
(leading layout markers, trailing CR), and — critically — the *next* inline string
can follow the terminator with no NUL in between. `LAND--NOT HERE!!!!!\rCMD: \x00`
is two messages; splitting on the first NUL and requiring the whole run to be
printable made the tool reject `LAND--NOT HERE!!!!!` and drop it silently. So the
extractor strips leading control markers, then reads printable bytes up to the
first non-printable byte, and treats that as the message.

What this gives you: the SET of messages a session produced. What it cannot:
order or count. `ExecutedInstructions` is a set of distinct addresses with no
timestamps and no repetition counts, so "the thief stole it, then I attacked" is
not recoverable here. For ordering you need str_out breakpoints or the VGA ring.

Usage:
  tools/cfg_printed.py <harvest-dir> [--exe PATH] [--contains TEXT] [--all]
  --all       also list discovered-but-never-executed print sites, marked as such
  --selftest  run the built-in positive/negative control and exit non-zero on fail
"""
from __future__ import annotations

import argparse
import json
import pathlib
import sys

STR_OUT_RT = 0x4FDF          # runtime offset of the str_out trampoline
RUNTIME_TO_FILE = 0x200      # code-segment runtime offset -> file offset
NEAR_CALL = 0xE8             # opcode of a near relative call
NEAR_CALL_LEN = 3            # E8 + 16-bit relative displacement
MIN_MSG_LEN = 2              # shorter runs are noise, not messages
# Layout control bytes: 0x0D carriage return, 0x0A line feed, 0x8D a
# cursor/positioning marker used heavily in the status code. They bracket a
# message but are not part of its printable text, so strip leading ones and stop
# at the first one that terminates the run.
LEAD_CTRL = (0x0D, 0x0A, 0x8D)


def is_printable(b: int) -> bool:
    return 0x20 <= b <= 0x7E or 0x80 <= b <= 0xFF


def split_entry(entry: str) -> tuple[int, int]:
    seg, off = entry.split(":")
    return int(seg, 16), int(off, 16)


def extract(exe: bytes, file_off: int, limit: int = 80) -> str | None:
    """Read the inline message at file_off, or None if there is no message.

    Strips leading control markers (kept in the output so the caller can still
    see them), then reads printable bytes up to the first non-printable byte.
    That terminator may be a NUL *or* a control byte that begins the next inline
    string, which is why splitting on NUL alone silently dropped
    `LAND--NOT HERE!!!!!` (see module docstring).
    """
    win = exe[file_off:file_off + limit]
    i = 0
    lead = []
    while i < len(win) and win[i] in LEAD_CTRL:
        lead.append(win[i])
        i += 1
    start = i
    while i < len(win) and is_printable(win[i]):
        i += 1
    body = win[start:i]
    if len(body) < MIN_MSG_LEN:
        return None
    text = body.decode("latin1")
    if lead:
        text = "\\x" + "\\x".join(f"{b:02x}" for b in lead) + text
    return text


def is_str_out_call(exe: bytes, file_off: int, runtime: int) -> bool:
    """True if a near call at this runtime offset targets str_out."""
    if file_off + NEAR_CALL_LEN > len(exe) or exe[file_off] != NEAR_CALL:
        return False
    rel = int.from_bytes(exe[file_off + 1:file_off + NEAR_CALL_LEN],
                         "little", signed=True)
    return ((runtime + NEAR_CALL_LEN + rel) & 0xFFFF) == STR_OUT_RT


def load_executed(harvest: pathlib.Path) -> list[dict]:
    """Return ExecutedInstructions, failing loudly if the shape is not understood."""
    flow = harvest / "spice86dumpExecutionFlow.json"
    if not flow.exists():
        sys.exit(f"missing {flow} — cannot tell executed from discovered; "
                 f"refusing to guess")
    try:
        data = json.loads(flow.read_text())
    except (ValueError, OSError) as exc:
        sys.exit(f"cannot parse {flow}: {exc}")
    if not isinstance(data, dict) or "ExecutedInstructions" not in data:
        sys.exit(f"{flow} has no ExecutedInstructions key — dump shape not "
                 f"understood; refusing to guess")
    entries = data["ExecutedInstructions"] or []
    if not entries:
        sys.exit("ExecutedInstructions is empty — refusing to report guesses")
    for e in entries[:1]:
        if not (isinstance(e, dict) and {"Offset", "Segment", "Linear"} <= e.keys()):
            sys.exit(f"{flow}: ExecutedInstructions entries are not "
                     f"{{Offset,Segment,Linear}} dicts — dump shape not understood")
    return entries


def find_code_segment(exe: bytes, executed: list[dict]) -> int:
    """The code segment is where the str_out entry itself executed.

    If str_out never ran, no message could have printed; fail loudly rather than
    return an empty list.
    """
    segs = {e["Segment"] for e in executed if e["Offset"] == STR_OUT_RT}
    if not segs:
        sys.exit("str_out (runtime 0x4FDF) is not in ExecutedInstructions — "
                 "this harvest printed nothing or the address model is wrong; "
                 "refusing to guess")
    if len(segs) > 1:
        sys.exit(f"str_out entry executed in multiple segments {sorted(hex(s) for s in segs)} "
                 f"— unexpected; refusing to guess")
    return segs.pop()


def executed_print_sites(exe: bytes, executed: list[dict], code_seg: int) -> list[dict]:
    """Every executed str_out call site, derived from ExecutedInstructions."""
    sites = []
    for e in executed:
        if e["Segment"] != code_seg:
            continue
        runtime = e["Offset"]
        file_off = runtime + RUNTIME_TO_FILE
        if not is_str_out_call(exe, file_off, runtime):
            continue
        msg = extract(exe, file_off + NEAR_CALL_LEN)
        sites.append({
            "call_runtime": runtime,
            "call_linear": e["Linear"],
            "msg": msg,
        })
    return sites


def discovered_print_sites(exe: bytes, blocks: list[dict], code_seg: int) -> list[dict]:
    """Every str_out call site in the discovered CFG, as a secondary seed only."""
    sites = []
    for blk in blocks:
        seg, addr = split_entry(blk["entry"])
        if seg != code_seg:
            continue
        off = 0
        for item in blk.get("asm") or []:
            parts = item.split("|", 1)
            if len(parts) != 2:
                continue
            hexbytes, text = parts
            runtime = addr + off
            if is_str_out_call(exe, runtime + RUNTIME_TO_FILE, runtime):
                msg = extract(exe, runtime + RUNTIME_TO_FILE + NEAR_CALL_LEN)
                sites.append({
                    "block": blk["entry"],
                    "call_linear": seg * 16 + runtime,
                    "msg": msg,
                })
            off += len(hexbytes) // 2
    return sites


def load_blocks(harvest: pathlib.Path, want_all: bool) -> list[dict]:
    cfg = harvest / "spice86dumpCfgBlocks.json"
    if not cfg.exists():
        if want_all:
            sys.exit(f"no CFG in {harvest} — cannot list discovered sites; "
                     f"the executed set is unaffected")
        return []
    try:
        blocks = json.loads(cfg.read_text())["blocks"]
    except (ValueError, OSError, KeyError) as exc:
        sys.exit(f"cannot parse {cfg}: {exc} — dump shape not understood")
    if not blocks:
        sys.exit(f"{cfg} parsed to zero blocks — dump shape not understood; "
                 f"refusing to report an empty discovered set as fact")
    return blocks


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("harvest", nargs="?")
    ap.add_argument("--exe", default="original/ultimaii.exe")
    ap.add_argument("--contains", default=None,
                    help="only show messages containing this text")
    ap.add_argument("--all", action="store_true",
                    help="also show discovered-but-not-executed print sites")
    ap.add_argument("--selftest", action="store_true",
                    help="run the built-in control and exit")
    args = ap.parse_args()

    if args.selftest:
        return selftest(pathlib.Path(args.exe))

    if not args.harvest:
        ap.error("harvest-dir is required unless --selftest")

    hdir = pathlib.Path(args.harvest)
    exe = pathlib.Path(args.exe).read_bytes()
    executed = load_executed(hdir)
    code_seg = find_code_segment(exe, executed)
    sites = executed_print_sites(exe, executed, code_seg)
    if not sites:
        sys.exit("no executed str_out call sites found in the code segment even "
                 "though str_out ran — address model likely wrong; refusing to "
                 "return an empty list")
    hit = [s for s in sites if s["msg"]]
    n_no_msg = len(sites) - len(hit)

    blocks = load_blocks(hdir, args.all) if args.all else []
    miss = []
    if args.all:
        ran = {s["call_linear"] for s in sites}
        disc = discovered_print_sites(exe, blocks, code_seg)
        seen = set()
        for s in disc:
            if s["msg"] and s["call_linear"] not in ran and s["call_linear"] not in seen:
                seen.add(s["call_linear"])
                miss.append(s)

    if args.contains:
        needle = args.contains.upper()
        hit = [s for s in hit if needle in s["msg"].upper()]
        miss = [s for s in miss if needle in s["msg"].upper()]

    print(f"{len(executed)} executed instructions, code segment "
          f"{code_seg:04X}, {len(sites)} executed str_out sites "
          f"({n_no_msg} had no printable inline message)")
    print(f"\n=== PRINTED ({len(hit)} sites, call instruction confirmed executed)")
    seen = set()
    for s in sorted(hit, key=lambda s: s["call_runtime"]):
        key = s["msg"]
        if key in seen:
            continue
        seen.add(key)
        print(f"  {code_seg:04X}:{s['call_runtime']:04X}  {s['msg']!r}")

    if args.all:
        print(f"\n=== DISCOVERED BUT NEVER EXECUTED ({len(miss)} sites) — "
              f"these did NOT print")
        seen = set()
        for s in miss:
            if s["msg"] in seen:
                continue
            seen.add(s["msg"])
            print(f"  {s['block']}  {s['msg']!r}")
    elif not args.contains:
        print(f"\n(pass --all to also list discovered-but-never-executed print sites)")
    return 0


def selftest(exe_path: pathlib.Path) -> int:
    """Positive/negative control per AGENTS.md § 5.

    A message known to be executed must be reported present; a message known to
    be unexecuted must be reported absent. `dungeon-35-live` is the positive
    capture (the plane-landing refuse fired); `create-test-live` is a clean
    negative control (character creation only, no combat strings at all).
    """
    root = pathlib.Path(__file__).resolve().parent.parent
    exe_file = root / exe_path if not exe_path.is_absolute() else exe_path
    if not exe_file.exists():
        print(f"SKIP selftest: {exe_file} absent (game content is gitignored)")
        return 0
    exe = exe_file.read_bytes()

    pos = root / "captures/spice86/dungeon-35-live"
    neg = root / "captures/spice86/create-test-live"
    for d in (pos, neg):
        if not (d / "spice86dumpExecutionFlow.json").exists():
            print(f"SKIP selftest: {d} absent (captures are gitignored)")
            return 0

    failures = []

    def printed_msgs(harvest: pathlib.Path) -> str:
        executed = load_executed(harvest)
        cs = find_code_segment(exe, executed)
        sites = executed_print_sites(exe, executed, cs)
        return " | ".join(s["msg"] for s in sites if s["msg"])

    pos_msgs = printed_msgs(pos)
    neg_msgs = printed_msgs(neg)

    # Positive: the site that the old tool silently dropped.
    if "LAND--NOT HERE!!!!!" not in pos_msgs:
        failures.append("dungeon-35-live: LAND--NOT HERE!!!!! must be PRESENT")
    # Negative: Minax was never met in this session.
    if "MINAX CRIES: DIE FOOL!" in pos_msgs:
        failures.append("dungeon-35-live: MINAX CRIES: DIE FOOL! must be ABSENT")
    # Clean negative control: a creation-only session prints no combat strings.
    for needle in ("ATTACK", "MISS", "HIT", "KILLED", "PARALYZ", "MINAX", "STOLE"):
        if needle in neg_msgs.upper():
            failures.append(f"create-test-live: {needle!r} must be ABSENT "
                            f"(no combat in a creation-only session)")

    if failures:
        print("SELFTEST FAILED:")
        for f in failures:
            print("  -", f)
        return 1
    print("SELFTEST PASSED: LAND--NOT HERE!!!!! present in dungeon-35-live; "
          "MINAX CRIES and all combat strings absent (dungeon-35 + create-test controls)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
