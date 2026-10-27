#!/usr/bin/env python3
"""Record a scripted session from the ORIGINAL Ultima II under Spice86, one turn at a time.

This is phase 1 of docs/plan-cross-game-replay.md: the recording that a later phase feeds to our engine
so the two DS mirrors can be diffed turn by turn. It drives the emulator through the existing
spice86_type reader and injector rather than reimplementing either (AGENTS: look first, do not
duplicate a tool).

Two design decisions, both earned the hard way in phase 0:

1. PACING IS IN EMULATED TICKS, NEVER REAL SECONDS. The game advances on the BIOS timer at 18.2 Hz.
   A fixed real-time sleep spans a slightly different number of ticks on each run, and with hostiles
   adjacent to the player one tick of jitter is one extra steal-and-hit, which cascades. Phase 0
   measured four boots under real-second pacing and got runs that diverged at turn 0; re-paced on tick
   counts, two fresh boots reproduced a 37-turn combat session field for field, full RNG trace
   included. A recorder that sleeps in seconds reproduces that fake nondeterminism and blames the
   game. See docs/plan-cross-game-replay.md sections 6b and 6c.

2. A KEY IS ONLY A TURN IF THE GAME CONSUMED IT. The BIOS keyboard ring is checked after every
   injection: the tail advancing means the key was delivered, and head catching up to tail means the
   game read it. A dropped key otherwise looks exactly like a turn where nothing happened, which is
   the failure mode this project has been bitten by repeatedly. Each record carries its own verdict.

DS:74 (the startup speed calibration) is recorded but flagged excluded: it is a busy-loop measurement
of emulator throughput, not gameplay state, and it differs on every boot. Diffing it produces a false
divergence on every single turn.

Usage:
    python3 tools/u2_record.py --script keys.txt --out /var/tmp/u2/rec.json
    python3 tools/u2_record.py --script keys.txt --out rec.json --frames /var/tmp/u2/frames
    python3 tools/u2_record.py --help

The script file is one key token per line, '#' starts a comment, blank lines skip. Tokens are the
spice86_type vocabulary: single letters and digits, or escape/enter/space/up/down/left/right.
"""
import argparse
import hashlib
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spice86_type as st  # noqa: E402

# The compared field set. Offsets are DS-relative and are the same addresses engine/src/core/state.h
# mirrors, which is the whole reason a diff here is a field-by-field memory comparison rather than a
# heuristic. Grades: every offset here is proven in state.h or docs/spice86-capture.md.
FIELDS = [
    ("pos",        0x00,  2, "player x,y - the original's own mirror"),
    ("speed",      0x74,  2, "EXCLUDED: startup busy-loop calibration, varies every boot"),
    ("sector",     0x49,  2, "two DECIMAL digits, not an integer"),
    ("hp",         0x51,  2, "BCD pair"),
    ("food",       0x53,  3, "3-byte BCD, hundreds first"),
    ("exp",        0x56,  2, "BCD"),
    ("gold",       0x58,  2, "BCD"),
    ("items",      0xD6, 16, "16 held-item slots"),
    ("mon_x",      0x137, 32, "creature x, 32 slots"),
    ("mon_y",      0x157, 32, "creature y"),
    ("mon_hp",     0x177, 32, "creature hp"),
    ("mon_type",   0x197, 32, "creature art/type byte"),
    ("mon_kind",   0x1B7, 32, "creature kind byte"),
    ("mon_role",   0x1D7, 32, "behaviour role: 1 hostile, 2 alerted, 3 wander"),
    ("wander_x",   0x1F7, 32, "role-3 step vector x (runtime state, ships zero)"),
    ("wander_y",   0x217, 32, "role-3 step vector y"),
    ("rng",        0x23F,  6, "the 6-byte feedback shift register"),
    ("paralysis",  0x26A,  4, "legs / arms / sleep / fourth"),
]

# Fields a cross-game diff must ignore, with the reason. Kept next to FIELDS so the two cannot drift.
EXCLUDED = {
    "speed": "DS:74 is the startup speed calibration measured from emulator throughput "
             "(asm/06AC); it feeds animation delays and key-wait timeouts, not game logic, "
             "and it differs on every boot. See docs/plan-cross-game-replay.md section 6a.",
}

TICK_ADDR = (0x0040, 0x6C)   # BIOS free-running timer, low dword


def wait_ready(http, timeout_s=120.0):
    """Block until the emulator answers memory reads.

    up.sh returns before Spice86's HTTP port is listening, and a recorder that starts too early gets a
    connection reset that looks like a game crash. Fail with a sentence, not a traceback.
    """
    t0 = time.time()
    while time.time() - t0 < timeout_s:
        try:
            st.status(http)
            bios_ticks(http)
            return True
        except Exception:
            time.sleep(1.0)
    return False


def bios_ticks(http):
    b = st.read_mem(*TICK_ADDR, 4, http)
    return b[0] | (b[1] << 8) | (b[2] << 16) | (b[3] << 24)


def wait_ticks(n, http, deadline_s=15.0):
    """Block until n BIOS ticks have passed. Emulated time, not wall time - see module docstring."""
    return wait_until_tick(bios_ticks(http) + n, http, deadline_s)


def wait_until_tick(target, http, deadline_s=15.0):
    """Block until the BIOS timer reaches an absolute tick count.

    Absolute, not relative, because the key-consumption poll below also burns emulated time, and its
    duration varies with how long the game takes to read the key. A relative wait added on top of that
    makes the spacing between keys variable in ticks, which is exactly the jitter phase 0 exists to
    remove: an early version of this recorder did `poll until consumed, then wait 18 ticks` and two
    boots diverged in player position. Anchoring to a tick count fixed at send time puts the polling
    inside the budget instead of after it.
    """
    t0 = time.time()
    while bios_ticks(http) < target:
        if time.time() - t0 > deadline_s:
            return False
        time.sleep(0.01)
    return True


