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
# WHAT THE GUARD TESTS, settled 2026-10-28: the byte at [DI+0x1B7] is the TERRAIN TILE of the
#   rolled spawn coordinate, filed into the slot by asm/0CEE one instruction before this arm
#   is reached. Not a sprite (docs/spice86-live-findings.md called it "monster sprite stamped
#   into the map cell" and conflated two fields), and not a drawn kind index either, which is
#   what this header said until the store site was walked in address order. This arm wants
#   0x08; the two arms that want 0x00 are the sea creatures. The arms write the type to
#   [DI+0x197] and stamp the same value into the map cell via [bx+si]; they never write
#   [DI+0x1B7]. Evidence, the 11/11 cell check and the mutation caveat are in
#   docs/monster-spawn.md 15.4. See docs/needs-gameplay.md G18.
# RUNTIME CONFIRMED 2026-10-28: with DS:60 forced so the chain sees 0x01, this stamp site
#   executed with DS:60 = 01 and AL = 08, and slot 1d came back type 0x30 hp 0x10.
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
