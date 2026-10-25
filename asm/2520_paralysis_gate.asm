# paralysis_gate — the `--PARALIZED!` early return, ahead of the food charge
# name-evidence: reads [DS:26B]; nonzero -> asm/2527_sub_2527.asm prints
#           `--PARALIZED!` and returns 0xFF from asm/2423_passability WITHOUT reaching
#           asm/253B_food_mode_dispatch. So a paralyzed character pays no food for a
#           refused step, which is the branch the engine's paralysis arm already models.
#           Reached from asm/24B1_sub_24b1.asm (the ordinary path) and from the tail of
#           asm/24B5_force_field_event.asm.
# provenance: asm/2423 call graph; the DS:26B paralysis flag is the owner-reported
#           `ARMS PARALYZED!` state, confirmed live on tmp/seed-townhp
# confidence: high
# func 2520..2526  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2520:
L_002720:
        mov    0x26b,%al
L_002723:
        cmp    $0x0,%al
L_002725:
        je L_00273b
