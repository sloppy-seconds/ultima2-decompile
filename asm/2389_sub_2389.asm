# sub_2389 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2389..2391  len 0009 B  evidence: seed+reko
# strings: "PASS"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2389:
L_002589:
        pop    %ax
L_00258a:
        call L_0051df
        db "PASS",0x00        # string
