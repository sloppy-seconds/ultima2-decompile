# level_gain_msg — reports a level gain
# name-evidence: string 'A LEVEL '
# func 4580..458C  len 000D B  evidence: seed+reko
# calls: L_0051df (str_out)
# provenance: live:airport (+11 other harvests), static
#           entry executed in 12 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
level_gain_msg:
L_004780:
        call L_0051df
        db 0x8d,"A LEVEL ",0x00        # string
