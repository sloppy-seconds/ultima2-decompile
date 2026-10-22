# monster_hp_orc — spawn arm: assigns monster type 0x30 and HP 16
# name-evidence: `mov $0x30,%al` stored to [DI+0x197] and stamped into the map cell,
#           then `mov $0x10,%al` stored to [DI+0x177]. [DI+0x177] is proven to be
#           monster HP by asm/2E3D_combat_attack_flow, which subtracts the damage
#           byte at [DS:20] from it and, on borrow, zeroes HP, type and sprite
#           together. Type 0x30 >> 2 == art 0x0C, which bestiary/bestiary.tsv names
#           Orc by bitmap identity, and the third-party HP for Orc is 16: three
#           independent lines landing on one arm.
# provenance: static, 2026-10-22; extracted by tools/monster_hp_dispatch.py
# confidence: high for the field and the value (bytes). The creature NAME remains
#           third-party and is not promoted by this file.
# label: kept as sub_0d4f on purpose — labels are body (CP0)
# CORRECTION 2026-10-22 about the guard key: the value this family tests at
#   [DI+0x1B7] is a small KIND INDEX, not a sprite. A live read of all 32 monster
#   slots found [DI+0x1B7] holding only 0x08 and 0x0C, which is exactly what the
#   guards compare against (`cmp $0x8,%al`). The arms write the type to [DI+0x197]
#   and stamp the same value into the map cell via [bx+si]; they never write
#   [DI+0x1B7]. docs/spice86-live-findings.md describes [DI+0x1B7] as "monster
#   sprite stamped into the map cell" and that is wrong — it conflated the two
#   fields, which is why the type->art transform briefly looked corroborated by two
#   fields when only one is involved. See docs/needs-gameplay.md G18.
# func 0D4F..0D63  len 0015 B  evidence: seed+reko
# calls: L_000daf
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0d4f:
L_000f4f:
        mov    $0x30,%al
L_000f51:
        mov    0x6,%bx
L_000f55:
        mov    %al,(%bx,%si)
L_000f57:
        mov    %al,0x197(%di)
L_000f5b:
        mov    $0x10,%al
L_000f5d:
        mov    %al,0x177(%di)
L_000f61:
        jmp L_000daf
