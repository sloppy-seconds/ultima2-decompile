# sub_0a02 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0A02..0A14  len 0013 B  evidence: seed+reko
# strings: "--INVALID MOVE!"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0a02:
L_000c02:
        call L_0051df
        db "--INVALID MOVE!",0x00        # string
