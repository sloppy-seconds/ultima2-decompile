# monster_hp_thief_daemon — spawn arms: type 0xFC with HP 32, and type 0x34 with HP 64
# name-evidence: two arms, each storing a type immediate to [DI+0x197] and stamping it
#           into the map cell, then storing an HP immediate to [DI+0x177] (monster HP,
#           proven by asm/2E3D_combat_attack_flow). 0xFC >> 2 == art 0x3F (Thief,
#           third-party HP 32) and 0x34 >> 2 == art 0x0D (Daemon, third-party HP 64,
#           "paralyzes legs range 2" — and asm/0E70 is the leg-paralysis event).
# IMPORTANT: this settles the thief's type at 0xFC, which resolves the open question
#           in asm/0AD3_combat_special_attack_dispatch — the thief is NOT type 0x40,
#           so the `cmp $0x40` at file 0x1244 is skipping EMPTY slots, not naming a
#           creature.
# provenance: static, 2026-10-22; extracted by tools/monster_hp_dispatch.py
# confidence: high for the fields and values (bytes); creature names remain third-party
# label: kept as sub_0d6f on purpose — labels are body (CP0)
# GUARD BYTE: [DI+0x1B7] is the terrain tile of the rolled spawn coordinate, stored by
#   asm/0CEE. Both arms here want 0x08 (land). See asm/0D4F and docs/monster-spawn.md 15.4.
# RUNTIME CONFIRMED 2026-10-28: the Thief stamp executed with DS:60 forced so the chain saw
#   0x02 (AL=08, slot 1a came back type 0xFC hp 0x20), and again with the chain at 0x12, where
#   bits 1 and 4 are both set — the lower bit won. The Daemon arm entry executed with the
#   chain at 0x04 but AL=00, so it took the reject tail and rolled DS:60 back.
# func 0D6F..0DA3  len 0035 B  evidence: seed+reko
# calls: L_000daf, L_000fc4
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0d6f:
L_000f6f:
        mov    $0xfc,%al
L_000f71:
        mov    0x6,%bx
L_000f75:
        mov    %al,(%bx,%si)
L_000f77:
        mov    %al,0x197(%di)
L_000f7b:
        mov    $0x20,%al
L_000f7d:
        mov    %al,0x177(%di)
L_000f81:
        jmp L_000daf
L_000f84:
        mov    0x1b7(%di),%al
L_000f88:
        cmp    $0x8,%al
L_000f8a:
        je L_000f8f
L_000f8c:
        jmp L_000fc4
L_000f8e:
        nop
L_000f8f:
        mov    $0x34,%al
L_000f91:
        mov    0x6,%bx
L_000f95:
        mov    %al,(%bx,%si)
L_000f97:
        mov    %al,0x197(%di)
L_000f9b:
        mov    $0x40,%al
L_000f9d:
        mov    %al,0x177(%di)
L_000fa1:
        jmp L_000daf
