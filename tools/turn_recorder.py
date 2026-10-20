#!/usr/bin/env python3
"""Turn-triggered recorder for a live Ultima II session.

Design, and why it is not a fixed-rate logger:

Ultima II is turn-based. The world advances only when the player acts or when
the idle auto-PASS fires, and every such turn changes food by exactly 19
(accepted move) or 10 (pass). Food is therefore a monotonic odometer of turns,
which gives two things a wall-clock logger cannot:

  * a change trigger, so snapshots land on turn boundaries rather than
    somewhere between them; and
  * a missed-turn check, because a food delta that cannot be decomposed into
    19a + 10b consistent with the observed movement means we lost something and
    say so instead of quietly recording a wrong history.

Polling is fast on purpose: the memory API sustains 250 req/s at 0.3 ms with no
errors (measured 2026-10-21). The old 3 Hz limit belonged to the windowed CFG
view model, not to memory reads.

Each turn writes a raw snapshot (DS region + VGA) so any later tool can re-render
it, plus one JSONL index line with the derived facts.

Read-only against the emulator. Writes only under the output directory.

Usage: tools/turn_recorder.py [port] [--out DIR] [--hz 50] [--limit N]
"""
from __future__ import annotations

import argparse
import json
import pathlib
import time
import urllib.request

DS = 0x08BE
DS_LEN = 0x2800          # state block plus the 4 KB sector buffer
VGA_BASE = 0xB8000
VGA_LEN = 0x1900         # the span the game's own screen-invert routine touches

FOOD_PER_MOVE = 19
FOOD_PER_PASS = 10


def rd(port, phys, n):
    url = f"http://127.0.0.1:{port}/api/memory/{phys}/range/{n}"
    with urllib.request.urlopen(url, timeout=5) as r:
        return bytes(json.load(r)["values"])


def bcd3(b):
    """Three packed-decimal bytes, most significant pair first."""
    return int("".join(f"{x:02X}" for x in b))


def decompose(delta):
    """Can this food delta be made from a moves and b passes? Return one."""
    for a in range(0, delta // FOOD_PER_MOVE + 1):
        rem = delta - a * FOOD_PER_MOVE
        if rem >= 0 and rem % FOOD_PER_PASS == 0:
            return a, rem // FOOD_PER_PASS
    return None


def screen_text(vga, cols=80, rows=25):
    out = []
    for r in range(rows):
        line = ""
        for c in range(cols):
            i = (r * cols + c) * 2
            ch = vga[i] if i < len(vga) else 0
            line += chr(ch) if 32 <= ch < 127 else " "
        out.append(line.rstrip())
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("port", nargs="?", type=int, default=20180)
    ap.add_argument("--out", default="/var/tmp/u2-turns")
    ap.add_argument("--hz", type=float, default=50.0)
    ap.add_argument("--limit", type=int, default=4000,
                    help="stop after this many recorded turns")
    args = ap.parse_args()

    out = pathlib.Path(args.out)
    (out / "turns").mkdir(parents=True, exist_ok=True)
    idx_path = out / "index.jsonl"
    idx = open(idx_path, "a", buffering=1)

    period = 1.0 / args.hz
    ds_phys = DS * 16
    prev = None
    n = 0
    anomalies = 0
    print(f"recording on port {args.port} at {args.hz:g} Hz -> {out}")
    print("polls a 96-byte signature; full DS + VGA only on a real turn")
    try:
        while n < args.limit:
            t0 = time.time()
            head = rd(args.port, ds_phys, 0x60)
            sig = (head[0], head[1], head[0x53], head[0x54], head[0x55],
                   head[0x20])
            if prev is None:
                prev = sig
                print(f"baseline: pos=({head[0]},{head[1]}) "
                      f"food={bcd3(head[0x53:0x56])} hp={bcd3(head[0x51:0x53])}")
            elif sig != prev:
                ds = rd(args.port, ds_phys, DS_LEN)
                vga = rd(args.port, VGA_BASE, VGA_LEN)
                px, py = head[0], head[1]
                food = bcd3(head[0x53:0x56])
                delta = bcd3(bytes(prev[2:5])) - food
                dec = decompose(delta) if delta > 0 else None
                moved = (px, py) != (prev[0], prev[1])
                rejected = head[0x20] != prev[5]
                # A real turn is food falling in a way that decomposes into moves
                # and passes, with the move count agreeing with whether we moved.
                # A rejected step costs no food, so delta 0 with the invalid
                # counter up is legitimate rather than an anomaly.
                ok = ((dec is not None and (dec[0] > 0) == moved)
                      or (delta == 0 and rejected and not moved))
                if not ok:
                    anomalies += 1
                rec = {
                    "n": n, "t": round(time.time(), 3),
                    "pos": [px, py], "food": food, "delta": delta,
                    "moves": dec[0] if dec else None,
                    "passes": dec[1] if dec else None,
                    "moved": moved, "rejected": rejected,
                    "odometer_ok": ok,
                    "invalid_ctr": head[0x20],
                    "hp": bcd3(head[0x51:0x53]),
                    "gold": bcd3(head[0x58:0x5A]),
                    "exp": bcd3(head[0x56:0x58]),
                    "monsters": [[ds[0x137 + i], ds[0x157 + i], ds[0x197 + i]]
                                 for i in range(32)
                                 if ds[0x137 + i] or ds[0x157 + i]],
                }
                (out / "turns" / f"{n:05d}.ds").write_bytes(ds)
                (out / "turns" / f"{n:05d}.vga").write_bytes(vga)
                rec["screen"] = [l for l in screen_text(vga) if l.strip()][:12]
                idx.write(json.dumps(rec) + "\n")
                flag = "" if ok else "  <-- ODOMETER ANOMALY"
                kind = ("reject" if (delta == 0 and rejected)
                        else f"{rec['moves']}mv/{rec['passes']}pass")
                print(f"  turn {n:4d} pos=({px:2d},{py:2d}) d={delta:>5} "
                      f"[{kind}] hp={rec['hp']:5d} gold={rec['gold']:5d} "
                      f"mons={len(rec['monsters'])}{flag}")
                prev = sig
                n += 1
            sleep = period - (time.time() - t0)
            if sleep > 0:
                time.sleep(sleep)
    except KeyboardInterrupt:
        print("\nstopped")
    finally:
        idx.close()
        print(f"recorded {n} turns, {anomalies} odometer anomalies -> {idx_path}")


if __name__ == "__main__":
    main()
