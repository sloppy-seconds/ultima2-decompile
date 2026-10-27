# vehicle_ship — SHIP vehicle message branch
# name-evidence: string ' SHIP' + crew text
# func 2FFE..3034  len 0037 B  evidence: seed+reko
# strings: " SHIP"
# calls: L_0051df (str_out)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# CORRECTED 2026-10-29: this is the ship arm's REFUSAL, not a vehicle. asm/2FF6 tests
#           [DS:E2] and reaches here only when it is zero; the success path is asm/3038.
#           E2 is items_held[12], and docs/spice86-live-findings.md § 11 calls slot 12 BLUE
#           TASSLE — which is what the message says in other words: the crew will not let
#           you board without it. No mode is set and no cell is written on this path; it
#           ends at jmp L_000c30 (cmd_done).
#           The provenance line above ('entry never appears in ExecutedInstructions of any
#           of the 60 harvests') still holds: every capture that boarded a ship used a
#           character holding the tassle, so the refusal arm has never run on camera.
#           Grade: bytes for the branch and the string; the item identity is inferred from
#           the message naming it, corroborated by the slot arithmetic.
vehicle_ship:
L_0031fe:
        call L_0051df
        db " SHIP",0x8d,"THE CREW OF THIS SHIP",0x8d,"WILL NOT LET YOU BOARD!",0x00        # string
