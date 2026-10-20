# sub_23d9 — mechanical clean (bulk wave); behavior not yet reviewed
# func 23D9..23E0  len 0008 B  evidence: seed+reko
# strings: "WEST"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_23d9:
L_0025d9:
        call L_0051df
        db "WEST",0x00        # string
