# cleric_raise — cleric raises the dead
# name-evidence: string 'AND FOR IT I RAISE THEE '
# func 428E..42A9  len 001C B  evidence: seed+reko
# strings: "AND FOR IT I RAISE THEE "
# calls: L_0051df (str_out)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
cleric_raise:
L_00448e:
        call L_0051df
        db "AND FOR IT I RAISE THEE ",0x00        # string
