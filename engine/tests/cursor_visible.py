#!/usr/bin/env python3
"""cursor_visible.py — is the cursor cell actually visible in a dumped frame?

    python3 tests/cursor_visible.py FRAME.ppm ROW COL [--quiet]

Exits 0 when the cell at (ROW, COL) is visibly inverted against the frame, 1
when it is not, 2 on a usage or format error.

Why this exists, and why it is pixels rather than a grid assertion. The cursor
is not a character: it is the same glyph repainted inverse video by the
renderer, so every text-level check in this project passes whether the block is
drawn or not. On 2026-11-06 the FM Towns theme made it invisible twice over —
`sdl_flush` repainted the cell with U2_CGA_WHITE, which is index 3, and that
theme keeps a second black at index 3 — so the block was black on black and the
character under it was repainted in black as well. The grid was byte-for-byte
correct throughout. Only the frame could show it.

The test is the one property that distinguishes a drawn cursor from a missing
one without knowing any colours by name: inside the cell, the most common colour
must differ from the frame's most common colour (the background), and it must be
brighter. A cursor drawn in the background colour cannot satisfy both, which is
exactly the failure, so the check does not need the theme's palette.
"""
import sys

def read_ppm(path):
    with open(path, "rb") as f:
        data = f.read()
    if not data.startswith(b"P6"):
        raise ValueError("not a binary PPM (P6)")
    fields, i = [], 2
    while len(fields) < 3:
        while i < len(data) and data[i:i + 1].isspace():
            i += 1
        if data[i:i + 1] == b"#":
            while i < len(data) and data[i:i + 1] != b"\n":
                i += 1
            continue
        start = i
        while i < len(data) and not data[i:i + 1].isspace():
            i += 1
        fields.append(int(data[start:i]))
    i += 1                                  # exactly one whitespace byte
    w, h, maxv = fields
    if maxv != 255:
        raise ValueError(f"maxval {maxv}, expected 255")
    need = w * h * 3
    if len(data) - i < need:
        raise ValueError(f"truncated: {len(data) - i} bytes, need {need}")
    return w, h, data[i:i + need]

def cell_stats(w, h, px, row, col):
    """Modal colour and mean brightness of one character cell."""
    if w % 40 or h % 25:
        raise ValueError(f"{w}x{h} is not a 40x25 grid")
    cw, ch = w // 40, h // 25
    if not (0 <= row < 25 and 0 <= col < 40):
        raise ValueError(f"cell {row},{col} is outside the grid")
    counts = {}
    for y in range(row * ch, (row + 1) * ch):
        base = y * w * 3
        for x in range(col * cw, (col + 1) * cw):
            k = bytes(px[base + x * 3: base + x * 3 + 3])
            counts[k] = counts.get(k, 0) + 1
    modal = max(counts, key=counts.get)
    return modal, len(counts)

def frame_stats(w, h, px):
    counts = {}
    for i in range(0, len(px), 3):
        k = bytes(px[i:i + 3])
        counts[k] = counts.get(k, 0) + 1
    modal = max(counts, key=counts.get)
    return modal, len(counts)

def bright(c):
    return sum(c)

def main(argv):
    quiet = "--quiet" in argv
    args = [a for a in argv[1:] if not a.startswith("--")]
    if len(args) != 3:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    path, row, col = args[0], int(args[1]), int(args[2])
    try:
        w, h, px = read_ppm(path)
        cell_modal, cell_colours = cell_stats(w, h, px, row, col)
        frame_modal, _ = frame_stats(w, h, px)
    except (OSError, ValueError) as e:
        print(f"cursor_visible: {e}", file=sys.stderr)
        return 2
    if not quiet:
        print(f"frame {w}x{h}  background {tuple(frame_modal)}")
        print(f"cell ({row},{col})  modal {tuple(cell_modal)}  "
              f"{cell_colours} colour(s)")
    if cell_colours < 2:
        print(f"FAIL  cursor cell ({row},{col}) is one flat colour: "
              f"no block and no glyph", file=sys.stderr)
        return 1
    if cell_modal == frame_modal:
        print(f"FAIL  cursor cell ({row},{col}) is drawn in the background "
              f"colour {tuple(cell_modal)}", file=sys.stderr)
        return 1
    if bright(cell_modal) <= bright(frame_modal):
        print(f"FAIL  cursor cell ({row},{col}) is no brighter than the "
              f"background: {tuple(cell_modal)} vs {tuple(frame_modal)}",
              file=sys.stderr)
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
