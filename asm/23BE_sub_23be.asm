# sub_23be — mechanical clean (bulk wave); behavior not yet reviewed
# func 23BE..23C6  len 0009 B  evidence: seed+reko
# strings: "SOUTH"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_23be:
L_0025be:
        call L_0051df
        db "SOUTH",0x00        # string
