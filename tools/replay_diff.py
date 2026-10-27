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
        dumps, rc = run_engine(a, keys, rng_state, work)
        print(f"engine produced {len(dumps)} turn dumps (exit {rc})")

        # A comparison over nothing is not a pass. This printed CLEAN once with zero dumps, which is the
        # exact shape of gate this project has been burned by repeatedly: a checker that cannot fail
        # reports success.
        if not dumps:
            print("\nREPLAY DIFF: INCONCLUSIVE — the engine produced no turn dumps")
            return 2

        # --- align by RNG register ---------------------------------------------------------------
        # The register advances monotonically with rolls, so it is a clock both sides expose. Multiple
        # original samples can share a register (keys that trigger no roll); the first is used and the
        # ambiguity is counted rather than hidden.
        index = {}
        for i, t in enumerate(turns):
            if i < a.align_turn:
                continue
            index.setdefault(t["ds"]["rng"], []).append(i)

        pairs, unaligned, ambiguous = [], [], 0
        for j, d in enumerate(dumps):
            try:
                reg = d["state"]["raw"]["rng"]
            except KeyError:
                print("REPLAY DIFF: INCONCLUSIVE — engine dump has no state.raw; rebuild the engine")
                return 2
            hits = index.get(reg)
            if not hits:
                unaligned.append(j)
                continue
            if len(hits) > 1:
                ambiguous += 1
            pairs.append((j, hits[0]))

        print(f"aligned {len(pairs)} engine turns to original samples; "
              f"{len(unaligned)} unaligned; {ambiguous} registers matched more than one sample")
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
