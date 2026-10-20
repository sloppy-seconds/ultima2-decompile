# sub_4853 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4853..485D  len 000B B  evidence: seed+reko
# strings: "ITEMS: "
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4853:
L_004a53:
        call L_0051df
        db "ITEMS: ",0x00        # string
