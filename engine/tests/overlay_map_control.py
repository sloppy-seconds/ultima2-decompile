#!/usr/bin/env python3
"""Control for the theme v2 player marker.

u2_frame_draw_view_ega() must route the overlay through the theme's art -> pool
map before it addresses the atlas. The first version blitted the art index
straight at the atlas, which is identity for every v1 theme and therefore
invisible, and wrong for the first real table: art 60 is the avatar, pool index
60 in the FM Towns theme is a capital O, and that is what a player saw.

theme_v2_check owns the assertion. This file owns the proof that the assertion
can fail: it restores the raw blit into a throwaway copy of frame.c, rebuilds the
real check against it, and requires the overlay checks to go red. A check that
cannot go red is decoration, and this one passed for an entire theme format.

Run from the engine directory. Prints one summary line and exits non-zero if the
control did not behave.
"""
import os
import shutil
import subprocess
import sys

FRAME = "src/core/frame.c"
CHECK = "tests/theme_v2_check.c"
SOURCES = [
    "src/core/view.c", "src/core/tiles_ega.c", "src/core/ini.c",
    "src/core/font.c", "src/core/vram.c", "src/debug/trace.c",
]

FIXED = """        const int tile = u2_tiles_ega_tile(t, overlay_art);
        if (tile >= 0)
            u2_frame_blit_tile_ega(f, t, tile,
                                   overlay_col * cell_w, overlay_row * cell_h);"""
BUGGY = """        u2_frame_blit_tile_ega(f, t, overlay_art,
                               overlay_col * cell_w, overlay_row * cell_h);"""


def fail(msg: str) -> "int":
    print(f"BROKEN: {msg}")
    return 1


def main() -> int:
    for p in (FRAME, CHECK):
        if not os.path.exists(p):
            return fail(f"{p} not found; run this from the engine directory")

    work = sys.argv[1] if len(sys.argv) > 1 else "/var/tmp/u2-overlay-control"
    shutil.rmtree(work, ignore_errors=True)
    os.makedirs(work, exist_ok=True)

    src = open(FRAME).read()
    if FIXED not in src:
        return fail("the fixed block is not where the control expects it, so the "
                    "control is stale and proves nothing")
    patched = os.path.join(work, "frame.c")
    open(patched, "w").write(src.replace(FIXED, BUGGY, 1))

    exe = os.path.join(work, "v2c")
    cc = (["cc", "-std=c11", "-Wall", "-Wextra", "-Isrc", "-Icontent", "-o", exe,
           CHECK, patched] + SOURCES)
    r = subprocess.run(cc, capture_output=True, text=True)
    if r.returncode != 0:
        return fail("the mutated check did not compile:\n" + r.stderr[-700:])

    run = subprocess.run([exe], capture_output=True, text=True)
    out = run.stdout + run.stderr
    red = [l.strip() for l in out.splitlines() if "overlay" in l and "FAIL" in l]
    if run.returncode == 0 or not red:
        return fail("the check stayed green with the bug restored:\n" + out[-700:])

    print(f"overlay map control: {len(red)} assertion(s) able to go red")
    return 0


if __name__ == "__main__":
    sys.exit(main())
