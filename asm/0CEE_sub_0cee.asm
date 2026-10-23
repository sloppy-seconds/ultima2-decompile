# sub_0cee — overworld spawner: store mon_kind[DS:1F], then dispatch on DS:60
# After the kind store this does `incb [0x60]` and falls into a chain of
# `clc ; rcr al,1 ; jae …` bit tests on DS:60, each bit selecting a species branch that
# sets type and HP for the slot — asm/0D4F_monster_hp_orc.asm is the Orc branch and
# writes type 0x30 with hp 0x10 = 16, which independently matches the bestiary's Orc HP
# of 16 from a completely different source. Two kinds of evidence agreeing on a number
# neither was derived from is the reason this reading is graded high.
# UNPROVEN: what DS:60 actually is. "Spawn counter" is the working name from `incb`
# plus the bit dispatch; a remaining-spawn bitmask or a seed fit the bytes equally well.
# See docs/monster-spawn.md § 11, "Still open".
# provenance: static, reassembled in address order 2026-10-23
# confidence: high for the bytes and the dispatch shape; low for DS:60's meaning
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
