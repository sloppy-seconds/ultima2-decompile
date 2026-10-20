# sub_34b5 — mechanical clean (bulk wave); behavior not yet reviewed
# func 34B5..34BF  len 000B B  evidence: seed+reko
# strings: "-CASTLE"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_34b5:
L_0036b5:
        call L_0051df
        db "-CASTLE",0x00        # string
