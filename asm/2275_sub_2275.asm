# sub_2275 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2275..2289  len 0015 B  evidence: seed+reko
# strings: "-ILLEGAL COMMAND!"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2275:
L_002475:
        call L_0051df
        db "-ILLEGAL COMMAND!",0x00        # string
