# sub_3038 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3038..3044  len 000D B  evidence: seed+reko
# strings: " FRIGATE"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3038:
L_003238:
        nop
L_003239:
        call L_0051df
        db " FRIGATE",0x00        # string
