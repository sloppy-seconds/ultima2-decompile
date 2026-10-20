# sub_4188 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4188..41A2  len 001B B  evidence: seed+reko
# strings: "A CLERIC SAYS:"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4188:
L_004388:
        call L_0051df
        db "A CLERIC SAYS:",0x0d,"BELIEVE!",0x00        # string
