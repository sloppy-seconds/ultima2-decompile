# open_no_door — OPEN with no door here
# name-evidence: string 'NO DOOR THERE!'
# func 4310..4325  len 0016 B  evidence: seed+reko
# calls: L_000c30, L_0051df (str_out)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
open_no_door:
L_004510:
        call L_0051df
        db 0x8d,"NO DOOR THERE!",0x00        # string
L_004523:
        jmp L_000c30
