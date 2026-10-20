# sub_018d — mechanical clean (bulk wave); behavior not yet reviewed
# func 018D..0197  len 000B B  evidence: seed+reko
# strings: "PART ]["
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_018d:
L_00038d:
        call L_0051df
        db "PART ][",0x00        # string
