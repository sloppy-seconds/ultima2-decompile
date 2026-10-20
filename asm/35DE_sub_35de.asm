# sub_35de — mechanical clean (bulk wave); behavior not yet reviewed
# func 35DE..35E9  len 000C B  evidence: reko
# strings: " DIRECT-"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_35de:
L_0037de:
        call L_0051df
        db " DIRECT-",0x00        # string
