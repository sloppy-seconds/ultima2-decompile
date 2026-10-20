# sub_2e09 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2E09..2E12  len 000A B  evidence: seed+reko
# strings: "--MISS"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2e09:
L_003009:
        call L_0051df
        db "--MISS",0x00        # string
