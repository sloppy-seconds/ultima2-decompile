# sub_17e9 — mechanical clean (bulk wave); behavior not yet reviewed
# func 17E9..17EE  len 0006 B  evidence: seed+reko
# strings: "NO"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_17e9:
L_0019e9:
        call L_0051df
        db "NO",0x00        # string
