# sub_3525 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3525..3539  len 0015 B  evidence: seed+reko
# strings: "-THE SIGN READS:"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3525:
L_003725:
        call L_0051df
        db "-THE SIGN READS:",0x0d,0x00        # string
