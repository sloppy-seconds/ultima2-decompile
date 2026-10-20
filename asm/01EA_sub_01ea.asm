# sub_01ea — mechanical clean (bulk wave); behavior not yet reviewed
# func 01EA..01FC  len 0013 B  evidence: seed+reko
# strings: "BY LORD BRITISH"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_01ea:
L_0003ea:
        call L_0051df
        db "BY LORD BRITISH",0x00        # string
