# combat_miss_msg — attack missed
# name-evidence: string '--MISS'
# func 2E09..2E12  len 000A B  evidence: seed+reko
# strings: "--MISS"
# calls: L_0051df (str_out)
# provenance: live:airport (+13 other harvests), static
#           entry executed in 14 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
combat_miss_msg:
L_003009:
        call L_0051df
        db "--MISS",0x00        # string
