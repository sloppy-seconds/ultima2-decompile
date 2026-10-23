# 0AA4_monster_spawn_entry — the only branch in the binary that enters the spawner cluster
# name-evidence: three bytes, `jmp L_000e9c`, and the sole reference to L_000e9c anywhere
#           in asm/. It is reached only by fall-through from asm/0AA1_monster_sweep_next
#           when DI has walked down to 0, i.e. at the end of every creature sweep. This is
#           the trigger the wandering-spawn hunt was looking for: docs/monster-spawn.md
#           § 15.2.
# It is a jmp, not a call, and the sweep above it is entered by jmp/fall-through too, so
# there is no return address to recover at runtime: measured at a stop on 17D:0CEE inside
# the spawner, SS:SP = 0BCE:0100 with the word at SS:SP = 0x0000, all of SP..SP+0x40 zero
# (SP exactly at its initial value, no pending call frame), and `monitor peekRet` answers
# 017D:0000. Anything that models this as a called function will invent a caller that does
# not exist.
# label: kept as sub_0aa4 on purpose (CP3 cross-reference anchor).
# func 0AA4..0AA6  len 0003 B  evidence: seed+reko
# provenance: static reassembly + live stop, 2026-10-28 (docs/monster-spawn.md § 15.2)
# confidence: high
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0aa4:
L_000ca4:
        jmp L_000e9c
