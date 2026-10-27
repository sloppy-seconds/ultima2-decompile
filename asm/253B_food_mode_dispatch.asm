# food_mode_dispatch — routes the per-step food charge by travel mode
# name-evidence: reads [DS:13], the player stamp / travel mode (0x78 foot, 0x22 horse,
#           0x24 ship, 0x26 plane, 0x28 rocket — docs/contract-creature-tick.md), and
#           dispatches. 0x28 rocket -> asm/2542_mode_arm_rocket.asm, REJECTS EVERY STEP,
#           no charge (it never reaches a drain, which is why it looked exempt).
#           0x26 plane -> asm/2604_mode_arm_plane.asm, charged via asm/2626_food_drain_mounted
#           and additionally refuses forest.
#           0x24 ship -> asm/2619_mode_arm_ship.asm, no charge, accepts water only.
#           0x22 horse -> asm/2557_mode_arm_horse.asm, charged via asm/2626_food_drain_mounted.
#           anything else (foot) -> asm/2575_sub_2575.asm, charged via
#           asm/2599_food_drain_walk.asm.
#           CORRECTED 2026-10-29: the rocket line used to point at asm/25F8 and call it an
#           accept, and the horse/plane lines did not mention that asm/2626 refuses shallow
#           water of its own. Both are fixed at the source files now; the dispatch order
#           here (0x28, 0x26, 0x24, 0x22, else foot) was always right.
#           This is the bytes' answer to the third-party claim that food is not consumed
#           aboard any vehicle (docs/needs-gameplay.md G34 claim 1): the ship and the
#           rocket are exempt, the plane is not, and the horse costs double.
# provenance: asm/2423 call graph + live:stepcost forced-[DS:13] samples 2026-10-25
# confidence: high
# func 253B..2541  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_253b:
L_00273b:
        mov    0x13,%al
L_00273e:
        cmp    $0x28,%al
L_002740:
        jne L_002745
