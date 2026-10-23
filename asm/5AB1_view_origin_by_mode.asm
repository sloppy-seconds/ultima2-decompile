# 5AB1_view_origin_by_mode — the routine the spawn arms call, and it is a viewport origin
# name-evidence: entry L_005cb1 is `call`ed from asm/0BAF_monster_hp_epilogue and five
#           others (0864, 08E6, 268C, 26CC, 38B0_cmd_L, 72A0). § 15 of
#           docs/monster-spawn.md listed this entry point as unknown behaviour; this is it.
#           It opens `cmpb $0xff,0x12` and branches between two near-identical
#           computations: asm/5B98 (world map) and asm/5ABB (interior). Both set
#           DS:03 = [DS:01] - 6 and DS:02 = [DS:00] - 10 via the `stc ; sbb ; cmc` idiom,
#           and the world-map branch alone masks both with `and $0x3f` -- the torus wrap.
#           So DS:02/03 are a viewport origin, and the only difference between overworld
#           and interior is whether that origin wraps.
# DS:12 IS NOT A TILE. It is a mode byte: 0xFF on the world map, 4 in an interior sector,
#           written by asm/0C1F_status_tick_branch and asm/0C2B on the [DS:4A] branch --
#           and DS:4A is the sector's low decimal digit (docs/monster-spawn.md § 15.2).
#           Live cross-check 2026-10-28: DS:12 read 0xFF in sector 20 (digit 0) and 4 in
#           sector 32 (digit 2). Two independent bytes agreeing on the same branch.
# Its only two readers in the tree are here and asm/5AF9_sub_5af9.asm (`mov 0x12,%al`).
# label: kept as sub_5ab1 on purpose (CP3 cross-reference anchor).
# func 5AB1..5AB7  len 0007 B  evidence: seed+call+reko
# provenance: static reassembly 2026-10-28 + the two live reads above
# confidence: high for the branch and the two origin computations; the -9/-5 vs -10/-6
#           difference against asm/5AE1 (which engine/src/core/state.h cites for the
#           window origin) is unreconciled and is a real open question, not a rounding
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5ab1:
L_005cb1:
        cmpb   $0xff,0x12
L_005cb6:
        jne L_005cbb
