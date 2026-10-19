# sub_4881 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4881..4885  len 0005 B  evidence: seed+reko
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4881:
L_004a81:
        call L_0051df
        db "S",0x00        # string
