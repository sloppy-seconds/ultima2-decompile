# sub_097c — mechanical clean (bulk wave); behavior not yet reviewed
# func 097C..0988  len 000D B  evidence: seed+reko
# strings: "SOUTH"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_097c:
L_000b7c:
        incb   0x1
L_000b80:
        call L_0051df
        db "SOUTH",0x00        # string
