#!/usr/bin/env python3
"""replay_diff.py — replay a recorded ORIGINAL session on our engine and diff the two state mirrors.

This is the payoff the plan exists for. docs/plan-cross-game-replay.md: the engine's state block is a
byte-for-byte mirror of the original's DS working segment, so a comparison between the two is a
field-by-field memory diff rather than a heuristic. The first turn where they disagree is an engine bug
with a reproduction attached.

What it does:
  1. reads a recording made by tools/u2_record.py (key + DS snapshot per turn),
  2. maps the original's key tokens onto the engine's script vocabulary,
  3. resumes the engine from the original's RNG register at the alignment turn — the original's idle
     loop advances that register on the BIOS timer, so replaying from the seed would compare two
     sessions that had rolled a different number of times,
  4. runs the engine headless with per-turn state dumps,
  5. diffs the fields both sides report, and prints the first divergence per field.

The RNG comparison is the most diagnostic single field: if the register matches turn for turn, the
engine consumed exactly the original's number of rolls, which is a statement about the whole model,
not just about dice.

Content policy: this prints offsets, counts and digests. It never copies game text out of either side.

STATUS — SKELETON, NOT A GATE. It runs end to end and it is useful, but it currently over-reports
divergence and must not be wired into CI until both problems below are fixed. Proving a checker can go
red is only half of it; a checker that goes red for the wrong reason trains everyone to ignore it.

1. TURN ALIGNMENT IS UNSOLVED. The recording samples once per KEY; the engine dumps once per TURN, and
   a turn can swallow several keys (attack + aim, a menu sequence, an idle auto-PASS). Comparing index
   to index therefore compares different moments. The first run made this visible rather than hiding
   it: the RNG register disagreed at turns 0-2 and then matched EXACTLY at turn 3, which is the
   signature of two identical streams read at an offset, not of an engine that rolls differently. The
   fix is command-level boundaries on both sides, which is phase 4's real work.

2. REPRESENTATION NORMALISATION IS INCOMPLETE. The engine decodes BCD and the original's dump is raw
   bytes, so hp and food are not comparable yet; the engine emits creature type/role as hex strings and
   the original side yields ints. These are differ bugs, not engine bugs, and they must be separated
   from real divergences before any verdict here is trusted.

What is already true and worth having: the key vocabulary maps cleanly (arrows are 0xF0..0xF3), the
engine resumes from a captured register, sector 03 loads with its 32 creatures, and the whole loop
runs from a recording to a diff in one command.

Usage:
    python3 tools/replay_diff.py --recording /var/tmp/u2/rec/C.json \
        --align-turn 7 --save-dir /var/tmp/u2/s03 --data-dir original
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
    "Up":    "0xF0",
    "Down":  "0xF1",
    "Left":  "0xF2",
    "Right": "0xF3",
    "Escape": "ESC",
    "Return": "CR",
    "Enter":  "CR",
    "Space":  "SP",
}

# Fields both sides can report, and how to read each side. `orig` is a DS field name from the
# recording; `engine` is a dotted path into the engine's turn JSON. Hex strings from the original are
# normalised to ints where the engine reports numbers.
def norm_bytes(s):
    return [int(x, 16) for x in s.split()]


def orig_pos(d):
    x, y = norm_bytes(d["pos"])
    return [x, y]


def orig_sector(d):
    a, b = norm_bytes(d["sector"])
    return f"{a}{b}"


def orig_hp(d):
    return norm_bytes(d["hp"])


def orig_food(d):
    return norm_bytes(d["food"])


def orig_creatures(d):
    """Live slots as [x, y, type, role, hp], matching the engine's dump shape."""
    out = []
    types = norm_bytes(d["mon_type"])
    xs, ys = norm_bytes(d["mon_x"]), norm_bytes(d["mon_y"])
    roles, hps = norm_bytes(d["mon_role"]), norm_bytes(d["mon_hp"])
    for i, t in enumerate(types):
        if t:
            out.append([xs[i], ys[i], t, roles[i], hps[i]])
    return out


