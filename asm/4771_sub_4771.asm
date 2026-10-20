# sub_4771 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4771..4776  len 0006 B  evidence: seed+reko
# strings: "S-"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4771:
L_004971:
        call L_0051df
        db "S-",0x00        # string
