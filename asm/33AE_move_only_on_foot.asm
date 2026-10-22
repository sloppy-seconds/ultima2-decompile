# move_only_on_foot — movement rejected while mounted
# name-evidence: string '-ONLY ON FOOT!'
# func 33AE..33C2  len 0015 B  evidence: seed+reko
# strings: "-ONLY ON FOOT!"
# calls: L_000c30, L_0051df (str_out)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
move_only_on_foot:
L_0035ae:
        call L_0051df
        db "-ONLY ON FOOT!",0x00        # string
L_0035c0:
        jmp L_000c30