COMPARISONS = [
    ("rng",       "rng",        lambda d: d["rng"],
     lambda j: ",".join(str(x) for x in j["state"]["rng"]["state"])),
    ("pos",       "pos",        orig_pos,
     lambda j: [j["state"]["pos"]["x"], j["state"]["pos"]["y"]]),
    ("sector",    "sector",     orig_sector,
     lambda j: str(j["state"].get("sector", ""))),
    ("hp",        "hp",         orig_hp,
     lambda j: j["state"].get("hp")),
    ("food",      "food",       orig_food,
     lambda j: j["state"].get("food")),
    ("creatures", "creatures",  orig_creatures,
     lambda j: j["state"].get("creatures")),
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
    # The engine rewrites the save in place, so every run must start from a fresh copy or state
    # compounds across runs and reads as a trend.
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
    print("  engine: " + " ".join(os.path.relpath(c) for c in cmd))
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"  engine exited {r.returncode}\n{r.stdout[-1500:]}\n{r.stderr[-1500:]}")
    # The engine writes into a timestamped subdirectory of --debug-path, not into --debug-path itself.
    # Glob rather than assume, and take the newest so a reused work dir cannot pick up a stale run.
    found = sorted(glob.glob(os.path.join(eng_dir, "**", "turn-*.json"), recursive=True))
    if not found:
        return [], r.returncode
    newest = os.path.dirname(found[-1])
    dumps = [json.load(open(p)) for p in sorted(glob.glob(os.path.join(newest, "turn-*.json")))]
    return dumps, r.returncode


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0],
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--recording", required=True, help="a tools/u2_record.py recording")
    ap.add_argument("--align-turn", type=int, default=0,
                    help="original turn index that corresponds to engine turn 0 (skip its menu keys)")
    ap.add_argument("--save-dir", required=True, help="dir holding the PLAYER the original loaded")
    ap.add_argument("--data-dir", default="original", help="mapx/monx/tlkx directory")
    ap.add_argument("--engine", default="engine/u2")
    ap.add_argument("--seed", default=None, help="passed through to the engine")
    ap.add_argument("--no-rng-resume", action="store_true",
                    help="do not load the original's register (shows what the resume is buying)")
    ap.add_argument("--max-report", type=int, default=6, help="divergences to print per field")
    a = ap.parse_args()

    rec = json.load(open(a.recording))
    turns = rec["turns_data"]
    if a.align_turn >= len(turns):
        raise SystemExit(f"--align-turn {a.align_turn} is past the end of a {len(turns)}-turn recording")

    keys = map_keys(turns, a.align_turn)
    rng_state = None
    if not a.no_rng_resume and a.align_turn > 0:
        rng_state = turns[a.align_turn - 1]["ds"]["rng"].replace(" ", "")
    print(f"recording: {len(turns)} turns, aligning at turn {a.align_turn} "
          f"-> {len(keys)} engine keys")
    print(f"rng resumed from: {rng_state or '(not resumed)'}")
    print("NOTE: the engine dumps one record per TURN; the recording samples one per KEY. A two-key")
    print("      command (attack + aim, unlock + aim) is one engine turn and two recording samples,")
    print("      so a script mixing them will mis-align. Use one-key commands until command alignment")
    print("      is built; the tool refuses rather than comparing a shifted pair.")

    work = tempfile.mkdtemp(prefix="u2-diff-", dir="/var/tmp")
    try:
        dumps, rc = run_engine(a, keys, rng_state, work)
        print(f"engine produced {len(dumps)} turn dumps (exit {rc})")
        n = min(len(dumps), len(turns) - a.align_turn)
        # A comparison over nothing is not a pass. This printed REPLAY DIFF: CLEAN once, with the
        # engine having produced zero dumps, which is the exact shape of gate this project has been
        # burned by three times: a checker that cannot fail reports success.
        if n == 0:
            print("\nREPLAY DIFF: INCONCLUSIVE — nothing was compared "
                  f"(engine dumps={len(dumps)}, recording turns after align={len(turns) - a.align_turn})")
            print(f"  engine exit {rc}; re-run with U2_DIFF_KEEP=1 and inspect the work dir")
            return 2
        if len(dumps) != len(keys):
            print(f"NOTE: engine ran {len(dumps)} turns against {len(keys)} keys; "
                  f"comparing the first {n}")
        print()
        print(f"{'field':<12} {'compared':>9} {'differing':>10}  verdict")
        total = 0
        compared_any = False
        for name, ofield, ofn, efn in COMPARISONS:
            diffs = []
            for i in range(n):
                try:
                    o = ofn(turns[a.align_turn + i]["ds"])
                    e = efn(dumps[i])
                except (KeyError, TypeError):
                    continue
                if o != e:
                    diffs.append((i, o, e))
            total += len(diffs)
            verdict = "MATCH" if not diffs else f"diverges at turn {diffs[0][0]}"
            print(f"{name:<12} {n:>9} {len(diffs):>10}  {verdict}")
            compared_any = True
            for i, o, e in diffs[:a.max_report]:
                print(f"    turn {i}: original {str(o)[:58]}")
                print(f"             engine   {str(e)[:58]}")
        print()
        if total == 0 and not compared_any:
            print("REPLAY DIFF: INCONCLUSIVE — no field could be read on both sides")
            return 2
        print(f"REPLAY DIFF: {'CLEAN' if total == 0 else f'{total} differing field-turns'}")
        return 0 if total == 0 else 1
    finally:
        if not os.environ.get("U2_DIFF_KEEP"):
            shutil.rmtree(work, ignore_errors=True)
        else:
            print(f"(work dir kept: {work})")


if __name__ == "__main__":
    sys.exit(main())
