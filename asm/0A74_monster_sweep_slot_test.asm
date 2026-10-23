# 0A74_monster_sweep_slot_test — loop body: skip an empty slot, otherwise run the AI
# name-evidence: `mov 0x197(%di),%al ; or %al,%al ; je L_000ca1` -- mon_type[slot] == 0
#           means the slot is free and the sweep moves on; a live slot falls through to
#           the mode/kind tests here and then to asm/0AA7_sub_0aa7 (the per-creature
#           body, which reaches the combat special gate in asm/0AAA).
# Loop-back labels L_000ca1 and L_000c74 are named from asm/0BAB, asm/2195 and asm/2272
# as well, so the AI paths do return to the sweep rather than leaving it -- which is what
# makes the sweep's end-of-loop fall-through unconditional. docs/monster-spawn.md § 15.2.
# NOT ESTABLISHED: what the DS:13 / DS:26 tests and the 0x48/0x3C/0x2C kind compares mean.
# label: kept as sub_0a74 on purpose (CP3 cross-reference anchor).
# func 0A74..0A7B  len 0008 B  evidence: seed+reko
# provenance: static reassembly 2026-10-28 (docs/monster-spawn.md § 15.2)
# confidence: high for the empty-slot skip; low for the mode tests
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0a74:
L_000c74:
        mov    0x197(%di),%al
L_000c78:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_000c7a:
        je L_000ca1
