# sub_0955 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0955..0961  len 000D B  evidence: seed+reko
# strings: "NORTH"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0955:
L_000b55:
        decb   0x1
L_000b59:
        call L_0051df
        db "NORTH",0x00        # string
