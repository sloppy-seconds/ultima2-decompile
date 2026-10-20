# sub_0c8c — mechanical clean (bulk wave); behavior not yet reviewed
# func 0C8C..0C99  len 000E B  evidence: seed+reko
# strings: " IS DEAD!"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0c8c:
L_000e8c:
        call L_0051df
        db " IS DEAD!",0x8d,0x00        # string
