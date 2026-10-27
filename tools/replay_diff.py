#!/usr/bin/env python3
"""replay_diff.py — replay a recorded ORIGINAL session on our engine and diff the two DS mirrors.

This is the payoff docs/plan-cross-game-replay.md exists for. The engine's state block is a byte-for-byte
mirror of the original's DS working segment, so the comparison is a byte diff with labels rather than a
heuristic between two models. The first turn where they disagree is an engine bug with a reproduction
attached.

How it works:
  1. read a recording made by tools/u2_record.py (key + raw DS snapshot per key),
  2. map the original's key tokens onto the engine's script vocabulary,
  3. resume the engine from the original's RNG register at the alignment point,
  4. run the engine headless with per-turn dumps,
  5. ALIGN BY RNG REGISTER, and diff raw bytes against raw bytes.

Two design decisions that replaced two failed approaches:

ALIGNMENT IS BY RNG REGISTER, NOT BY INDEX. The recording samples once per key; the engine dumps once
per turn, and a turn swallows several keys (attack + aim is two keys, one turn). Index-to-index
therefore compares different moments, and the first version of this tool reported 19 divergences from
two sessions that were actually identical — the giveaway was the RNG register disagreeing at turns 0-2
and then matching exactly at turn 3, which is the signature of an offset, not of a different engine.
The RNG register is a strictly advancing function of rolls executed, so it is a clock both sides expose
natively, and it is the honest join key. An engine turn whose register appears in no original sample is
reported as UNALIGNED rather than compared against a guess.

COMPARISON IS RAW BYTES, NOT DECODED VALUES. The engine's decoded fields are pleasant for a human and
useless as a comparison basis: u2_bcd16() takes (lo, hi) while the display prints hundreds-first, and
food is a 3-byte BCD that a 16-bit decoder truncates. Every such convention is a place where two correct
sides look different. The engine therefore emits state.raw — the same DS bytes, the same field names and
the same formatting as the recorder — and this tool compares strings. No interpretation on the path.

Content policy: offsets, counts and digests only. Game text is never copied out of either side.

Usage:
    python3 tools/replay_diff.py --recording /var/tmp/u2/rec/M1.json \
        --align-turn 7 --save-dir /var/tmp/s03 --data-dir original
"""
import argparse
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile

# Original key token -> engine script token. The engine's arrows are ch values 0xF0..0xF3
# (platform.h U2_KEY_*), which its script format reaches as 0xNN. An unmapped token is a hard error:
# a silently-dropped key makes the replay diverge for a boring reason that reads like a deep bug.
KEY_MAP = {
    "Up": "0xF0", "Down": "0xF1", "Left": "0xF2", "Right": "0xF3",
    "Escape": "ESC", "Return": "CR", "Enter": "CR", "Space": "SP",
}

# Compared raw fields, in the order they are reported. Both sides emit these as space-separated
# lowercase hex of the same DS bytes, so equality is string equality.
RAW_FIELDS = [
    "pos", "sector", "hp", "food", "exp", "gold", "items",
    "mon_x", "mon_y", "mon_hp", "mon_type", "mon_kind", "mon_role",
    "wander_x", "wander_y", "rng", "paralysis",
]


# DS offset of each recorded field, so a checkpoint file can be rebuilt from a recording.
# These are the same offsets the recorder reads, and state.h mirrors them byte for byte.
DS_OFFSETS = {
    "pos": 0x00, "sector": 0x49, "hp": 0x51, "food": 0x53, "exp": 0x56, "gold": 0x58,
    "items": 0xD6, "mon_x": 0x137, "mon_y": 0x157, "mon_hp": 0x177, "mon_type": 0x197,
    "mon_kind": 0x1B7, "mon_role": 0x1D7, "wander_x": 0x1F7, "wander_y": 0x217,
    "rng": 0x23F, "paralysis": 0x26A,
}
DS_BLOCK_LEN = 0x280


def build_checkpoint(turns, align, path):
    """Rebuild a DS block from the recording, taken at the sample BEFORE the first compared turn.

    This is what makes the comparison mean anything. The save file carries only DS:36..135, and the
    original ran several menu commands before the compared window — during which creatures moved,
    the player's state changed and the RNG advanced. Resuming only the RNG register left the engine
    starting from a different world, and the very first diff proved it: every static loaded field
    matched while every dynamic one differed from turn 0. That was a starting-state mismatch wearing
    a behavioural divergence's clothes.

    Fields the recording does not carry stay zero, which is why the block is bounded at 0x280 and
    why a recorder that dumps the whole DS range is the better long-term answer.
    """
    ds = turns[align - 1]["ds"] if align > 0 else turns[0]["ds"]
    blk = bytearray(DS_BLOCK_LEN)
    for name, off in DS_OFFSETS.items():
        if name not in ds:
            continue
        raw = bytes.fromhex(ds[name].replace(" ", ""))
        blk[off:off + len(raw)] = raw
    with open(path, "w") as f:
        f.write(" ".join(f"{b:02x}" for b in blk))
    return ds


