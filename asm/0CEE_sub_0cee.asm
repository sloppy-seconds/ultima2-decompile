# sub_0cee — store mon_kind[DI], then a bit-test dispatch on DS:60
# After the kind store: `incb [0x60]` then a chain of `clc ; rcr al,1 ; jae …`, each bit
# selecting a species branch that sets type and HP for the slot. asm/0D4F_monster_hp_orc
# is the Orc branch and writes type 0x30 with hp 0x10 = 16, matching the bestiary's Orc
# HP of 16 from an unrelated third-party source — the one cross-check in this cluster
# that holds up independently.
# NOT ESTABLISHED, and the live check made it worse rather than better: DS:60 read 0 after
# a session in which the player moved and food fell, so the `incb` path never ran and
# "spawn counter" has no observation behind it at all. See docs/monster-spawn.md § 11.
# provenance: static reassembly 2026-10-23, live-disproved same day
# confidence: high for the bytes and the dispatch shape; LOW for DS:60's meaning
# func 0CEE..0D05  len 0018 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0cee:
L_000eee:
        mov    $0x0,%bh
L_000ef0:
        mov    0x1f,%bl
L_000ef4:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_000ef6:
        mov    %al,0x1b7(%di)
L_000efa:
        incb   0x60
L_000efe:
        mov    0x60,%al
L_000f01:
        clc
L_000f02:
        rcr    $1,%al
L_000f04:
        jae L_000f09
