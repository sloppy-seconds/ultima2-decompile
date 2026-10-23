#!/usr/bin/env python3
"""Emit a synthetic content directory for the CP5 fight gate.

Everything written here is engine-authored filler — the same rule monsters_check.c
and world_check.c follow, so that a fight can be gated in CI without touching the
player's own game files. The bytes are shaped like the real ones because the engine
reads them the same way: a 4096-byte mapx, a 256-byte monx, a 384-byte PLAYER
record whose byte i is DS[0x36+i] (docs/save-format.md).

Usage: cp5_fight_seed.py DIR
"""
import os
import sys

GRASS = 0x08          # measured passable on foot (docs/passability-findings.md F10)
SLOT = 32             # creature slots per array; monx columns are 32 bytes apart


def main(out_dir: str) -> int:
    content = os.path.join(out_dir, "content")
    save = os.path.join(out_dir, "save")
    os.makedirs(content, exist_ok=True)
    os.makedirs(save, exist_ok=True)

    # --- mapx00: all grass, sector 00 being the one the save names -------------
    with open(os.path.join(content, "mapx00"), "wb") as f:
        f.write(bytes([GRASS]) * 4096)

    # --- monx00: one creature at (3,0), the cell east of the player's entry ----
    # Columns: x 0..31, y 32..63, hp 64..95, type 96..127, kind 128..159,
    # role 160..191 (docs/monster-spawn.md § 6). Role 1 is the full AI pass
    # (§ 14), so the creature is awake from the first turn.
    mon = bytearray(256)
    mon[0 + 0] = 3            # x of slot 0
    mon[32 + 0] = 0           # y of slot 0
    mon[64 + 0] = 5           # hp — one hit from this character kills outright
    mon[96 + 0] = 0x68        # type: the Fighter art, 0x68 >> 2 == 0x1A
    mon[128 + 0] = 0x70       # kind
    mon[160 + 0] = 1          # role: active
    with open(os.path.join(content, "monx00"), "wb") as f:
        f.write(bytes(mon))

    # --- PLAYER: 384 bytes, file[i] == DS[0x36+i] -----------------------------
    p = bytearray(384)
    p[0x36 - 0x36:0x36 - 0x36 + 6] = b"GATEMAX"[:6]      # name at DS:36
    p[0x49 - 0x36] = 0                    # sector first digit
    p[0x4A - 0x36] = 0                    # sector second digit: the world map
    p[0x51 - 0x36] = 0x99                 # HP high BCD byte
    p[0x52 - 0x36] = 0x97                 # HP low  -> H.P.=9997
    p[0x53 - 0x36] = 0x99                 # food, three bytes
    p[0x54 - 0x36] = 0x99
    p[0x55 - 0x36] = 0x99
    p[0x56 - 0x36] = 0x99                 # exp  -> EXP.=9999, so a kill wraps it
    p[0x57 - 0x36] = 0x99
    p[0x58 - 0x36] = 0x99                 # gold -> GOLD=9999, same
    p[0x59 - 0x36] = 0x99
    p[0x5A - 0x36] = 2                    # entry x: the cell the player starts on
    p[0x5B - 0x36] = 0                    # entry y
    p[0x61 - 0x36] = 1                    # readied weapon index 1 (damage = 8*w + str)/4
    p[0x4C - 0x36] = 0x80                 # agility byte 0x80 = 128 displayed:
    #                                       asm/2E3D rolls (rand>>1) < agi and the
    #                                       roll maxes at 127, so a hit is certain.
    p[0x4B - 0x36] = 0x40                 # strength, plenty for a one-hit kill
    with open(os.path.join(save, "PLAYER"), "wb") as f:
        f.write(bytes(p))
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: cp5_fight_seed.py DIR", file=sys.stderr)
        raise SystemExit(2)
    raise SystemExit(main(sys.argv[1]))
