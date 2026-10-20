# sub_33ae — mechanical clean (bulk wave); behavior not yet reviewed
# func 33AE..33C2  len 0015 B  evidence: seed+reko
# strings: "-ONLY ON FOOT!"
# calls: L_000c30, L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_33ae:
L_0035ae:
        call L_0051df
        db "-ONLY ON FOOT!",0x00        # string
L_0035c0:
        jmp L_000c30
