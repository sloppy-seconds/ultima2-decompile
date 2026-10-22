# cleric_welcome — cleric greeting before tribute
# name-evidence: string 'WELCOME MY CHILD '
# func 4249..425E  len 0016 B  evidence: seed+reko
# strings: "WELCOME MY CHILD "
# calls: L_0051df (str_out)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
cleric_welcome:
L_004449:
        nop
L_00444a:
        call L_0051df
        db "WELCOME MY CHILD ",0x00        # string
