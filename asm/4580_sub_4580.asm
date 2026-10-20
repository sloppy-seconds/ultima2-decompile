# sub_4580 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4580..458C  len 000D B  evidence: seed+reko
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4580:
L_004780:
        call L_0051df
        db 0x8d,"A LEVEL ",0x00        # string
