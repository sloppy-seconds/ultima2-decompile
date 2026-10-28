#!/usr/bin/env python3
"""save_cross_load.py — LOCAL, ON-DEMAND: do the engine and the original read each other's saves?

    python3 tools/save_cross_load.py                 # direction A only (no emulator)
    python3 tools/save_cross_load.py --with-emulator # A, then B against the live original
    python3 tools/save_cross_load.py --player FILE   # a specific real record instead of references/

**This is deliberately not wired into `make test` and not in any CI workflow.** Two reasons, both
Paul's, 2026-10-29: it needs `original/` and `references/`, which are gitignored, and a CI that
re-ran it on every push would be measuring a game binary that has not changed since the last time
it passed. **Run it when save handling changes** — `engine/src/core/save.c`, the write-back in
`engine/src/core/world.c`, the DS layout in `engine/src/core/state.h`, or this tool. That trigger
is also written into AGENTS.md § 3 so it outlives the memory of whoever added it.

What CI already covers, and what this adds: `engine/tests/save_check.c` runs in CI and asserts the
PLAYER record's byte format with engine-authored filler — sizes, offsets, tail preservation, the
both-directions claim at the byte level. What it cannot assert is the thing only the original can
answer: whether the real game accepts what we write, and whether we read what it wrote. That is
this harness.

Direction A, original -> engine, no emulator needed.
    Take a real record (default `references/ultima2/player`, the pristine shipped save), load it
    into the engine, dump the DS mirror, and compare DS:36..0x135 against the file bytes. A
    mismatch here is an offset drift or a byte-swap in our reader, and it is the failure mode
    `docs/save-format.md` warns about: the record is 256 bytes at DS:36 and the file is 384, so
    the tail is easy to read into the wrong place.

Direction B, engine -> original, needs Spice86.
    Have the engine write a save (Q), boot the original with that file as its `player`, press ESC
    and P so the game actually loads it, then peek DS:36..256 back out of the live process. If the
    original loads it and the bytes agree, the record we write is a record the original accepts.
    The peek is read from memory rather than from the run dir's `player` file on purpose: the game
    rewrites that file during play, so the file is not a stable witness.

Both directions print the decoded fields they compared, because "byte 0x9F differs" is a worse
report than "GOLD moved".
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, ".."))
ENGINE = os.path.join(REPO, "engine", "u2")

# The player record: 256 bytes at DS:36, in a 384-byte file (docs/save-format.md).
REC_OFF = 0x36
REC_LEN = 256
FILE_LEN = 384

# Fields worth naming in a diff, as (name, offset within the record, length).
FIELDS = [
    ("name", 0x00, 16), ("sex", 0x10, 1), ("pclass", 0x11, 1), ("race", 0x12, 1),
    ("sector", 0x13, 2), ("stats", 0x15, 6), ("hp", 0x1B, 2), ("food", 0x1D, 3),
    ("exp", 0x20, 2), ("gold", 0x22, 2), ("entry xy", 0x24, 2),
    ("weapons", 0x40, 10), ("armour owned", 0x61, 6), ("items", 0xA0, 16),
]

# Bytes inside the 256-byte window that are NOT save state, with the reason. The saved
# window and the persisted-field set are not the same thing, and direction B found that out
# by being strict: the only difference between the record the engine wrote and the memory of
# the original that loaded it was DS:74/75, the game speed, which asm/06AC_clock_tick_wait
# measures at every startup (docs/spice86-live-findings.md: 0x3A17 on this host). The
# original writes its freshly calibrated value into the file because the byte is inside the
# window; the engine has no clock calibration, so it writes what its mirror holds.
# Excluded with a reason rather than silently widened, and the values are still printed, so a
# change here is visible instead of merely tolerated.
EXCLUDED = [
    (0x3E, 2, "DS:74/75 speed — calibrated at startup by asm/06AC, runtime state that "
              "happens to sit inside the saved window"),
]


def excluded_at(off, n):
    """True if the range [off, off+n) overlaps any excluded range."""
    return any(off < e0 + e1 and off + n > e0 for e0, e1, _ in EXCLUDED)


def hexs(b):
    return " ".join("%02x" % x for x in b)


def field_diffs(a, b):
    """Per-field differences between two 256-byte records, named rather than offset-only.

    Ranges in EXCLUDED are reported as notes by the caller and never as failures, but they
    are still compared so a note can say what the two sides actually held.
    """
    out, notes = [], []
    for name, off, n in FIELDS:
        if a[off:off + n] != b[off:off + n]:
            if excluded_at(off, n):
                notes.append("%s (%s): %s | %s" % (name, hexs(a[off:off + n]),
                                                   hexs(b[off:off + n]),
                                                   [r for o, l, r in EXCLUDED if o == off][0]))
            else:
                out.append("%s: %s | %s" % (name, hexs(a[off:off + n]), hexs(b[off:off + n])))
    if a != b:
        for i in range(0, len(a), 16):
            if a[i:i + 16] != b[i:i + 16] and not excluded_at(i, 16):
                # Only bytes that differ, not the whole 16: a row-wide print hides which
                # byte moved, which is the thing a reader needs.
                moved = [j for j in range(16) if a[i + j] != b[i + j]]
                if all(excluded_at(i + j, 1) for j in moved):
                    notes.append("record[%#04x] (not a named field): %s | %s — excluded"
                                 % (i + moved[0], hexs([a[i + j] for j in moved]),
                                    hexs([b[i + j] for j in moved])))
                    continue
                out.append("record[%#04x:%#04x] (not a named field): %s | %s"
                           % (i, i + 16, hexs(a[i:i + 16]), hexs(b[i:i + 16])))
    return out, notes


def parse_ds_dump(path):
    """Parse a --dump-ds file: the first 0x280 DS bytes.

    The engine writes one continuous hex string (main.c prints "%02x" with no separator),
    but --load-ds accepts whitespace-separated hex, so accept both rather than assuming
    the two counterparts are symmetric — they are not, and a parser that guessed would
    read a whole record as one enormous integer and fail somewhere far away from here.
    """
    toks = open(path).read().split()
    if len(toks) == 1:
        h = toks[0]
        if len(h) % 2:
            raise RuntimeError("--dump-ds output has an odd hex length (%d)" % len(h))
        return bytes(int(h[i:i + 2], 16) for i in range(0, len(h), 2))
    return bytes(int(t, 16) for t in toks)


def engine_loads_record(player_file, work):
    """Load a real PLAYER into the engine and return the DS mirror bytes it produced."""
    save_dir = os.path.join(work, "save")
    data_dir = os.path.join(work, "content")
    os.makedirs(save_dir, exist_ok=True)
    os.makedirs(data_dir, exist_ok=True)
    shutil.copy(player_file, os.path.join(save_dir, "PLAYER"))
    # The engine needs a sector to open. Copy the real mapx/monx so the record's own sector
    # digits resolve to the real files rather than to a synthetic grid.
    src = os.path.join(REPO, "original")
    for name in os.listdir(src):
        if name.startswith(("mapx", "monx", "MAPX", "MONX", "mapg", "mong")):
            shutil.copy(os.path.join(src, name), os.path.join(data_dir, name))

    ds_path = os.path.join(work, "ds.txt")
    keys = os.path.join(work, "empty.keys")
    open(keys, "w").close()
    r = subprocess.run([ENGINE, "--headless", "--play-map", "--cleanroom",
                        "--data-dir", data_dir, "--save-dir", save_dir,
                        "--script", keys, "--dump-ds", ds_path],
                       capture_output=True, text=True)
    if not os.path.exists(ds_path):
        raise RuntimeError("engine wrote no --dump-ds file; stderr: %s" % r.stderr.strip()[:300])
    return parse_ds_dump(ds_path)


def direction_a(player_file, work):
    print("== A: original's record -> engine's reader")
    raw = open(player_file, "rb").read()
    if len(raw) < FILE_LEN:
        raise RuntimeError("%s is %d bytes, expected %d" % (player_file, len(raw), FILE_LEN))
    print("   source          %s (%d bytes)" % (os.path.relpath(player_file, REPO), len(raw)))
    ds = engine_loads_record(player_file, work)
    mirror = ds[REC_OFF:REC_OFF + REC_LEN]
    want = raw[:REC_LEN]
    diffs, notes = field_diffs(want, mirror)
    if diffs:
        for d in diffs:
            print("   FAIL  %s" % d)
        return False
    print("   ok    DS:36..0x135 matches the file byte for byte (%d bytes, %d named fields)"
          % (REC_LEN, len(FIELDS)))
    tail = raw[REC_LEN:FILE_LEN]
    print("   note  the record's %d-byte tail is not read into DS, per docs/save-format.md"
          % len(tail))
    return True


def engine_write_save(work, player_src, tag):
    """Load a real record into the engine and have it write one back with Q.

    Returns (bytes_written, ds_mirror). The save goes to a throwaway --save-dir, never to
    engine/saves/ or the user's own copy: the engine rewrites the record in place, and
    references/ is read-only by rule.
    """
    save_dir = os.path.join(work, "write-%s" % tag)
    data_dir = os.path.join(work, "content-%s" % tag)
    os.makedirs(save_dir, exist_ok=True)
    os.makedirs(data_dir, exist_ok=True)
    shutil.copy(player_src, os.path.join(save_dir, "PLAYER"))
    src = os.path.join(REPO, "original")
    for name in os.listdir(src):
        if name.startswith(("mapx", "monx", "MAPX", "MONX", "mapg", "mong")):
            shutil.copy(os.path.join(src, name), os.path.join(data_dir, name))

    keys = os.path.join(work, "q-%s.keys" % tag)
    with open(keys, "w") as f:
        f.write("Q\n")
    ds_path = os.path.join(work, "ds-%s.txt" % tag)
    subprocess.run([ENGINE, "--headless", "--play-map", "--cleanroom",
                    "--data-dir", data_dir, "--save-dir", save_dir,
                    "--script", keys, "--dump-ds", ds_path],
                   capture_output=True, text=True)
    written = open(os.path.join(save_dir, "PLAYER"), "rb").read()
    return written, (parse_ds_dump(ds_path) if os.path.exists(ds_path) else b"")


def engine_authored_record(work):
    """Produce a record with the engine's own reader and writer, from the gate seed.

    Why not the shipped references/ultima2/player: that file is the BLANK template the game
    uses for creation, and the original refuses to 'load previous character' from it — the
    first run of this harness proved that, reading DS:13 = 0x00 and a blank name because the
    game never left the title. The seed record is engine-authored filler (name GATEMAX, real
    stats, sector 00), which is exactly the thing under test: a file WE wrote, that the
    original has to accept.
    """
    seed_dir = os.path.join(work, "seed-b")
    subprocess.run([sys.executable, os.path.join(REPO, "engine", "tests",
                                                 "cp5_fight_seed.py"), seed_dir], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    written, _ = engine_write_save(work, os.path.join(seed_dir, "save", "PLAYER"), "b")
    return written


def direction_b(work, player_src, http_port, mcp_port):
    """Engine writes a save; the original loads it; the bytes must agree.

    The comparison is read out of the live process rather than from the run dir's `player`
    file, because the game rewrites that file as it plays and it is not a stable witness.
    The name at DS:36 is checked first and is the real proof: if the original shows the
    seed character's name, it loaded OUR file rather than sitting on a title screen.
    """
    print("== B: engine's record -> the original's loader")
    written = engine_authored_record(work)
    if len(written) < FILE_LEN:
        print("   FAIL  engine wrote %d bytes, expected %d" % (len(written), FILE_LEN))
        return False
    seed_name = written[0x00:0x10].rstrip(b"\x00")
    print("   engine wrote a %d-byte record for %r" % (len(written), seed_name))

    sys.path.insert(0, HERE)
    try:
        from spice86_type import read_mem
    except ImportError as e:
        print("   FAIL  cannot import read_mem from tools/spice86_type.py: %s" % e)
        return False

    our_file = os.path.join(work, "write-b", "PLAYER")
    start = ["bash", os.path.join(REPO, "tools", "spice86_start.sh"), "--headless",
             "--name", "xload", "--player", our_file,
             "--auto-play", "--patch-arrows",
             "--http-port", str(http_port), "--mcp-port", str(mcp_port)]
    print("   booting the original with our save (this takes about a minute)...")
    r = subprocess.run(start, capture_output=True, text=True, timeout=300)
    if "HTTP API ready" not in r.stdout:
        print("   FAIL  emulator did not come up: %s" % (r.stdout + r.stderr)[-400:])
        subprocess.run(["bash", os.path.join(REPO, "tools", "spice86_stop.sh"), "--no-harvest"],
                       capture_output=True, text=True)
        return False

    try:
        # DS:13 is the travel mode: 0x78 means the game is actually in the world and has
        # loaded a character, rather than sitting on the title or the poem screen.
        stamp = read_mem(0x08BE, 0x13, 1, http_port)[0]
        live = read_mem(0x08BE, REC_OFF, REC_LEN, http_port)
        name = read_mem(0x08BE, 0x36, 16, http_port).rstrip(b"\x00")
        print("   original: DS:13 = %#02x, name at DS:36 = %r" % (stamp, name))
        if stamp not in (0x78, 0x7A, 0x7C, 0x7E):
            print("   FAIL  DS:13 = %#02x: the original never reached the world, so the"
                  " comparison below would prove nothing" % stamp)
            return False
        if name != seed_name:
            print("   FAIL  the original loaded %r, not our %r" % (name, seed_name))
            return False
        diffs, notes = field_diffs(written[:REC_LEN], live)
        # Always show what the excluded ranges held, not only when they differ: a tolerance
        # that prints nothing is indistinguishable from a tolerance that never fired, and the
        # whole point of the list is that a future reader can see whether it is load-bearing.
        for e0, e1, why in EXCLUDED:
            print("   note  record[%#04x] excluded (%s): ours %s | original %s — %s"
                  % (REC_OFF + e0, "DS:%02X" % (REC_OFF + e0),
                     hexs(written[e0:e0 + e1]), hexs(live[e0:e0 + e1]), why))
        for n in notes:
            print("   note  %s" % n)
        if diffs:
            for d in diffs:
                print("   FAIL  %s" % d)
            return False
        print("   ok    the original loaded our record: DS:36..0x135 matches the %d bytes"
              " the engine wrote" % REC_LEN)
        return True
    finally:
        # --no-harvest, and this matters more than tidiness. The provenance gates count the
        # harvests under captures/spice86/ and quote "N of 167 harvests" in asm headers, so a
        # harness that harvested would silently move every one of those denominators and leave
        # a save-test dump masquerading as behavioural evidence. This session found that the
        # hard way: the first cross-load run made the corpus 168 and cmd_provenance_derived
        # went red on cmd_Z: 14/167 -> 14/168. A save-compatibility probe is not evidence
        # about what the game does, so it must not join the corpus that decides what ran.
        subprocess.run(["bash", os.path.join(REPO, "tools", "spice86_stop.sh"), "--no-harvest"],
                       capture_output=True, text=True)


def main():
    ap = argparse.ArgumentParser(description="cross-load the PLAYER record between engine and original")
    ap.add_argument("--player", default=os.path.join(REPO, "references", "ultima2", "player"))
    ap.add_argument("--with-emulator", action="store_true",
                    help="also run direction B: boot the original and have it load our save")
    ap.add_argument("--http-port", type=int, default=20285)
    ap.add_argument("--mcp-port", type=int, default=20286)
    args = ap.parse_args()

    if not os.path.exists(ENGINE):
        sys.exit("save_cross_load: build the engine first (make -C engine)")
    if not os.path.exists(args.player):
        sys.exit("save_cross_load: no player record at %s — this harness needs the user's own "
                 "copy and will NOT skip silently" % args.player)
    if not os.path.isdir(os.path.join(REPO, "original")):
        sys.exit("save_cross_load: no original/ content directory; direction A needs real "
                 "mapx/monx files to open the record's sector")

    work = tempfile.mkdtemp(prefix="u2-xload-", dir="/var/tmp")
    try:
        ok = direction_a(args.player, work)
        print()
        if args.with_emulator:
            ok = direction_b(work, args.player, args.http_port, args.mcp_port) and ok
        else:
            print("== B: engine's record -> the original's loader")
            print("   not run (needs --with-emulator and a live Spice86 session)")
        print()
        print("SAVE CROSS-LOAD: %s" % ("PASS" if ok else "FAIL"))
        return 0 if ok else 1
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
