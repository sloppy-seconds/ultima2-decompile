# sub_23cc — mechanical clean (bulk wave); behavior not yet reviewed
# func 23CC..23D3  len 0008 B  evidence: seed+reko
# strings: "EAST"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_23cc:
L_0025cc:
        call L_0051df
        db "EAST",0x00        # string
