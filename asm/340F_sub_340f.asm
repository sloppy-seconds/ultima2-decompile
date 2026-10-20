# sub_340f — mechanical clean (bulk wave); behavior not yet reviewed
# func 340F..341A  len 000C B  evidence: seed+reko
# strings: "-VILLAGE"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_340f:
L_00360f:
        call L_0051df
        db "-VILLAGE",0x00        # string
