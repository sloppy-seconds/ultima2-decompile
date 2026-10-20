# sub_014b — mechanical clean (bulk wave); behavior not yet reviewed
# func 014B..0154  len 000A B  evidence: seed+reko
# strings: "ORIGIN"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_014b:
L_00034b:
        call L_0051df
        db "ORIGIN",0x00        # string
