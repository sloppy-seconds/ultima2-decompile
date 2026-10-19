# sub_09c9 — mechanical clean (bulk wave); behavior not yet reviewed
# func 09C9..09D4  len 000C B  evidence: seed+reko
# strings: "EAST"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_09c9:
L_000bc9:
        incb   0x0
L_000bcd:
        call L_0051df
        db "EAST",0x00        # string
