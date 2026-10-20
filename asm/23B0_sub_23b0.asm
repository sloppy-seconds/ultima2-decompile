# sub_23b0 — mechanical clean (bulk wave); behavior not yet reviewed
# func 23B0..23B8  len 0009 B  evidence: seed+reko
# strings: "NORTH"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_23b0:
L_0025b0:
        call L_0051df
        db "NORTH",0x00        # string
