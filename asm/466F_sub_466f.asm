# sub_466f — mechanical clean (bulk wave); behavior not yet reviewed
# func 466F..4678  len 000A B  evidence: seed+reko
# strings: "TOOLS-"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_466f:
L_00486f:
        call L_0051df
        db "TOOLS-",0x00        # string
