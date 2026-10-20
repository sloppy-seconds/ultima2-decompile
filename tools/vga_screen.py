#!/usr/bin/env python3
"""Render the text-mode screen out of a Spice86 memory dump.

Why: the windowed Spice86 UI drops or garbles game text, so fight and reward
messages were invisible to us. They are not lost. Ultima II runs in a text
video mode, and the harvest's memory dump contains the framebuffer at B8000 as
character/attribute pairs, so the screen as the player saw it is recoverable
from a capture we already have. No trace, no replayer, no new run required.

This is a snapshot of the screen at harvest time, not a recording. Anything that
scrolled off before the dump is genuinely gone; to keep it, dump more often.

Usage: tools/vga_screen.py <memorydump.bin> [--cols 80] [--rows 25]
       tools/vga_screen.py <memorydump.bin> --attrs
"""
import argparse
import sys

TEXT_BASE = 0xB8000
CELLS_MAX = 0x2000


def load(path):
    with open(path, "rb") as f:
        return f.read()


def render(dump, cols=80, rows=25, attrs=False):
    blob = dump[TEXT_BASE:TEXT_BASE + CELLS_MAX * 2]
    if len(blob) < cols * rows * 2:
        sys.exit(f"dump too small for {cols}x{rows}: have {len(blob)} bytes "
                 f"at {hex(TEXT_BASE)}")
    lines = []
    for r in range(rows):
        text = ""
        attr = ""
        for c in range(cols):
            i = (r * cols + c) * 2
            ch = blob[i]
            a = blob[i + 1]
            text += chr(ch) if 32 <= ch < 127 else " "
            attr += f"{a:02x} "
        line = text.rstrip()
        if attrs:
            line = f"{r:2d}|{line}\n   attr: {attr.rstrip()}"
        lines.append(f"{r:2d}|{line}" if not attrs else line)
    return lines


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dump")
    ap.add_argument("--cols", type=int, default=80)
    ap.add_argument("--rows", type=int, default=25)
    ap.add_argument("--attrs", action="store_true",
                    help="also print the attribute byte per cell (colour/blink)")
    ap.add_argument("--nonblank-only", action="store_true")
    args = ap.parse_args()

    dump = load(args.dump)
    lines = render(dump, args.cols, args.rows, args.attrs)
    for ln in lines:
        if args.nonblank_only and not ln.strip():
            continue
        print(ln)


if __name__ == "__main__":
    main()
