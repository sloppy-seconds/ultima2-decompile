# sub_462f — mechanical clean (bulk wave); behavior not yet reviewed
# func 462F..4637  len 0009 B  evidence: seed+reko
# strings: "KEYS-"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_462f:
L_00482f:
        call L_0051df
        db "KEYS-",0x00        # string
