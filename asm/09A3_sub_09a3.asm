# sub_09a3 — mechanical clean (bulk wave); behavior not yet reviewed
# func 09A3..09AE  len 000C B  evidence: seed+reko
# strings: "WEST"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_09a3:
L_000ba3:
        decb   0x0
L_000ba7:
        call L_0051df
        db "WEST",0x00        # string