def bcd(s):
    """Packed-decimal bytes to an int. Each byte's two nibbles ARE decimal digits,
    so 0x99 0x63 0x67 is 996367. Formatting the byte as decimal instead of hex is the
    classic mistake here and yields impossible numbers with more digits than the field has."""
    return int("".join(f"{int(x, 16):02x}" for x in s.split()))


# The food a completed command costs, from asm/2599 (move, 19) and asm/0B0D (pass, 10).
# A refused step pays the 19 as well - proven, and re-proven by the M1 recording, where all
# 19 movement keys cost exactly 19 whether the player moved or not.
TURN_COSTS = {19, 10}


def odometer_ok(turns, align, n):
    """Prove the original's samples are one-per-command before aligning them by index.

    Index alignment is only honest if each original sample is a completed command. The food
    odometer is the evidence: every accepted move, refused step and auto-PASS costs a known
    amount, so a window where every consecutive delta is 19 or 10 has no extra turns hiding in
    it and no missing ones. Anything else (a delta of 0, or an unexplained amount) means a
    command landed between samples or a sample was torn, and index alignment would then compare
    different moments - which is the exact error this whole file exists to avoid.
    """
    bad = []
    for i in range(align, align + n):
        if i >= len(turns) or i == 0:
            continue
        d = bcd(turns[i - 1]["ds"]["food"]) - bcd(turns[i]["ds"]["food"])
        if d not in TURN_COSTS:
            bad.append((i, d))
    return bad


def fsr_step(s):
    """One rand_byte() advance of the 6-byte register, as asm/5217/522B/5236 do it.

    The shift loop runs bx = 4..0 writing s[1+bx] = s[bx], so s[1] = s[0] happens AFTER s[0] takes
    the new value — which is why every observed register has its first two bytes equal. Getting that
    order wrong yields a model that rolls plausible numbers and matches nothing. This one reproduces
    CP0's committed vector (seed 0 -> 2,3,4,6,10,16,24,35,52,79,120,180,12,144) byte for byte, which
    is what makes it arithmetic rather than a guess.
    """
    al = s[1]
    t = al + s[4] + 1
    al = t & 0xFF
    cf = (t >> 8) & 1
    t = al + s[5] + cf
    al = t & 0xFF
    return [al, al, s[1], s[2], s[3], s[4]]


def rolls_between(a, b, cap=4000):
    """How many rolls take register a to register b, or None if not reachable within cap.

    The register is a pure forward function of itself but NOT invertible — the shift discards the old
    high byte — so the count is found by stepping forward. Cheap: a few thousand steps is nothing.
    """
    s = a
    for k in range(1, cap + 1):
        s = fsr_step(s)
        if s == b:
            return k
    return None


def hexreg(s):
    return [int(x, 16) for x in s.split()]


def map_keys(turns, align):
    out = []
    for t in turns[align:]:
        k = t["key"]
        if k in KEY_MAP:
            out.append(KEY_MAP[k])
        elif len(k) == 1:
            out.append(k)
        else:
            raise SystemExit(f"no engine mapping for original key {k!r} (turn {t['turn']}); "
                             f"add it to KEY_MAP rather than dropping it")
    return out