def snapshot(http):
    out = {name: st.read_mem(st.DS, off, n, http).hex(" ") for name, off, n, _ in FIELDS}
    # The whole DS range as well, so a replay resumes from an exact checkpoint instead of
    # rebuilding one from the named fields. The save file carries only DS:36..135; the creature
    # arrays, wander vectors, RNG register and status counters all live outside it, so a replay
    # that resumes from the save alone starts from a different world — and every dynamic field
    # then diverges from turn 0 for a reason that has nothing to do with game behaviour.
    out["ds_block"] = st.read_mem(st.DS, 0x0000, 0x280, http).hex(" ")
    return out


def read_script(path):
    keys = []
    with open(path) as f:
        for lineno, raw in enumerate(f, 1):
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            try:
                keys.append((lineno, st.letter(line)))
            except SystemExit as e:
                raise SystemExit(f"{path}:{lineno}: {e}")
    return keys


def file_sha(path):
    if not path or not os.path.exists(path):
        return None
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0],
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--script", required=True, help="key tokens, one per line")
    ap.add_argument("--out", required=True, help="where to write the recording")
    ap.add_argument("--ticks", type=int, default=18,
                    help="BIOS ticks to wait after each key (default 18 = ~1s of emulated time)")
    ap.add_argument("--http-port", type=int, default=st.HTTP)
    ap.add_argument("--mcp-port", type=int, default=st.MCP)
    ap.add_argument("--player", help="player save used, recorded in metadata for reproducibility")
    ap.add_argument("--label", default="", help="free text recorded in metadata")
    ap.add_argument("--frames", help="also write a PNG per turn into this directory (game content: "
                                     "keep it out of git)")
    ap.add_argument("--settle-ticks", type=int, default=36,
                    help="ticks to wait before the first key, so the title screen has settled")
    a = ap.parse_args()

    keys = read_script(a.script)
    if not keys:
        raise SystemExit(f"{a.script}: no key tokens found")

    mcp = st.Mcp(a.mcp_port)
    turns = []
    undelivered = 0

    if not wait_ready(a.http_port):
        raise SystemExit(f"emulator not answering on port {a.http_port} after 120s; "
                         f"is the run up? (deploy/spice86-novnc/up.sh)")
    if not wait_ticks(a.settle_ticks, a.http_port):
        raise SystemExit("emulator is not advancing; is the run alive?")

    for idx, (lineno, key) in enumerate(keys):
        head0, tail0, _ = st.keyboard_state(a.http_port)
        # Anchor the pacing budget BEFORE injecting: everything after this point, including the
        # consumption poll, has to fit inside a.ticks of emulated time.
        tick_at_send = bios_ticks(a.http_port)
        st.send_key(mcp, key)

        # Delivered: the ring tail moved. Consumed: the head caught up, i.e. the game read it.
        delivered = consumed = False
        t0 = time.time()
        while time.time() - t0 < 5.0:
            head, tail, _ = st.keyboard_state(a.http_port)
            delivered = delivered or tail != tail0
            consumed = delivered and head == tail
            if consumed:
                break
            time.sleep(0.02)
        if not consumed:
            undelivered += 1

        wait_until_tick(tick_at_send + a.ticks, a.http_port)
        rec = {"turn": idx, "key": key, "script_line": lineno,
               "delivered": delivered, "consumed": consumed,
               "ds": snapshot(a.http_port)}
        if a.frames:
            os.makedirs(a.frames, exist_ok=True)
            fp = os.path.join(a.frames, f"turn-{idx:05d}.png")
            try:
                import subprocess
                subprocess.run([sys.executable,
                                os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                             "spice86_screenshot.py"), fp,
                                "--mcp-port", str(a.mcp_port)],
                               check=False, timeout=30)
                rec["frame"] = fp
            except Exception as e:            # a missing frame must not lose the state record
                rec["frame_error"] = str(e)
        turns.append(rec)

    out = {
        "recorder": "u2_record.py",
        "format_version": 1,
        "target": "original ultimaii.exe under Spice86",
        "label": a.label,
        "player_sha256": file_sha(a.player),
        "pacing": {"unit": "bios_ticks", "ticks_per_key": a.ticks,
                   "note": "emulated time, not wall time; see module docstring"},
        "fields": {name: {"ds_offset": f"0x{off:03X}", "bytes": n, "what": what}
                   for name, off, n, what in FIELDS},
        "excluded_fields": EXCLUDED,
        "http_port": a.http_port, "mcp_port": a.mcp_port,
        "keys": len(keys), "turns": len(turns), "keys_not_consumed": undelivered,
        "turns_data": turns,
    }
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    with open(a.out, "w") as f:
        json.dump(out, f, indent=1)

    print(f"recorded {len(turns)} turns -> {a.out}")
    if undelivered:
        print(f"WARNING: {undelivered} key(s) were not consumed by the game; "
              f"those turns are not comparable")
        for t in turns:
            if not t["consumed"]:
                print(f"  turn {t['turn']} key {t['key']} (script line {t['script_line']})")
    print(f"final rng: {turns[-1]['ds']['rng']}  pos: {turns[-1]['ds']['pos']}  "
          f"sector: {turns[-1]['ds']['sector']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
