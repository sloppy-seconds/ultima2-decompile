# sub_40a6 — mechanical clean (bulk wave); behavior not yet reviewed
# func 40A6..40BC  len 0017 B  evidence: seed+reko
# strings: "FUNNY, NO RESPONSE!"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_40a6:
L_0042a6:
        call L_0051df
        db "FUNNY, NO RESPONSE!",0x00        # string