def run_engine(args, keys, rng_state, work):
    eng_dir = os.path.join(work, "engine-turns")
    os.makedirs(eng_dir, exist_ok=True)
    # The engine rewrites the save in place, so every run starts from a fresh copy or state compounds
    # across runs and reads as a trend.
    shutil.copyfile(os.path.join(args.save_dir, "PLAYER"), os.path.join(work, "PLAYER"))
    script = os.path.join(work, "keys.engine")
    with open(script, "w") as f:
        f.write("\n".join(keys) + "\n")
    cmd = [args.engine, "--headless", "--play-map",
           "--data-dir", args.data_dir, "--save-dir", work,
           "--debug", "cli", "--debug-path", eng_dir, "--debug-limit", "0",
           "--script", script]
    if args.checkpoint:
        cmd += ["--load-ds", os.path.join(work, "checkpoint.hex")]
    if rng_state:
        cmd += ["--rng-state", rng_state]
    if args.seed is not None:
        cmd += ["--seed", str(args.seed)]
    print("  engine: " + " ".join(cmd))
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"  engine exited {r.returncode}\n{r.stdout[-1200:]}\n{r.stderr[-1200:]}")
    # The engine writes into a timestamped subdirectory of --debug-path. Glob, and take the newest so a
    # reused work dir cannot pick up a stale run.
    found = sorted(glob.glob(os.path.join(eng_dir, "**", "turn-*.json"), recursive=True))
    if not found:
        return [], r.returncode
    newest = os.path.dirname(found[-1])
    return [json.load(open(p)) for p in sorted(glob.glob(os.path.join(newest, "turn-*.json")))], r.returncode


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0],
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--recording", required=True, help="a tools/u2_record.py recording")
    ap.add_argument("--align-turn", type=int, default=0,
                    help="original sample index that corresponds to the engine's start (skip its menu keys)")
    ap.add_argument("--save-dir", required=True, help="dir holding the PLAYER the original loaded")
    ap.add_argument("--data-dir", default="original", help="mapx/monx/tlkx directory")
    ap.add_argument("--engine", default="engine/u2")
    ap.add_argument("--seed", default=None, help="passed through to the engine")
    ap.add_argument("--no-rng-resume", action="store_true",
                    help="do not load the original's register (shows what the resume is buying)")
    ap.add_argument("--checkpoint", action="store_true",
                    help="resume the engine from a full DS block rebuilt from the recording, not "
                         "just the RNG register. Without it the two sides start from different "
                         "worlds and every dynamic field diverges from turn 0 for a reason that "
                         "has nothing to do with game behaviour.")
    ap.add_argument("--force-register", action="store_true",
                    help="align on RNG register even when the food odometer proves index alignment valid")
    ap.add_argument("--max-report", type=int, default=5, help="divergences to print per field")
    a = ap.parse_args()

    rec = json.load(open(a.recording))
    turns = rec["turns_data"]
    if a.align_turn >= len(turns):
        raise SystemExit(f"--align-turn {a.align_turn} is past the end of a {len(turns)}-turn recording")

    keys = map_keys(turns, a.align_turn)
    rng_state = None
    if not a.no_rng_resume and a.align_turn > 0:
        rng_state = turns[a.align_turn - 1]["ds"]["rng"].replace(" ", "")
    print(f"recording: {len(turns)} samples, aligning at {a.align_turn} -> {len(keys)} engine keys")
    print(f"rng resumed from: {rng_state or '(NOT resumed - seed only)'}")

    work = tempfile.mkdtemp(prefix="u2-diff-", dir="/var/tmp")
    try:
        if a.checkpoint and a.align_turn > 0:
            pre = build_checkpoint(turns, a.align_turn, os.path.join(work, "checkpoint.hex"))
            print(f"checkpoint: DS block from sample {a.align_turn - 1} "
                  f"(pos={pre['pos']} rng={pre['rng']})")
        dumps, rc = run_engine(a, keys, rng_state, work)
        print(f"engine produced {len(dumps)} turn dumps (exit {rc})")

        # A comparison over nothing is not a pass. This printed CLEAN once with zero dumps, which is the
        # exact shape of gate this project has been burned by repeatedly: a checker that cannot fail
        # reports success.
        if not dumps:
            print("\nREPLAY DIFF: INCONCLUSIVE — the engine produced no turn dumps")
            return 2

        # --- alignment --------------------------------------------------------------------------
        # Two candidate axes, and the honest one depends on the script.
        #
        # INDEX (engine turn j == original sample align+j) is exact IF each original sample is one
        # completed command. The food odometer proves that: every accepted move, refused step and
        # auto-PASS costs a known 19 or 10, so a window where every delta is one of those has no
        # command hiding between samples. When it holds, index alignment is the right axis and the
        # divergences it reports are behavioural.
        #
        # REGISTER (join on the RNG value) was the only axis before, and it is now known to be the
        # wrong one for a general script: the original's idle auto-PASSes consume rolls the engine
        # never makes, so the two roll streams drift apart permanently and only coincidental matches
        # survive. It stays as a fallback and as a cross-check, because how often the registers agree
        # is itself a measurement of roll-consumption fidelity.
        n = min(len(dumps), len(turns) - a.align_turn)
        if n <= 0:
            print("\nREPLAY DIFF: INCONCLUSIVE — nothing to compare")
            return 2

        reg_index = {}
        for i, t in enumerate(turns):
            if i >= a.align_turn:
                reg_index.setdefault(t["ds"]["rng"], []).append(i)
        reg_hits = sum(1 for d in dumps[:n]
                       if d["state"]["raw"]["rng"] in reg_index)

        bad = odometer_ok(turns, a.align_turn, n)
        if a.force_register:
            use_index = False
        else:
            use_index = not bad
        print(f"food odometer over the compared window: "
              f"{'clean, every delta 19 or 10' if not bad else f'{len(bad)} sample(s) not on a command boundary'}")
        print(f"RNG registers agree on {reg_hits}/{n} turns "
              f"(a roll-consumption fidelity measure, not the alignment)")

        if use_index:
            pairs = [(j, a.align_turn + j) for j in range(n)]
            unaligned = []
            print(f"alignment: INDEX — engine turn j vs original sample {a.align_turn}+j, "
                  f"{n} pairs")
        else:
            pairs, unaligned = [], []
            for j, d in enumerate(dumps[:n]):
                hits = reg_index.get(d["state"]["raw"]["rng"])
                if hits:
                    pairs.append((j, hits[0]))
                else:
                    unaligned.append(j)
            print(f"alignment: REGISTER fallback — {len(pairs)} matched, {len(unaligned)} unaligned")
            print("  index alignment was refused because the odometer shows commands between samples;")
            print("  a movement-only script is the way to get an exact index comparison.")

        print(f"aligned {len(pairs)} engine turns to original samples")
        if not pairs:
            print("\nREPLAY DIFF: INCONCLUSIVE — no engine turn shares an RNG register with any "
                  "original sample")
            print("  Either the two sessions are not the same session, or the engine is not consuming")
            print("  the same rolls. Not reported as a match.")
            return 2

        print()
        print(f"{'field':<12} {'aligned':>8} {'differing':>10}  verdict")
        total = 0
        detail = []
        for f in RAW_FIELDS:
            if f == "rng":
                # rng is the join key, so equality here is true by construction and proves nothing.
                # It is listed for completeness and marked, because an unmarked MATCH on the field that
                # everyone most wants to see is its own small lie.
                print(f"{'rng':<12} {len(pairs):>8} {'-':>10}  JOIN KEY (equal by construction)")
                continue
            diffs = []
            for j, i in pairs:
                o = turns[i]["ds"].get(f)
                e = dumps[j]["state"]["raw"].get(f)
                if o is None or e is None:
                    continue
                if o != e:
                    diffs.append((j, i, o, e))
            total += len(diffs)
            verdict = "MATCH" if not diffs else f"first at engine turn {diffs[0][0]}"
            print(f"{f:<12} {len(pairs):>8} {len(diffs):>10}  {verdict}")
            detail.extend(diffs[:a.max_report])
        for j, i, o, e in detail[:a.max_report * 4]:
            print(f"    engine turn {j} (original sample {i}):")
            print(f"      original {o[:60]}")
            print(f"      engine   {e[:60]}")

        print()
        # --- rolls per command -----------------------------------------------------------------
        # "Which fields differ" is downstream; "which command first consumed a different number of
        # rolls" is usually the cause. Once the two sides sit at different points in the stream,
        # every wander vector, creature position and contact test after that inherits the offset,
        # so chasing a late divergence before fixing the first one wastes the afternoon.
        print("rolls per command (original derived by forward simulation; engine from its counter)")
        print(f"{'turn':>4} {'key':<7} {'orig':>6} {'eng':>6} {'diff':>6}  note")
        first_split = None
        for j in range(n):
            i = a.align_turn + j
            try:
                o_rolls = rolls_between(hexreg(turns[i - 1]["ds"]["rng"]),
                                        hexreg(turns[i]["ds"]["rng"]))
            except (KeyError, IndexError):
                o_rolls = None
            e_rolls = dumps[j]["state"]["rng"]["rolls"] - (
                dumps[j - 1]["state"]["rng"]["rolls"] if j else 0)
            d = None if o_rolls is None else o_rolls - e_rolls
            note = ""
            if d not in (0, None) and first_split is None:
                first_split = j
                note = "<-- FIRST SPLIT"
            if o_rolls is None:
                note = "original register unreachable (torn read or over cap)"
            if j < a.max_report or first_split == j:
                print(f"{j:>4} {turns[i]['key']:<7} {str(o_rolls):>6} {e_rolls:>6} "
                      f"{str(d):>6}  {note}")
        if first_split is None:
            print("  no split: the engine consumed the same number of rolls on every compared turn")
        else:
            print(f"  first split at engine turn {first_split} "
                  f"(key {turns[a.align_turn + first_split]['key']}, "
                  f"original sample {a.align_turn + first_split})")
            print("  fix that before chasing any later divergence; the rest inherit it.")

        print()
        if unaligned:
            print(f"NOTE: {len(unaligned)} engine turns had no original sample at the same RNG "
                  f"register (turns {unaligned[:8]}). Those are not counted as matches.")
        verdict = "CLEAN" if total == 0 else f"{total} differing field-turns"
        print(f"REPLAY DIFF: {verdict}")
        return 0 if total == 0 else 1
    finally:
        if os.environ.get("U2_DIFF_KEEP"):
            print(f"(work dir kept: {work})")
        else:
            shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
