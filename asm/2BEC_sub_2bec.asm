# sub_2bec — mechanical clean (bulk wave); behavior not yet reviewed
# func 2BEC..2BF7  len 000C B  evidence: seed+reko
# strings: "--HIT!!!"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2bec:
L_002dec:
        call L_0051df
        db "--HIT!!!",0x00        # string
